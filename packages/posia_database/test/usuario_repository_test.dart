import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	sqfliteFfiInit();
	databaseFactory = databaseFactoryFfi;

	group('UsuarioRepository seguro', () {
		late Database base;
		late UsuarioRepository repo;

		setUp(() async {
			base = await openDatabase(
				inMemoryDatabasePath,
				version: SCHEMA_VERSION,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			repo = UsuarioRepository(baseDatos: base);
		});

		tearDown(() => base.close());

		test('no permite codigos duplicados', () async {
			const usuario = Usuario(
				id: 'u-1',
				nombre: 'Ana',
				codigo: '1000',
				pin: '1234',
				rol: RolUsuario.administrador,
				activo: true,
			);
			await repo.guardar(usuario);
			expect(
				() => repo.guardar(
					Usuario(
						id: 'u-2',
						nombre: 'Otra',
						codigo: '1000',
						pin: '2345',
						rol: RolUsuario.empleado,
						activo: true,
						tiendaId: 't-1',
					),
				),
				throwsA(isA<StateError>()),
			);
		});

		test('autentica con pin hasheado y rechaza pin incorrecto', () async {
			await repo.guardar(
				const Usuario(
					id: 'u-emp',
					nombre: 'Pedro',
					codigo: '3001',
					pin: '3456',
					rol: RolUsuario.empleado,
					activo: true,
					tiendaId: 't-1',
				),
			);
			final ok = await repo.autenticar('3001', '3456');
			final mal = await repo.autenticar('3001', '1234');
			expect(ok?.nombre, 'Pedro');
			expect(ok?.pin, isNull);
			expect(mal, isNull);
		});
	});
}
