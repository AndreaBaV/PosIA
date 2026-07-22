/// Almacen de eventos sobre Postgres para produccion.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

import 'almacen_eventos.dart';
import 'almacen_usuarios_postgres.dart';
import 'esquema_pos_postgres.dart';
import 'evento_hub.dart';
import 'proyector_eventos_postgres.dart';

class AlmacenEventosPostgres implements AlmacenEventos {
	AlmacenEventosPostgres({required String urlConexion})
		: _urlConexion = urlConexion;

	final String _urlConexion;
	Pool<Object>? _pool;

	/// Cola de escrituras: un solo lote a la vez evita saturar el pool
	/// cuando varias cajas reintentan POST /v1/events en paralelo.
	Future<void> _colaEscritura = Future<void>.value();

	@override
	Future<void> inicializar() async {
		final pool = await _obtenerPool();
		await EsquemaPosPostgres.crearEsquemaCompleto(pool);
		final purgados = await EsquemaPosPostgres.purgarEventosAntiguos(pool);
		if (purgados > 0) {
			stdout.writeln(
				'Sync: purgados $purgados eventos antiguos '
				'(retencion ${DIAS_RETENCION_SYNC_EVENTS}d)',
			);
		}
		final compactados = await _compactarCatalogoDuplicado(pool);
		if (compactados > 0) {
			stdout.writeln(
				'Sync: compactados $compactados eventos de catálogo duplicados',
			);
		}
		await _reproyectarEventosEspejoPendientes(pool);
	}

	/// Tipos de catálogo "last-write-wins": solo importa el estado más
	/// reciente por entidad. Deja intacto el historial append-only (ventas,
	/// compras, movimientos, asistencia, nómina).
	static const _tiposCatalogoCompactables = [
		'productUpserted',
		'categoryUpserted',
		'productPresentationsReplaced',
		'wholesaleTiersReplaced',
		'variantUpserted',
		'customerUpserted',
		'supplierUpserted',
		'warehouseUpserted',
		'storeUpserted',
		'customRoleUpserted',
	];

	/// Colapsa versiones viejas del mismo evento de catálogo, dejando solo la
	/// más reciente por (tipo, id de entidad). Corre en cada arranque (no es
	/// un backfill único): el catálogo se sigue editando y re-generando
	/// duplicados con el uso normal, igual que [EsquemaPosPostgres.purgarEventosAntiguos].
	/// Seguro con el cursor de pull (`seq`): un dispositivo con cursor viejo
	/// solo deja de ver estados de catálogo ya superados, nunca el más
	/// reciente. `productPresentationsReplaced`/`wholesaleTiersReplaced` usan
	/// `productoId` como clave de entidad (no tienen `id` propio); el resto
	/// usa `id`.
	Future<int> _compactarCatalogoDuplicado(Pool<Object> pool) async {
		final listaTipos = _tiposCatalogoCompactables.map((t) => "'$t'").join(', ');
		final resultado = await pool.execute('''
			WITH claves AS (
				SELECT
					seq,
					CASE
						WHEN type IN ('productPresentationsReplaced', 'wholesaleTiersReplaced')
							THEN payload->>'productoId'
						ELSE payload->>'id'
					END AS entity_key
				FROM sync_events
				WHERE type IN ($listaTipos)
			),
			duplicados AS (
				SELECT seq FROM (
					SELECT
						c.seq,
						ROW_NUMBER() OVER (
							PARTITION BY se.type, c.entity_key ORDER BY c.seq DESC
						) AS rn
					FROM claves c
					JOIN sync_events se ON se.seq = c.seq
					WHERE c.entity_key IS NOT NULL AND c.entity_key <> ''
				) t
				WHERE rn > 1
			)
			DELETE FROM sync_events WHERE seq IN (SELECT seq FROM duplicados)
		''');
		return resultado.affectedRows;
	}

	@override
	Future<int> guardarLote(List<EventoHub> eventos) {
		return _encolarEscritura(() => _guardarLoteInterno(eventos));
	}

	Future<T> _encolarEscritura<T>(Future<T> Function() trabajo) {
		final resultado = Completer<T>();
		_colaEscritura = _colaEscritura.then((_) async {
			try {
				resultado.complete(await trabajo());
			} on Object catch (error, stack) {
				resultado.completeError(error, stack);
			}
		});
		return resultado.future;
	}

