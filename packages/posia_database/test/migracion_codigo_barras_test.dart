/// Pruebas de migracion que fusiona productos duplicados por codigo de barras.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	group('Migracion codigo de barras unico', () {
		test('migrarVersion22A23 desactiva duplicados y conserva stock', () async {
			sqfliteFfiInit();
			databaseFactory = databaseFactoryFfi;
			final base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: (db, _) async {
					await MigracionesEsquema.crearEsquemaCompleto(db);
					await db.execute(
						'DROP INDEX IF EXISTS idx_products_barcode_tienda_activo',
					);
				},
			);
			const tiendaId = 'tienda-prueba';
			const codigo = '7501112223334';
			await base.insert('products', {
				'id': 'prod-viejo',
				'nombre': 'Producto original',
				'codigo_barras': codigo,
				'precio_base': 10.0,
				'unidad_medida': 'pieza',
				'ruta_imagen': '',
				'activo': 1,
				'tienda_id': tiendaId,
				'modulo_vertical': 'general',
				'categoria_id': 'cat',
				'costo_unitario': 5.0,
				'favorito_caja': 0,
				'notas': '',
			});
			await base.insert('products', {
				'id': 'prod-nuevo',
				'nombre': 'Producto duplicado',
				'codigo_barras': codigo,
				'precio_base': 15.0,
				'unidad_medida': 'pieza',
				'ruta_imagen': '',
				'activo': 1,
				'tienda_id': tiendaId,
				'modulo_vertical': 'general',
				'categoria_id': 'cat',
				'costo_unitario': 5.0,
				'favorito_caja': 0,
				'notas': '',
			});
			await base.insert('stock_levels', {
				'producto_id': 'prod-viejo',
				'tienda_id': tiendaId,
				'cantidad': 3.0,
				'actualizado_en': '2026-01-01T00:00:00.000Z',
				'stock_minimo': 0.0,
			});
			await base.insert('stock_levels', {
				'producto_id': 'prod-nuevo',
				'tienda_id': tiendaId,
				'cantidad': 7.0,
				'actualizado_en': '2026-01-01T00:00:00.000Z',
				'stock_minimo': 0.0,
			});

			await MigracionesEsquema.migrarVersion22A23(base);

			final activos = await base.query(
				'products',
				where: 'tienda_id = ? AND codigo_barras = ? AND activo = 1',
				whereArgs: [tiendaId, codigo],
			);
			expect(activos, hasLength(1));
			expect(activos.first['id'], 'prod-nuevo');

			final stock = await base.query(
				'stock_levels',
				where: 'producto_id = ? AND tienda_id = ?',
				whereArgs: ['prod-nuevo', tiendaId],
			);
			expect(stock, hasLength(1));
			expect(stock.first['cantidad'], 10.0);

			final inactivo = await base.query(
				'products',
				where: 'id = ?',
				whereArgs: ['prod-viejo'],
			);
			expect(inactivo.first['activo'], 0);

			await base.close();
		});
	});
}
