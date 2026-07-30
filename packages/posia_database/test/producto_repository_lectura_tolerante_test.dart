/// Regresion: una fila rara no debe tumbar la lectura del catalogo entero.
///
/// La escritura de eventos remotos siempre fue tolerante (cae a un valor por
/// defecto si no reconoce el enum), pero la lectura usaba `byName` y casts
/// duros. Bastaba un producto guardado por una version mas nueva —o un precio
/// almacenado como entero— para que `listarActivosPorTienda` lanzara y la caja
/// se viera sin productos aunque SQLite los tuviera todos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	late Database base;
	late ProductoRepository productos;

	setUp(() async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
		base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		productos = ProductoRepository(baseDatos: base);
		await TiendaRepository(baseDatos: base).guardar(
			const Tienda(
				id: 'tienda-1',
				nombre: 'Matriz',
				direccion: '',
				activa: true,
			),
		);
	});

	tearDown(() => base.close());

	Future<void> insertarCrudo(Map<String, Object?> columnas) async {
		await base.insert('products', {
			'codigo_barras': '',
			'ruta_imagen': '',
			'activo': 1,
			'tienda_id': 'tienda-1',
			'modulo_vertical': ModuloVertical.general.name,
			'unidad_medida': UnidadMedida.pieza.name,
			'notas': '',
			'costo_unitario': 0.0,
			'favorito_caja': 0,
			'permite_stock_negativo': 1,
			...columnas,
		});
	}

	test('un producto con unidad de medida desconocida no tumba el catalogo', () async {
		await insertarCrudo({
			'id': 'p-sano',
			'nombre': 'Sano',
			'precio_base': 10.0,
		});
		await insertarCrudo({
			'id': 'p-futuro',
			'nombre': 'De una versión más nueva',
			'precio_base': 20.0,
			'unidad_medida': 'unidadQueAunNoExiste',
		});

		final catalogo = await productos.listarActivosPorTienda('tienda-1');

		final ids = catalogo.map((p) => p.id);
		expect(ids, containsAll(['p-sano', 'p-futuro']));
		final futuro = catalogo.firstWhere((p) => p.id == 'p-futuro');
		expect(futuro.unidadMedida, UnidadMedida.pieza);
	});

	test('un modulo vertical desconocido cae a general sin lanzar', () async {
		await insertarCrudo({
			'id': 'p-futuro',
			'nombre': 'Vertical nuevo',
			'precio_base': 5.0,
			'modulo_vertical': 'verticalQueAunNoExiste',
		});

		final catalogo = await productos.listarActivosPorTienda('tienda-1');

		final futuro = catalogo.firstWhere((p) => p.id == 'p-futuro');
		expect(futuro.moduloVertical, ModuloVertical.general);
	});

	test('un precio almacenado como entero se lee sin reventar', () async {
		// SQLite es de tipado dinamico: si el valor entro sin decimales, la
		// columna devuelve un int y el cast directo a double lanzaba.
		await base.rawInsert(
			'''
			INSERT INTO products (
				id, nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
				activo, tienda_id, modulo_vertical, notas, costo_unitario,
				favorito_caja, permite_stock_negativo
			) VALUES (?, ?, '', ?, ?, '', 1, 'tienda-1', ?, '', 0, 0, 1)
			''',
			[
				'p-entero',
				'Precio entero',
				100,
				UnidadMedida.pieza.name,
				ModuloVertical.general.name,
			],
		);

		final catalogo = await productos.listarActivosPorTienda('tienda-1');

		final entero = catalogo.firstWhere((p) => p.id == 'p-entero');
		expect(entero.precioBase, 100.0);
	});
}
