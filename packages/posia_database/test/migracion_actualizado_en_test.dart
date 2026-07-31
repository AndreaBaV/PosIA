/// Regresion: `migrarVersion38A39` debe poder reintentarse sin tronar.
///
/// Incidente real: un dispositivo cuya apertura en dos fases se reintento
/// (fase 2 vuelve a abrir con `onUpgrade` en el siguiente arranque si la
/// corrida previa no completo) volvio a ejecutar `ALTER TABLE products ADD
/// COLUMN actualizado_en` sobre una base que ya tenia la columna, y
/// `DatabaseException: duplicate column name` tumbaba la pantalla de login
/// antes de que el usuario pudiera hacer nada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	test('migrarVersion38A39 no truena si se ejecuta dos veces', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);

		// crearEsquemaCompleto ya la corrio una vez al crear la base; un
		// reintento (el escenario real que causo el incidente) no debe lanzar.
		await MigracionesEsquema.migrarVersion38A39(base);
		await MigracionesEsquema.migrarVersion38A39(base);

		final columnas = await base.rawQuery('PRAGMA table_info(products)');
		final ocurrencias = columnas.where((c) => c['name'] == 'actualizado_en');
		expect(ocurrencias.length, 1);

		await base.close();
	});
}
