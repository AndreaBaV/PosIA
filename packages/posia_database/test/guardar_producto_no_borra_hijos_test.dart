/// Regresion: guardar un producto no debe vaciar sus tablas hijas.
///
/// `ProductoRepository.guardar` usaba ConflictAlgorithm.replace. `INSERT OR
/// REPLACE` borra la fila existente antes de insertar la nueva y, desde la
/// migracion v33, ese borrado dispara ON DELETE CASCADE sobre empaques, stock,
/// escalas de mayoreo y variantes. Guardar un producto los eliminaba todos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _producto = Producto(
	id: 'prod-arroz',
	nombre: 'Arroz Morelos',
	codigoBarras: '750001',
	precioBase: 25.0,
	unidadMedida: UnidadMedida.kilogramo,
	rutaImagen: '',
	activo: true,
	tiendaId: 'tienda-1',
	costoUnitario: 15.0,
);

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	test('guardar un producto conserva empaques, escalas y stock', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		// Sin esto el CASCADE ni siquiera se evalua y el test no probaria nada.
		await base.execute('PRAGMA foreign_keys=ON');
		await base.insert('stores', {
			'id': 'tienda-1',
			'nombre': 'Centro',
			'direccion': '',
			'activa': 1,
		});

		final productos = ProductoRepository(baseDatos: base);
		await productos.guardar(_producto);

		final presentaciones = PresentacionRepository(baseDatos: base);
		await presentaciones.guardarPresentacion(
			const PresentacionProducto(
				id: 'pres-bulto',
				productoId: 'prod-arroz',
				tipoPresentacionId: null,
				nombre: 'Bulto 25 kg',
				factorABase: 25.0,
				esPresentacionBase: false,
				codigoBarras: '',
				precio: 600.0,
				activo: true,
			),
		);
		await PrecioRepository(baseDatos: base).reemplazarEscalasMayoreo(
			'prod-arroz',
			const [
				EscalaMayoreo(
					productoId: 'prod-arroz',
					cantidadMinima: 10.0,
					precioUnitario: 22.0,
				),
			],
		);

		expect(await presentaciones.listarPorProducto('prod-arroz'), hasLength(1));

		// El guardado que ocurre al pulsar "Guardar producto".
		await productos.guardar(_producto.copiarCon(precioBase: 26.0));

		expect(
			await presentaciones.listarPorProducto('prod-arroz'),
			hasLength(1),
			reason: 'el empaque debe sobrevivir al guardado del producto',
		);
		expect(
			await base.query(
				'wholesale_tiers',
				where: 'producto_id = ?',
				whereArgs: ['prod-arroz'],
			),
			hasLength(1),
			reason: 'las escalas de mayoreo deben sobrevivir',
		);
		final guardado = await productos.obtenerPorId('prod-arroz');
		expect(guardado!.precioBase, 26.0, reason: 'el cambio si debe aplicarse');

		await base.close();
	});
}
