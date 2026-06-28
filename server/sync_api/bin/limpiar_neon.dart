/// Limpia tablas espejo y eventos en Neon (desarrollo / reparacion).
///
/// Uso:
///   dart run bin/limpiar_neon.dart --listar
///   dart run bin/limpiar_neon.dart --usuarios
///   dart run bin/limpiar_neon.dart --completo --confirmar
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:postgres/postgres.dart';

Future<void> main(List<String> arguments) async {
	final parser = ArgParser()
		..addFlag('listar', abbr: 'l', help: 'Solo listar usuarios en Neon', negatable: false)
		..addFlag('usuarios', abbr: 'u', help: 'Borrar users y eventos userUpserted', negatable: false)
		..addFlag('completo', abbr: 'c', help: 'Vaciar todas las tablas espejo + sync_events', negatable: false)
		..addFlag('confirmar', help: 'Requerido para ejecutar borrado', negatable: false);

	late ArgResults args;
	try {
		args = parser.parse(arguments);
	} on FormatException catch (e) {
		stderr.writeln('Error: $e\n${parser.usage}');
		exitCode = 64;
		return;
	}

	if (!args.wasParsed('listar') && !args.wasParsed('usuarios') && !args.wasParsed('completo')) {
		stdout.writeln(parser.usage);
		return;
	}

	final config = await ConfigEntorno.cargar();
	final url = config.urlBaseDatos;
	if (url == null) {
		stderr.writeln('DATABASE_URL no configurada.');
		exitCode = 1;
		return;
	}

	final conexion = await _abrir(url);
	try {
		await EsquemaPosPostgres.crearEsquemaCompleto(conexion);

		if (args['listar'] as bool) {
			await _listarUsuarios(conexion);
			return;
		}

		if (!(args['confirmar'] as bool)) {
			stderr.writeln('Agrega --confirmar para ejecutar el borrado.');
			exitCode = 1;
			return;
		}

		if (args['usuarios'] as bool) {
			await _limpiarUsuarios(conexion);
			stdout.writeln('Usuarios y eventos userUpserted eliminados.');
			await _listarUsuarios(conexion);
			return;
		}

		if (args['completo'] as bool) {
			await _limpiarCompleto(conexion);
			stdout.writeln('Base Neon vaciada (espejo + sync_events).');
		}
	} finally {
		await conexion.close();
	}
}

Future<Connection> _abrir(String urlConexion) async {
	final uri = Uri.parse(urlConexion);
	final info = uri.userInfo.split(':');
	return Connection.open(
		Endpoint(
			host: uri.host,
			port: uri.hasPort ? uri.port : 5432,
			database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
			username: info.isNotEmpty ? info[0] : '',
			password: info.length > 1 ? info[1] : '',
		),
		settings: ConnectionSettings(
			sslMode: uri.host.contains('neon.tech') ||
					uri.queryParameters['sslmode'] == 'require'
				? SslMode.require
				: SslMode.disable,
		),
	);
}

Future<void> _listarUsuarios(Connection conexion) async {
	final filas = await conexion.execute('''
		SELECT id, tenant_id, nombre, codigo, rol, activo
		FROM users
		ORDER BY tenant_id, codigo
	''');
	stdout.writeln('=== users (${filas.length}) ===');
	for (final fila in filas) {
		stdout.writeln(
			'  ${fila[2]} | ${fila[3]} | ${fila[4]} | tenant=${fila[1]} | activo=${fila[5]}',
		);
	}
}

Future<void> _limpiarUsuarios(Connection conexion) async {
	await conexion.execute('DELETE FROM users');
	await conexion.execute("DELETE FROM sync_events WHERE type = 'userUpserted'");
	stdout.writeln('  users: 0 filas');
	final restantes = await conexion.execute('SELECT COUNT(*) FROM sync_events');
	stdout.writeln('  sync_events restantes: ${restantes.first[0]}');
}

Future<void> _limpiarCompleto(Connection conexion) async {
	const tablas = [
		'sale_lines',
		'sales',
		'transfer_lines',
		'transfers',
		'stock_levels',
		'product_variants',
		'products',
		'categories',
		'customers',
		'users',
		'stores',
		'almacenes',
		'sync_events',
	];
	for (final tabla in tablas) {
		try {
			await conexion.execute('DELETE FROM $tabla');
			stdout.writeln('  $tabla: vaciada');
		} on Object catch (e) {
			stdout.writeln('  $tabla: omitida ($e)');
		}
	}
	await conexion.execute(
		"SELECT setval(pg_get_serial_sequence('sync_events', 'seq'), 1, false)",
	);
	stdout.writeln('  sync_events seq reiniciado');
}
