/// Pruebas de integridad referencial al guardar clientes remotos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	test('guardar cliente crea lista de precios padre faltante', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');

		const listaId = 'ae91c6db-c33a-4008-a744-81bf1ea51477';
		final repo = ClienteRepository(baseDatos: base);
		await repo.guardar(
			Cliente(
				id: 'ca1ae2e1-c030-429b-832f-1e6423b7623b',
				nombre: 'Andrea Bahena',
				listaPreciosId: listaId,
				creditoHabilitado: true,
				activo: true,
				telefono: '7291335261',
				direccion: 'Av. Árboles 123',
				diasCredito: 15,
			),
		);

		final listas = await base.query('price_lists', where: 'id = ?', whereArgs: [listaId]);
		expect(listas, isNotEmpty);
		final clientes = await base.query(
			'customers',
			where: 'id = ?',
			whereArgs: ['ca1ae2e1-c030-429b-832f-1e6423b7623b'],
		);
		expect(clientes, isNotEmpty);
		expect(clientes.first['lista_precios_id'], listaId);

		final fkCheck = await base.rawQuery('PRAGMA foreign_key_check');
		expect(fkCheck, isEmpty);

		await base.close();
	});
}
