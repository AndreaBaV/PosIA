/// Almacen de eventos sobre Postgres para produccion.
library;

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
		await _reproyectarEventosEspejoPendientes(pool);
	}

	@override
	Future<int> guardarLote(List<EventoHub> eventos) async {
		final pool = await _obtenerPool();
		var aceptados = 0;
		for (final evento in eventos) {
			try {
				await pool.runTx((tx) async {
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
					await ProyectorEventosPostgres(tx).aplicar(evento);
				});
				aceptados = aceptados + 1;
			} on Object catch (error) {
				stdout.writeln('Sync: error en ${evento.tipo} (${evento.id}): $error');
			}
		}
		return aceptados;
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
				maxConnectionCount: 5,
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

	/// Reproyecta eventos de roles/usuarios que quedaron solo en sync_events.
	Future<void> _reproyectarEventosEspejoPendientes(Pool<Object> pool) async {
		const claveMeta = 'mirror_backfill_roles_v1';
		await pool.execute('''
			CREATE TABLE IF NOT EXISTS schema_meta (
				clave TEXT PRIMARY KEY,
				valor TEXT NOT NULL
			)
		''');
		final existente = await pool.execute(
			Sql.named('SELECT valor FROM schema_meta WHERE clave = @clave'),
			parameters: {'clave': claveMeta},
		);
		if (existente.isNotEmpty) {
			return;
		}
		final filas = await pool.execute('''
			SELECT seq, id, store_id, device_id, type, payload, created_at
			FROM sync_events
			WHERE type IN ('customRoleUpserted', 'userUpserted')
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
					'Sync backfill: error en ${fila.toColumnMap()['type']}: $error',
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