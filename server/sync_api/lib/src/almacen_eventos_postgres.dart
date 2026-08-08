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

	/// Pool de escrituras por PRIORIDAD (dos carriles concurrentes). El carril
	/// ALTO atiende lo interactivo y el alta de catálogo (productos, categorías);
	/// el BAJO, las avalanchas grandes sin fundamentos. Así un flujo masivo de un
	/// dispositivo no atora las ventas ni el alta de productos de los demás.
	/// Cada carril está serializado (un lote a la vez) para no saturar el pool.
	Future<void> _colaAlta = Future<void>.value();
	Future<void> _colaBaja = Future<void>.value();

	/// Tipos "fundamento": el catálogo del que dependen ventas y stock. Tienen
	/// prioridad ALTA y, dentro de un lote, se aplican ANTES que el resto para
	/// que existan cuando una venta los referencie (evita el 23503 de FK).
	static const Set<String> _tiposFundacion = {
		'productUpserted',
		'categoryUpserted',
		'presentationTypeUpserted',
		'productPresentationsReplaced',
		'wholesaleTiersReplaced',
		'storeUpserted',
		'supplierUpserted',
		'warehouseUpserted',
	};

	/// Un lote más grande que esto se considera "avalancha": si además no trae
	/// fundamentos, va al carril BAJO para no bloquear lo interactivo.
	static const int _umbralLoteGrande = 25;

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
		// Carril ALTO: lotes chicos (una venta, el alta de un producto, una
		// edición) y cualquier lote con fundamentos de catálogo — el alta de
		// productos es prioridad. Carril BAJO: avalanchas grandes sin fundamentos
		// (p. ej. resincronización masiva de ventas), para no atorar lo demás.
		final tieneFundamentos = eventos.any((e) => _tiposFundacion.contains(e.tipo));
		final alta = eventos.length <= _umbralLoteGrande || tieneFundamentos;
		return _encolarEscritura(alta, () => _guardarLoteInterno(eventos));
	}

	Future<T> _encolarEscritura<T>(bool alta, Future<T> Function() trabajo) {
		final resultado = Completer<T>();
		final siguiente = (alta ? _colaAlta : _colaBaja).then((_) async {
			try {
				resultado.complete(await trabajo());
			} on Object catch (error, stack) {
				resultado.completeError(error, stack);
			}
		});
		if (alta) {
			_colaAlta = siguiente;
		} else {
			_colaBaja = siguiente;
		}
		return resultado.future;
	}

	Future<int> _guardarLoteInterno(List<EventoHub> eventosEntrada) async {
		if (eventosEntrada.isEmpty) {
			return 0;
		}
		// Fundamentos de catálogo primero (orden relativo estable), luego el
		// resto. Así, dentro del lote, un producto se proyecta ANTES que la venta
		// que lo referencia y no se rompe la llave foránea (23503).
		final eventos = <EventoHub>[
			...eventosEntrada.where((e) => _tiposFundacion.contains(e.tipo)),
			...eventosEntrada.where((e) => !_tiposFundacion.contains(e.tipo)),
		];
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
	Future<int> obtenerUltimoSeq() async {
		final pool = await _obtenerPool();
		final resultado = await pool.execute(
			'SELECT COALESCE(MAX(seq), 0) FROM sync_events',
		);
		return (resultado.first[0] as num?)?.toInt() ?? 0;
	}

	/// Desafio PIN activo y no vencido de [tiendaId], o null.
	///
	/// Evita que el celular tenga que ponerse al dia con todo el log solo
	/// para validar un PIN generado hace segundos en otro equipo.
	Future<Map<String, Object?>?> obtenerDesafioAsistenciaActivo(
		String tiendaId,
	) async {
		final tienda = tiendaId.trim();
		if (tienda.isEmpty) {
			return null;
		}
		final pool = await _obtenerPool();
		// No comparar expira_en como texto: Neon/driver puede devolver
		// "2026-08-08 00:30Z" (espacio) vs ISO con "T" y el > falla.
		final filas = await pool.execute(
			Sql.named('''
				SELECT id, tienda_id, pin_hash, expira_en, creado_por,
					latitud, longitud, radio_metros, activo
				FROM attendance_challenges
				WHERE tienda_id = @tienda AND activo = 1
				ORDER BY expira_en DESC
				LIMIT 8
			'''),
			parameters: {'tienda': tienda},
		);
		final ahora = DateTime.now().toUtc();
		for (final fila in filas) {
			final c = fila.toColumnMap();
			final expiraCrudo = c['expira_en'];
			final DateTime? expira = switch (expiraCrudo) {
				final DateTime d => d.toUtc(),
				final String s => DateTime.tryParse(s)?.toUtc(),
				_ => null,
			};
			if (expira == null || !expira.isAfter(ahora)) {
				continue;
			}
			final pinHash = c['pin_hash'] as String? ?? '';
			final id = c['id'] as String? ?? '';
			if (id.isEmpty || pinHash.isEmpty) {
				continue;
			}
			return {
				'id': id,
				'tiendaId': c['tienda_id'] as String? ?? tienda,
				'pinHash': pinHash,
				'expiraEn': expira.toIso8601String(),
				'creadoPor': c['creado_por'] as String? ?? '',
				'latitud': c['latitud'],
				'longitud': c['longitud'],
				'radioMetros': c['radio_metros'] ?? 150,
				'activo': true,
			};
		}
		return null;
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

	/// Eventos que definen el catalogo (ver [_tiposCatalogoCompactables]),
	/// deduplicados al mas reciente por entidad.
	///
	/// A diferencia de un pull normal desde seq=0, esto NO trae ventas,
	/// compras, traspasos, asistencia ni nomina: un dispositivo cuyo catalogo
	/// diverge de Neon pero cuyo historial transaccional esta sano puede
	/// repararse sin repetir años de eventos que no le hacen falta. Reusa la
	/// misma extraccion de clave por entidad que [_compactarCatalogoDuplicado]
	/// (`productPresentationsReplaced`/`wholesaleTiersReplaced` usan
	/// `productoId`, el resto usa `id`) para no discrepar sobre cual es la
	/// version mas reciente de cada fila.
	Future<List<EventoHub>> obtenerCatalogoCompacto() async {
		final pool = await _obtenerPool();
		final listaTipos = _tiposCatalogoCompactables.map((t) => "'$t'").join(', ');
		final resultado = await pool.execute('''
			SELECT DISTINCT ON (type, entity_key)
				seq, id, store_id, device_id, type, payload, created_at
			FROM (
				SELECT
					seq, id, store_id, device_id, type, payload, created_at,
					CASE
						WHEN type IN ('productPresentationsReplaced', 'wholesaleTiersReplaced')
							THEN payload->>'productoId'
						ELSE payload->>'id'
					END AS entity_key
				FROM sync_events
				WHERE type IN ($listaTipos)
			) con_clave
			WHERE entity_key IS NOT NULL AND entity_key <> ''
			ORDER BY type, entity_key, seq DESC
		''');
		final eventos = resultado.map(_mapearFila).toList()
			..sort((a, b) => a.seq.compareTo(b.seq));
		return eventos;
	}

	/// Cuenta y huella del catalogo activo en Neon, para que el dispositivo
	/// compare contra su copia local aunque su cursor de sync ya este al dia.
	///
	/// Un pull incremental solo repara lo que un evento nuevo "toca"; si un
	/// producto se perdio silenciosamente en el dispositivo (bug de indice
	/// unico corregido en el cliente, o cualquier otra causa futura) el cursor
	/// avanza igual y ese hueco nunca se vuelve a descargar. Esta auditoria le
	/// da al dispositivo una forma de notar el hueco y disparar una
	/// reconstruccion desde origen.
	Future<HuellaCatalogo> auditarCatalogo() async {
		final pool = await _obtenerPool();
		final filasProducto = await pool.execute(
			'SELECT id, nombre, codigo_barras FROM products WHERE activo = 1',
		);
		final huellaProductos = filasProducto.map((fila) {
			final mapa = fila.toColumnMap();
			return FilaHuellaProducto(
				id: mapa['id']! as String,
				nombre: mapa['nombre'] as String? ?? '',
				codigoBarras: mapa['codigo_barras'] as String? ?? '',
			);
		}).toList();
		final resultadoCategorias = await pool.execute(
			'SELECT COUNT(*) AS total FROM categories WHERE activa = 1',
		);
		final categoriasActivas =
			(resultadoCategorias.first[0] as num?)?.toInt() ?? 0;
		return HuellaCatalogo(
			productosActivos: huellaProductos.length,
			categoriasActivas: categoriasActivas,
			huellaProductos: calcularHuellaCatalogo(huellaProductos),
		);
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