/// Muestra eventos en sync_events (tipo y payload resumido).
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
		final filas = await conexion.execute('''
			SELECT seq, id, type, payload, store_id
			FROM sync_events
			ORDER BY seq ASC
		''');
		stdout.writeln('Eventos en Neon (${filas.length}):\n');
		for (final fila in filas) {
			final payloadCrudo = fila[3];
			final payload = payloadCrudo is String
				? jsonDecode(payloadCrudo) as Map<String, Object?>
				: Map<String, Object?>.from(payloadCrudo as Map<Object?, Object?>);
			final resumen = payload.entries
				.map((e) => '${e.key}=${e.value}')
				.join(', ');
			stdout.writeln('  seq ${fila[0]} | ${fila[2]} | store=${fila[4]}');
			stdout.writeln('    id evento: ${fila[1]}');
			stdout.writeln('    payload: $resumen\n');
		}
	} finally {
		await conexion.close();
	}
}
