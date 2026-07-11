/// Pruebas de integridad referencial al guardar usuarios remotos.
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

	test('guardarRemoto crea padres FK faltantes antes de insertar usuario', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');

		final repo = UsuarioRepository(baseDatos: base);
		final ahora = DateTime.now().toUtc().toIso8601String();
		final aplicado = await repo.guardarRemoto(
			id: 'EMP001',
			nombre: 'BRITANY',
			codigo: 'EMP001',
			rol: RolUsuario.empleado,
			tiendaId: 'tienda-sur',
			rolPersonalizadoId: 'e33b3401-03fb-4070-ab6c-8c916fb530f8',
			activo: true,
			pinCredencial: 'hash-pin',
			creadoEn: ahora,
			actualizadoEn: ahora,
		);

		expect(aplicado, isTrue);
		final tiendas = await base.query('stores', where: 'id = ?', whereArgs: ['tienda-sur']);
		expect(tiendas, isNotEmpty);
		final roles = await base.query(
			'roles_personalizados',
			where: 'id = ?',
			whereArgs: ['e33b3401-03fb-4070-ab6c-8c916fb530f8'],
		);
		expect(roles, isNotEmpty);
		final usuarios = await base.query('usuarios', where: 'id = ?', whereArgs: ['EMP001']);
		expect(usuarios, isNotEmpty);
		expect(usuarios.first['tienda_id'], 'tienda-sur');
		expect(
			usuarios.first['rol_personalizado_id'],
			'e33b3401-03fb-4070-ab6c-8c916fb530f8',
		);

		final fkCheck = await base.rawQuery('PRAGMA foreign_key_check');
		expect(fkCheck, isEmpty);

		await base.close();
	});
}
