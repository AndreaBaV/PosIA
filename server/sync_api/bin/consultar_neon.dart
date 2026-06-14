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
		const tablas = [
			'stores',
			'categories',
			'products',
			'customers',
			'vendedores',
			'proveedores',
			'sales',
			'sale_lines',
			'stock_levels',
			'product_variants',
			'transfers',
			'transfer_lines',
			'pharmacy_lots',
			'sync_events',
		];
		stdout.writeln('=== Neon — espejo POS ===\n');
		for (final tabla in tablas) {
			final cuenta = await conexion.execute('SELECT COUNT(*) FROM $tabla');
			final total = cuenta.first[0];
			stdout.writeln('  $tabla: $total filas');
		}
		final productos = await conexion.execute(
			'SELECT id, nombre, precio_base FROM products ORDER BY nombre LIMIT 5',
		);
		if (productos.isNotEmpty) {
			stdout.writeln('\n=== Muestra products ===');
			for (final fila in productos) {
				stdout.writeln('  ${fila[0]} | ${fila[1]} | \$${fila[2]}');
			}
		} else {
			stdout.writeln(
				'\nSin productos aun. Sincronice desde la caja (Admin → Sincronizar) '
				'o ejecute: dart run bin/reproyectar_neon.dart',
			);
		}
		final eventos = await conexion.execute(
			'SELECT seq, type, payload FROM sync_events ORDER BY seq DESC LIMIT 3',
		);
		if (eventos.isNotEmpty) {
			stdout.writeln('\n=== Ultimos sync_events ===');
			for (final fila in eventos) {
				stdout.writeln('  seq ${fila[0]} | ${fila[1]}');
			}
		}
	} finally {
		await conexion.close();
	}
}
