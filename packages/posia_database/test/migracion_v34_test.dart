/// Verifica que el esquema v34 (compras empresa) no rompe integridad FK.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixture_servicio_admin.dart';

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	test('crearEsquemaCompleto deja FKs validas en v34', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		final violaciones = await base.rawQuery('PRAGMA foreign_key_check');
		expect(violaciones, isEmpty);
		final tablas = await base.rawQuery(
			"SELECT name FROM sqlite_master WHERE type='table' AND name='purchase_allocations'",
		);
		expect(tablas, isNotEmpty);
		await base.close();
	});

	test('FixtureAdmin abre tras migracion v34', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final producto = await servicio.registrarProductoCompleto(
			AltaProductoRequest(
				nombre: 'Prueba esquema',
				codigoBarras: 'schema-v34',
				precioBase: 10.0,
				categoriaId: fixture.categoriaId,
				stockInicial: 5.0,
			),
		);
		expect(producto.id, isNotEmpty);
		await fixture.cerrar();
	});
}
