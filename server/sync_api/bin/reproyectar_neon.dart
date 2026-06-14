/// Reproyecta todos los eventos de sync_events a tablas espejo del POS.
library;

import 'dart:convert';
import 'dart:io';

import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
	final config = await ConfigEntorno.cargar();
	final url = config.urlBaseDatos;
	if (url == null) {
		stderr.writeln('DATABASE_URL no configurada.');
		exitCode = 1;
		return;
	}
	final almacen = AlmacenEventosPostgres(urlConexion: url);
	await almacen.inicializar();
	final uri = Uri.parse(url);
	final infoUsuario = uri.userInfo.split(':');
	final conexion = await Connection.open(
		Endpoint(
			host: uri.host,
			port: uri.hasPort ? uri.port : 5432,
			database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
			username: infoUsuario.isNotEmpty ? infoUsuario[0] : '',
			password: infoUsuario.length > 1 ? infoUsuario[1] : '',
		),
		settings: ConnectionSettings(
			sslMode: uri.host.contains('neon.tech') || uri.queryParameters['sslmode'] == 'require'
				? SslMode.require
				: SslMode.disable,
		),
	);
	try {
		final proyector = ProyectorEventosPostgres(conexion);
		final filas = await conexion.execute('''
			SELECT id, tenant_id, store_id, device_id, type, payload, created_at
			FROM sync_events
			ORDER BY seq ASC
		''');
		stdout.writeln('Reproyectando ${filas.length} eventos...');
		var ok = 0;
		for (final fila in filas) {
			final cols = fila.toColumnMap();
			final payloadCrudo = cols['payload'];
			final payload = payloadCrudo is String
				? Map<String, Object?>.from(
					jsonDecode(payloadCrudo) as Map<Object?, Object?>,
				)
				: Map<String, Object?>.from(payloadCrudo as Map<Object?, Object?>);
			final evento = EventoHub(
				seq: 0,
				id: cols['id'] as String,
				tenantId: cols['tenant_id'] as String,
				tiendaId: cols['store_id'] as String,
				dispositivoId: cols['device_id'] as String,
				tipo: cols['type'] as String,
				payload: payload,
				creadoEn: (cols['created_at'] as DateTime).toUtc(),
			);
			try {
				await proyector.aplicar(evento);
				ok = ok + 1;
			} on Object catch (e) {
				stdout.writeln('  omitido ${evento.id} (${evento.tipo}): $e');
			}
		}
		stdout.writeln('Listo: $ok/${filas.length} eventos proyectados.');
	} finally {
		await conexion.close();
		await almacen.cerrar();
	}
}
