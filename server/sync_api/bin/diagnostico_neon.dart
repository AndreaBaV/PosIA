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
		await EsquemaPosPostgres.crearEsquemaCompleto(conexion);
		stdout.writeln('=== stores ===');
		final stores = await conexion.execute(
			'SELECT id, nombre, activa FROM stores ORDER BY nombre',
		);
		for (final fila in stores) {
			stdout.writeln('  ${fila[0]} | ${fila[1]} | activa=${fila[2]}');
		}
		stdout.writeln('\n=== users ===');
		final users = await conexion.execute(
			'SELECT codigo, rol, tienda_id, activo FROM users ORDER BY codigo',
		);
		for (final fila in users) {
			stdout.writeln(
				'  ${fila[0]} | ${fila[1]} | tienda=${fila[2]} | activo=${fila[3]}',
			);
		}
		stdout.writeln('\n=== storeUpserted (ultimos 10) ===');
		final eventos = await conexion.execute(
			"SELECT seq, store_id, type FROM sync_events WHERE type = 'storeUpserted' ORDER BY seq DESC LIMIT 10",
		);
		for (final fila in eventos) {
			stdout.writeln('  seq=${fila[0]} store=${fila[1]}');
		}
		if (eventos.isEmpty) {
			stdout.writeln('  (ninguno)');
		}
	} finally {
		await conexion.close();
	}
}
