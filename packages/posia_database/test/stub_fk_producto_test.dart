/// Regresion: los stubs FK de producto no deben contaminar el catalogo.
///
/// Un stub sin marcar viaja a Neon como producto real y, al bajar a los demas
/// equipos, reemplaza al producto legitimo que comparte su id: nombre pasa a
/// "Producto", precio a 0 y la categoria se pierde.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/utils/asegurador_padres_fk.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Producto _productoReal(String id) => Producto(
	id: id,
	nombre: 'Arroz Quebrado',
	codigoBarras: '7501234567890',
	precioBase: 18.0,
	unidadMedida: UnidadMedida.kilogramo,
	rutaImagen: '',
	activo: true,
	tiendaId: 'tienda-centro',
	costoUnitario: 12.0,
);

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	Future<Database> abrirBase() async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');
		return base;
	}

	test('asegurarProducto marca el stub que crea', () async {
		final base = await abrirBase();
		await AseguradorPadresFk(base).asegurarProducto('prod-huerfano');

		final filas = await base.query(
			'products',
			where: 'id = ?',
			whereArgs: ['prod-huerfano'],
		);
		expect(filas.single['notas'], '__stub_fk__');
		await base.close();
	});

	test('asegurarProducto no toca un producto real existente', () async {
		final base = await abrirBase();
		final repo = ProductoRepository(baseDatos: base);
		await repo.guardar(_productoReal('prod-real'));

		await AseguradorPadresFk(base).asegurarProducto('prod-real');

		final guardado = await repo.obtenerPorId('prod-real');
		expect(guardado!.nombre, 'Arroz Quebrado');
		expect(guardado.precioBase, 18.0);
		expect(guardado.esStubFk, isFalse);
		await base.close();
	});

	test('esStubFk distingue placeholder de producto real', () async {
		expect(_productoReal('x').esStubFk, isFalse);

		const stubMarcado = Producto(
			id: 'y',
			nombre: 'Producto',
			codigoBarras: '',
			precioBase: 0.0,
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-sync',
			notas: '__stub_fk__',
		);
		expect(stubMarcado.esStubFk, isTrue);

		// Stubs creados por versiones anteriores no llevan la marca; se detectan
		// por su forma para poder filtrarlos igual.
		const stubHeredado = Producto(
			id: 'z',
			nombre: 'Producto',
			codigoBarras: '',
			precioBase: 0.0,
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-sync',
		);
		expect(stubHeredado.esStubFk, isTrue);

		// Un producto real que casualmente se llame "Producto" pero tenga datos
		// de negocio no debe confundirse con un placeholder.
		const homonimo = Producto(
			id: 'w',
			nombre: 'Producto',
			codigoBarras: '7500000000001',
			precioBase: 45.0,
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-centro',
		);
		expect(homonimo.esStubFk, isFalse);
	});
}