	Future<int> _guardarLoteInterno(List<EventoHub> eventos) async {
		if (eventos.isEmpty) {
			return 0;
		}
		final pool = await _obtenerPool();
		final cronometro = Stopwatch()..start();
		var aceptados = 0;
		var modo = 'lote';
		// Una sola conexion por lote: evita N adquisiciones del semaforo
		// (cada pool.runTx pelea por un slot con connectTimeout ~15s).
		await pool.withConnection((conexion) async {
			// Camino rapido: TODO el lote en una transaccion. Antes se abria una
			// transaccion por evento (40 BEGIN/COMMIT extra contra Neon), lo que
			// costaba ~18 s por lote de 40; como las escrituras estan serializadas
			// en `_colaEscritura`, esa demora se acumulaba en una fila global de
			// minutos y los clientes cortaban por timeout antes de recibir el 200.
			try {
				aceptados = await conexion.runTx(
					(tx) => _aplicarEventos(tx, eventos, cacheTiendas: <String>{}),
				);
				return;
			} on Object catch (error) {
				// Un solo evento invalido aborta la transaccion completa: se
				// reintenta evento por evento para aislarlo y salvar el resto.
				stdout.writeln('Sync: lote en bloque fallo ($error); aislando eventos');
			}
			modo = 'aislado';
			aceptados = 0;
			for (final evento in eventos) {
				try {
					// Sin cache de tiendas: si esta transaccion revierte, un id
					// cacheado quedaria marcado como insertado sin estarlo.
					await conexion.runTx((tx) => _aplicarEventos(tx, [evento]));
					aceptados = aceptados + 1;
				} on Object catch (error) {
					stdout.writeln(
						'Sync: error en ${evento.tipo} (${evento.id}): $error',
					);
				}
			}
		});
		cronometro.stop();
		stdout.writeln(
			'Sync: lote ${eventos.length} eventos ($modo), '
			'$aceptados aceptados en ${cronometro.elapsed}',
		);
		return aceptados;
	}

	/// Persiste y proyecta [eventos] dentro de la sesion/transaccion [tx].
	///
	/// Retorna cuantos se aplicaron. Si alguno lanza, propaga: quien llama
	/// decide si revierte el bloque o reintenta evento por evento.
	Future<int> _aplicarEventos(
		Session tx,
		List<EventoHub> eventos, {
		Set<String>? cacheTiendas,
	}) async {
		final proyector = ProyectorEventosPostgres(tx, cacheTiendas: cacheTiendas);
		for (final evento in eventos) {
			await tx.execute(
				Sql.named('''
					INSERT INTO sync_events
						(id, store_id, device_id, type, payload, created_at)
					VALUES
						(@id, @storeId, @deviceId, @type, @payload, @createdAt)
					ON CONFLICT (id) DO UPDATE SET
						store_id = EXCLUDED.store_id,
						device_id = EXCLUDED.device_id,
						type = EXCLUDED.type,
						payload = EXCLUDED.payload,
						created_at = EXCLUDED.created_at
				'''),
				parameters: {
					'id': evento.id,
					'storeId': evento.tiendaId,
					'deviceId': evento.dispositivoId,
					'type': evento.tipo,
					'payload': jsonEncode(evento.payload),
					'createdAt': evento.creadoEn,
				},
			);
			await proyector.aplicar(evento);
		}
		return eventos.length;
	}

	@override
	Future<List<EventoHub>> obtenerDesde({
		required int desdeSeq,
		String? excluirDispositivoId,
		int limite = 500,
	}) async {
		final pool = await _obtenerPool();
		final resultado = await pool.execute(
			Sql.named('''
				SELECT seq, id, store_id, device_id, type, payload, created_at
				FROM sync_events
				WHERE seq > @desdeSeq
					AND (@deviceId::TEXT IS NULL OR device_id <> @deviceId)
				ORDER BY seq ASC
				LIMIT @limite
			'''),
			parameters: {
				'desdeSeq': desdeSeq,
				'deviceId': excluirDispositivoId,
				'limite': limite,
			},
		);
		return resultado.map(_mapearFila).toList();
	}

	@override
	Future<void> cerrar() async {
		await _pool?.close();
		_pool = null;
	}

	Future<AlmacenUsuariosPostgres> obtenerAlmacenUsuarios() async {
		// Proveedor en lugar de Connection fija: Neon cierra conexiones idle y
		// auth debe reutilizar _obtenerPool() como el resto del almacen.
		return AlmacenUsuariosPostgres(_obtenerPool);
	}

	Future<Pool<Object>> _obtenerPool() async {
		final existente = _pool;
		if (existente != null) {
			return existente;
		}
		final uri = Uri.parse(_urlConexion);
		final infoUsuario = uri.userInfo.split(':');
		final pool = Pool<Object>.withEndpoints(
			[
				Endpoint(
					host: uri.host,
					port: uri.hasPort ? uri.port : 5432,
					database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'posia_sync',
					username: infoUsuario.isNotEmpty ? infoUsuario[0] : 'posia',
					password: infoUsuario.length > 1 ? infoUsuario[1] : '',
				),
			],
			settings: PoolSettings(
				sslMode: _resolverSsl(uri),
				// Lecturas (GET/auth) + 1 escritura serializada.
				maxConnectionCount: 8,
				// Default del driver es 15s; con colas de sync es insuficiente.
				connectTimeout: const Duration(seconds: 90),
				queryTimeout: const Duration(minutes: 2),
			),
		);
		_pool = pool;
		return pool;
	}

