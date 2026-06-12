/// Almacen de eventos sobre Postgres para produccion multi-tenant.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

import 'dart:convert';

import 'package:postgres/postgres.dart';

import 'almacen_eventos.dart';
import 'evento_hub.dart';

/// Implementa [AlmacenEventos] con tabla sync_events en Postgres.
class AlmacenEventosPostgres implements AlmacenEventos {
	/// Crea almacen con URL de conexion Postgres.
	///
	/// [urlConexion] URL estilo postgres://usuario:clave@host:puerto/base.
	AlmacenEventosPostgres({required String urlConexion})
		: _urlConexion = urlConexion;

	final String _urlConexion;
	Connection? _conexion;

	@override
	Future<void> inicializar() async {
		final conexion = await _abrirConexion();
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS sync_events (
				seq BIGSERIAL PRIMARY KEY,
				id TEXT UNIQUE NOT NULL,
				tenant_id TEXT NOT NULL,
				store_id TEXT NOT NULL,
				device_id TEXT NOT NULL,
				type TEXT NOT NULL,
				payload JSONB NOT NULL,
				created_at TIMESTAMPTZ NOT NULL,
				received_at TIMESTAMPTZ NOT NULL DEFAULT now()
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sync_events_tenant_seq
			ON sync_events (tenant_id, seq)
		''');
	}

	@override
	Future<int> guardarLote(List<EventoHub> eventos) async {
		final conexion = await _abrirConexion();
		var aceptados = 0;
		for (final evento in eventos) {
			final resultado = await conexion.execute(
				Sql.named('''
					INSERT INTO sync_events
						(id, tenant_id, store_id, device_id, type, payload, created_at)
					VALUES
						(@id, @tenantId, @storeId, @deviceId, @type, @payload, @createdAt)
					ON CONFLICT (id) DO NOTHING
				'''),
				parameters: {
					'id': evento.id,
					'tenantId': evento.tenantId,
					'storeId': evento.tiendaId,
					'deviceId': evento.dispositivoId,
					'type': evento.tipo,
					'payload': jsonEncode(evento.payload),
					'createdAt': evento.creadoEn,
				},
			);
			aceptados = aceptados + resultado.affectedRows;
		}
		return aceptados;
	}

	@override
	Future<List<EventoHub>> obtenerDesde({
		required String tenantId,
		required int desdeSeq,
		String? excluirDispositivoId,
		int limite = 500,
	}) async {
		final conexion = await _abrirConexion();
		final resultado = await conexion.execute(
			Sql.named('''
				SELECT seq, id, tenant_id, store_id, device_id, type, payload, created_at
				FROM sync_events
				WHERE tenant_id = @tenantId
					AND seq > @desdeSeq
					AND (@deviceId::TEXT IS NULL OR device_id <> @deviceId)
				ORDER BY seq ASC
				LIMIT @limite
			'''),
			parameters: {
				'tenantId': tenantId,
				'desdeSeq': desdeSeq,
				'deviceId': excluirDispositivoId,
				'limite': limite,
			},
		);
		return resultado.map(_mapearFila).toList();
	}

	@override
	Future<void> cerrar() async {
		await _conexion?.close();
		_conexion = null;
	}

	/// Abre o reutiliza conexion activa a Postgres.
	///
	/// Retorna conexion lista para consultas.
	Future<Connection> _abrirConexion() async {
		final existente = _conexion;
		if (existente != null && existente.isOpen) {
			return existente;
		}
		final uri = Uri.parse(_urlConexion);
		final infoUsuario = uri.userInfo.split(':');
		final conexion = await Connection.open(
			Endpoint(
				host: uri.host,
				port: uri.hasPort ? uri.port : 5432,
				database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'posia_sync',
				username: infoUsuario.isNotEmpty ? infoUsuario[0] : 'posia',
				password: infoUsuario.length > 1 ? infoUsuario[1] : '',
			),
			settings: ConnectionSettings(sslMode: _resolverSsl(uri)),
		);
		_conexion = conexion;
		return conexion;
	}

	/// Determina modo SSL segun host (Neon requiere TLS).
	SslMode _resolverSsl(Uri uri) {
		final sslParam = uri.queryParameters['sslmode'];
		if (uri.host.contains('neon.tech') ||
			sslParam == 'require' ||
			sslParam == 'verify-full') {
			return SslMode.require;
		}
		return SslMode.disable;
	}

	/// Convierte fila SQL en [EventoHub].
	///
	/// [fila] Fila retornada por la consulta.
	/// Retorna evento del hub.
	EventoHub _mapearFila(ResultRow fila) {
		final columnas = fila.toColumnMap();
		final payloadCrudo = columnas['payload'];
		final payload = payloadCrudo is String
			? jsonDecode(payloadCrudo) as Map<String, Object?>
			: Map<String, Object?>.from(payloadCrudo as Map<Object?, Object?>);
		return EventoHub(
			seq: columnas['seq'] as int,
			id: columnas['id'] as String,
			tenantId: columnas['tenant_id'] as String,
			tiendaId: columnas['store_id'] as String,
			dispositivoId: columnas['device_id'] as String,
			tipo: columnas['type'] as String,
			payload: payload,
			creadoEn: (columnas['created_at'] as DateTime).toUtc(),
		);
	}
}
