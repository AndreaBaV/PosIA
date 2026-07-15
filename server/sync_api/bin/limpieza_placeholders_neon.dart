/// Limpieza de un solo uso de datos corruptos en Neon, producto de
/// AseguradorPadresFk (stubs FK) y de una siembra de categorías duplicada
/// contra la UI normal. Autorizado explícitamente por el usuario.
///
/// Acciones (en este orden):
/// 1. Fusiona categorías duplicadas con nombre real (Abarrotes, Aceite/
///    Aceites, Frutos Secos, Semillas): reasigna productos al id con más
///    productos reales y borra el duplicado.
/// 2. Reasigna los productos de las 4 categorías placeholder ("Categoría")
///    a la categoría canónica de Semillas, y borra los placeholders.
/// 3. Renombra los 5 proveedores placeholder ("Proveedor") a "Proveedor N".
/// 4. Verifica que las 2 tiendas placeholder (tienda-sync, almacen:alm-1)
///    sigan sin referencias reales en NINGUNA tabla con tienda_id, y las
///    borra solo si eso se cumple.
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

	// --- 1. Fusion de categorias duplicadas (canonico = mas productos reales) ---
	final fusiones = <String, List<String>>{
		'62844046-2abf-41a4-ad82-1f7ef7b54683': ['cat-abarrotes'], // Abarrotes
		'c39294f7-bbf5-41e0-a94e-51022e287ce4': ['cat-aceite', 'cat-aceites'], // Aceite/Aceites
		'cat-frutos-secos': ['fa91a526-c95d-4e06-8704-f4d8bb95a532'], // Frutos Secos
		'c27b8173-f601-43a3-93b2-f966db7f17a8': ['cat-semillas'], // Semillas
	};

	print('=== 1. Fusionando categorias duplicadas ===');
	for (final entrada in fusiones.entries) {
		final canonico = entrada.key;
		for (final duplicado in entrada.value) {
			final movidos = await conn.execute(
				Sql.named(
					'UPDATE products SET categoria_id = @canonico WHERE categoria_id = @dup',
				),
				parameters: {'canonico': canonico, 'dup': duplicado},
			);
			await conn.execute(
				Sql.named('DELETE FROM categories WHERE id = @dup'),
				parameters: {'dup': duplicado},
			);
			print(
				'  $duplicado -> $canonico (${movidos.affectedRows} productos reasignados, categoria duplicada borrada)',
			);
		}
	}

	// --- 2. Categorias placeholder ("Categoria") -> Semillas canonico ---
	const semillasCanonico = 'c27b8173-f601-43a3-93b2-f966db7f17a8';
	final stubsCategoria = await conn.execute(
		Sql.named("SELECT id FROM categories WHERE nombre = 'Categoría'"),
	);
	print('\n=== 2. Reasignando categorias placeholder a Semillas ===');
	for (final fila in stubsCategoria) {
		final id = fila[0] as String;
		final movidos = await conn.execute(
			Sql.named(
				'UPDATE products SET categoria_id = @semillas WHERE categoria_id = @id',
			),
			parameters: {'semillas': semillasCanonico, 'id': id},
		);
		await conn.execute(
			Sql.named('DELETE FROM categories WHERE id = @id'),
			parameters: {'id': id},
		);
		print('  $id -> $semillasCanonico (${movidos.affectedRows} productos reasignados, placeholder borrado)');
	}

	// --- 3. Renombrar proveedores placeholder ---
	final stubsProveedor = await conn.execute(
		Sql.named("SELECT id FROM suppliers WHERE nombre = 'Proveedor' ORDER BY id"),
	);
	print('\n=== 3. Renombrando proveedores placeholder ===');
	var n = 1;
	for (final fila in stubsProveedor) {
		final id = fila[0] as String;
		final nuevoNombre = 'Proveedor $n';
		await conn.execute(
			Sql.named('UPDATE suppliers SET nombre = @nombre WHERE id = @id'),
			parameters: {'nombre': nuevoNombre, 'id': id},
		);
		print('  $id -> "$nuevoNombre"');
		n++;
	}

	// --- 4. Borrar tiendas placeholder solo si siguen sin referencias reales ---
	print('\n=== 4. Verificando y borrando tiendas placeholder huerfanas ===');
	final tablasConTienda = [
		'products', 'sales', 'users', 'almacenes', 'cash_shifts',
		'payroll_periods', 'stock_levels', 'purchases', 'quotes', 'orders',
		'attendance_records', 'attendance_challenges', 'custom_roles',
	];
	final stubsTienda = await conn.execute(
		Sql.named("SELECT id FROM stores WHERE nombre = 'Tienda'"),
	);
	for (final fila in stubsTienda) {
		final id = fila[0] as String;
		var totalReferencias = 0;
		for (final tabla in tablasConTienda) {
			final r = await conn.execute(
				Sql.named('SELECT COUNT(*)::bigint FROM "$tabla" WHERE tienda_id = @id'),
				parameters: {'id': id},
			);
			totalReferencias += (r.first[0] as int);
		}
		if (totalReferencias > 0) {
			print('  $id tiene $totalReferencias referencias reales -> NO se borra');
			continue;
		}
		await conn.execute(
			Sql.named('DELETE FROM stores WHERE id = @id'),
			parameters: {'id': id},
		);
		print('  $id -> borrada (0 referencias reales)');
	}

	print('\nListo.');
	await conn.close();
}
