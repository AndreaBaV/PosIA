/// Audita tablas e índices del esquema Neon (solo lectura).
import 'dart:io';

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
	final envPath = File('.env');
	if (!envPath.existsSync()) {
		stderr.writeln('Falta .env con DATABASE_URL');
		exit(1);
	}
	final line = envPath
		.readAsLinesSync()
		.firstWhere((l) => l.startsWith('DATABASE_URL='), orElse: () => '');
	if (line.isEmpty) {
		stderr.writeln('DATABASE_URL no definida');
		exit(1);
	}
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

	print('=== TABLAS PUBLIC (Neon) ===');
	final tablas = await conn.execute('''
		SELECT table_name
		FROM information_schema.tables
		WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
		ORDER BY table_name
	''');
	for (final fila in tablas) {
		final nombre = fila[0] as String;
		final conteo = await conn.execute(
			'SELECT COUNT(*)::bigint AS total FROM "$nombre"',
		);
		final total = conteo.first[0];
		print('$nombre\t$total');
	}

	print('\n=== ÍNDICES (Neon) ===');
	final indices = await conn.execute('''
		SELECT tablename, indexname, indexdef
		FROM pg_indexes
		WHERE schemaname = 'public'
		ORDER BY tablename, indexname
	''');
	for (final fila in indices) {
		print('${fila[0]}\t${fila[1]}');
	}

	print('\n=== FK (Neon) ===');
	final fks = await conn.execute('''
		SELECT
			tc.table_name,
			kcu.column_name,
			ccu.table_name AS foreign_table,
			ccu.column_name AS foreign_column
		FROM information_schema.table_constraints tc
		JOIN information_schema.key_column_usage kcu
			ON tc.constraint_name = kcu.constraint_name
		JOIN information_schema.constraint_column_usage ccu
			ON ccu.constraint_name = tc.constraint_name
		WHERE tc.constraint_type = 'FOREIGN KEY'
		ORDER BY tc.table_name
	''');
	if (fks.isEmpty) {
		print('(sin foreign keys declaradas)');
	} else {
		for (final fila in fks) {
			print('${fila[0]}.${fila[1]} -> ${fila[2]}.${fila[3]}');
		}
	}

	print('\n=== COLUMNAS CLAVE (Neon) ===');
	for (final nombre in MapaTablasSync.tablasClaveAuditoriaNeon) {
		final existe = tablas.any((f) => f[0] == nombre);
		if (!existe) {
			print('$nombre\t(NO EXISTE)');
			continue;
		}
		final cols = await conn.execute(
			Sql.named('''
			SELECT column_name, data_type, is_nullable
			FROM information_schema.columns
			WHERE table_schema = 'public' AND table_name = @nombre
			ORDER BY ordinal_position
		'''),
			parameters: {'nombre': nombre},
		);
		print('--- $nombre ---');
		for (final c in cols) {
			print('  ${c[0]}\t${c[1]}\tnullable=${c[2]}');
		}
	}

	print('\n=== MAPA SQLITE → NEON (renombres) ===');
	for (final par in MapaTablasSync.renombres) {
		print('${par.sqlite}\t→\t${par.neon}');
	}

	await conn.close();
}