	SslMode _resolverSsl(Uri uri) {
		final sslParam = uri.queryParameters['sslmode'];
		if (uri.host.contains('neon.tech') ||
			sslParam == 'require' ||
			sslParam == 'verify-full') {
			return SslMode.require;
		}
		return SslMode.disable;
	}

	EventoHub _mapearFila(ResultRow fila) {
		final columnas = fila.toColumnMap();
		final payloadCrudo = columnas['payload'];
		final payload = payloadCrudo is String
			? jsonDecode(payloadCrudo) as Map<String, Object?>
			: Map<String, Object?>.from(payloadCrudo as Map<Object?, Object?>);
		return EventoHub(
			seq: columnas['seq'] as int,
			id: columnas['id'] as String,
			tiendaId: columnas['store_id'] as String,
			dispositivoId: columnas['device_id'] as String,
			tipo: columnas['type'] as String,
			payload: payload,
			creadoEn: (columnas['created_at'] as DateTime).toUtc(),
		);
	}

	/// Reproyecta eventos que quedaron solo en sync_events (nunca aplicados a
	/// su tabla espejo). Cada backfill corre una sola vez, marcado en
	/// schema_meta; agregar un backfill nuevo no repite los anteriores.
	Future<void> _reproyectarEventosEspejoPendientes(Pool<Object> pool) async {
		await pool.execute('''
			CREATE TABLE IF NOT EXISTS schema_meta (
				clave TEXT PRIMARY KEY,
				valor TEXT NOT NULL
			)
		''');
		// v2: users.creado_en/actualizado_en pasaron a TIMESTAMPTZ; el proyector
		// casteaba DateTime as String? y tumaba userUpserted (y lotes con proveedores).
		await _reproyectarPorTipos(
			pool: pool,
			claveMeta: 'mirror_backfill_roles_v2',
			tipos: [
				'customRoleUpserted',
				'userUpserted',
				'supplierUpserted',
				'supplierDeleted',
			],
		);
		// v1: _registrarEventoCompra y ServicioAsistencia usaban IDs de evento
		// aleatorios; cada reintento de sync creaba un evento "nuevo" que nunca
		// convergia, dejando compras/nomina/asistencia varadas en sync_events
		// sin proyectarse (ver docs/mantenimiento/AUDITORIA_INICIAL.md).
		await _reproyectarPorTipos(
			pool: pool,
			claveMeta: 'mirror_backfill_ops_v1',
			tipos: [
				'purchaseCompleted',
				'payrollPeriodClosed',
				'employeeProfileUpserted',
				'attendanceChallengeCreated',
				'attendanceCheckedIn',
				'attendanceCheckedOut',
			],
		);
	}

	Future<void> _reproyectarPorTipos({
		required Pool<Object> pool,
		required String claveMeta,
		required List<String> tipos,
	}) async {
		final existente = await pool.execute(
			Sql.named('SELECT valor FROM schema_meta WHERE clave = @clave'),
			parameters: {'clave': claveMeta},
		);
		if (existente.isNotEmpty) {
			return;
		}
		// `tipos` son literales internos fijos (nunca entrada de usuario); se
		// listan inline porque el driver no soporta bien parámetros de array
		// con Sql.named en este proyecto.
		final listaTipos = tipos.map((t) => "'$t'").join(', ');
		final filas = await pool.execute('''
			SELECT seq, id, store_id, device_id, type, payload, created_at
			FROM sync_events
			WHERE type IN ($listaTipos)
			ORDER BY seq ASC
		''');
		for (final fila in filas) {
			try {
				final evento = _mapearFila(fila);
				await pool.runTx((tx) async {
					await ProyectorEventosPostgres(tx).aplicar(evento);
				});
			} on Object catch (error) {
				stdout.writeln(
					'Sync backfill ($claveMeta): error en ${fila.toColumnMap()['type']}: $error',
				);
			}
		}
		await pool.execute(
			Sql.named('''
				INSERT INTO schema_meta (clave, valor)
				VALUES (@clave, @valor)
				ON CONFLICT (clave) DO NOTHING
			'''),
			parameters: {
				'clave': claveMeta,
				'valor': DateTime.now().toUtc().toIso8601String(),
			},
		);
	}
}