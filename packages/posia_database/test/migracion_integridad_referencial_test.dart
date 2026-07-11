/// Pruebas de migracion v33: FKs reales y preflight de sync al hub.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	test('migrarVersion32A33 exige cola de sync vacia', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.insert('sync_event_queue', {
			'id': 'evt-1',
			'tienda_id': 't1',
			'dispositivo_id': 'd1',
			'tipo': 'productUpserted',
			'payload': '{}',
			'creado_en': DateTime.now().toUtc().toIso8601String(),
			'estado': 'pendiente',
		});

		expect(
			() => MigracionIntegridadReferencial.aplicar(base),
			throwsA(isA<MigracionRequiereSyncHubException>()),
		);
		await base.close();
	});

	test('crearEsquemaCompleto deja FKs de sale_lines aplicadas', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);

		expect(await MigracionIntegridadReferencial.yaAplicada(base), isTrue);
		final check = await base.rawQuery('PRAGMA foreign_key_check');
		expect(check, isEmpty);
		await base.close();
	});

	test('rebuild aplica FKs sobre tablas sin REFERENCES', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) async {
				await db.execute('''
					CREATE TABLE stores (
						id TEXT PRIMARY KEY,
						nombre TEXT NOT NULL,
						activa INTEGER NOT NULL DEFAULT 1
					)
				''');
				await db.execute('''
					CREATE TABLE products (
						id TEXT PRIMARY KEY,
						nombre TEXT NOT NULL,
						codigo_barras TEXT NOT NULL,
						precio_base REAL NOT NULL,
						unidad_medida TEXT NOT NULL,
						ruta_imagen TEXT NOT NULL,
						activo INTEGER NOT NULL,
						tienda_id TEXT NOT NULL,
						modulo_vertical TEXT NOT NULL DEFAULT 'general',
						categoria_id TEXT,
						piezas_por_caja INTEGER,
						proveedor_id TEXT,
						unidades_por_bulto INTEGER,
						notas TEXT NOT NULL DEFAULT '',
						costo_unitario REAL NOT NULL DEFAULT 0,
						favorito_caja INTEGER NOT NULL DEFAULT 0,
						permite_stock_negativo INTEGER NOT NULL DEFAULT 1
					)
				''');
				await db.execute('''
					CREATE TABLE sales (
						id TEXT PRIMARY KEY,
						tienda_id TEXT NOT NULL,
						caja_id TEXT NOT NULL,
						cliente_id TEXT,
						metodo_pago TEXT NOT NULL,
						total REAL NOT NULL,
						creada_en TEXT NOT NULL,
						vendedor_id TEXT,
						estado TEXT NOT NULL DEFAULT 'completada',
						turno_caja_id TEXT,
						descuento_ticket REAL NOT NULL DEFAULT 0,
						monto_efectivo REAL,
						monto_tarjeta REAL,
						monto_transferencia REAL,
						credito_dias INTEGER,
						credito_vence_en TEXT,
						credito_liquidado INTEGER NOT NULL DEFAULT 0,
						credito_liquidado_en TEXT
					)
				''');
				await db.execute('''
					CREATE TABLE sale_lines (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						venta_id TEXT NOT NULL,
						producto_id TEXT NOT NULL,
						nombre_producto TEXT NOT NULL,
						cantidad REAL NOT NULL,
						precio_unitario REAL NOT NULL,
						regla_precio TEXT NOT NULL,
						lote_id TEXT,
						etiqueta_lote TEXT,
						descuento_linea REAL NOT NULL DEFAULT 0
					)
				''');
				await db.execute('''
					CREATE TABLE sync_event_queue (
						id TEXT PRIMARY KEY,
						tienda_id TEXT NOT NULL,
						dispositivo_id TEXT NOT NULL,
						tipo TEXT NOT NULL,
						payload TEXT NOT NULL,
						creado_en TEXT NOT NULL,
						estado TEXT NOT NULL
					)
				''');
			},
		);

		await base.insert('stores', {'id': 's1', 'nombre': 'Tienda', 'activa': 1});
		await base.insert('products', {
			'id': 'p1',
			'nombre': 'Prod',
			'codigo_barras': '1',
			'precio_base': 1,
			'unidad_medida': 'pieza',
			'ruta_imagen': '',
			'activo': 1,
			'tienda_id': 's1',
		});
		await base.insert('sales', {
			'id': 'v1',
			'tienda_id': 's1',
			'caja_id': 'c1',
			'metodo_pago': 'efectivo',
			'total': 1,
			'creada_en': DateTime.now().toUtc().toIso8601String(),
		});
		await base.insert('sale_lines', {
			'venta_id': 'v1',
			'producto_id': 'p1',
			'nombre_producto': 'Prod',
			'cantidad': 1,
			'precio_unitario': 1,
			'regla_precio': 'precioBase',
		});

		await MigracionIntegridadReferencial.aplicar(base);

		expect(await MigracionIntegridadReferencial.yaAplicada(base), isTrue);
		final check = await base.rawQuery('PRAGMA foreign_key_check');
		expect(check, isEmpty);
		await base.close();
	});
}
