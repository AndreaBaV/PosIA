/// Pruebas de integridad referencial al guardar productos remotos.
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

	test('guardar producto crea tienda, categoría y proveedor padre faltantes', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');

		const tiendaId = 'tienda-sur';
		const categoriaId = 'cat-leches';
		const proveedorId = 'prov-lala';

		final repo = ProductoRepository(baseDatos: base);
		await repo.guardar(
			Producto(
				id: 'a7d1ae4e-c6f9-43ed-a359-8c768aeedefe',
				nombre: 'Leche Santa Clara',
				codigoBarras: '235532456455',
				precioBase: 32.0,
				unidadMedida: UnidadMedida.pieza,
				activo: true,
				tiendaId: tiendaId,
				categoriaId: categoriaId,
				proveedorId: proveedorId,
			),
		);

		expect(
			await base.query('stores', where: 'id = ?', whereArgs: [tiendaId]),
			isNotEmpty,
		);
		expect(
			await base.query('categories', where: 'id = ?', whereArgs: [categoriaId]),
			isNotEmpty,
		);
		expect(
			await base.query('proveedores', where: 'id = ?', whereArgs: [proveedorId]),
			isNotEmpty,
		);
		expect(
			await base.query(
				'products',
				where: 'id = ?',
				whereArgs: ['a7d1ae4e-c6f9-43ed-a359-8c768aeedefe'],
			),
			isNotEmpty,
		);

		final fkCheck = await base.rawQuery('PRAGMA foreign_key_check');
		expect(fkCheck, isEmpty);

		await base.close();
	});
}
