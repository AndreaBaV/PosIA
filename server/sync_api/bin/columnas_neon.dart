/// Lista todas las columnas de tablas POS en Neon (solo lectura).
import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main() async {
	final envPath = File('.env');
	final line = envPath
		.readAsLinesSync()
		.firstWhere((l) => l.startsWith('DATABASE_URL='));
	final uri = Uri.parse(line.substring('DATABASE_URL='.length).trim());
	final info = uri.userInfo.split(':');
	final conn = await Connection.open(
		Endpoint(
			host: uri.host,
			port: uri.hasPort ? uri.port : 5432,
			database: uri.pathSegments.first,
			username: info[0],
			password: info.length > 1 ? info.sublist(1).join(':') : '',
		),
		settings: ConnectionSettings(sslMode: SslMode.require),
	);

	const excluir = {
		'account',
		'session',
		'user',
		'organization',
		'member',
		'invitation',
		'verification',
	};

	final cols = await conn.execute('''
		SELECT table_name, column_name, data_type, is_nullable, column_default
		FROM information_schema.columns
		WHERE table_schema = 'public'
		ORDER BY table_name, ordinal_position
	''');

	String? tablaActual;
	for (final c in cols) {
		final tabla = c[0] as String;
		if (excluir.contains(tabla)) continue;
		if (tabla != tablaActual) {
			print('### $tabla');
			tablaActual = tabla;
		}
		print('  ${c[1]}\t${c[2]}\tnullable=${c[3]}\tdefault=${c[4]}');
	}

	await conn.close();
}
