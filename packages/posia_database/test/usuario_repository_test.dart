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

		test('generarSiguienteCodigo evita codigos reservados', () async {
			await repo.guardar(
				const Usuario(
					id: 'u-emp1',
					nombre: 'Ana',
					codigo: 'EMP001',
					pin: '1234',
					rol: RolUsuario.empleado,
					activo: true,
					tiendaId: 't-1',
				),
			);
			final codigo = await repo.generarSiguienteCodigo(
				RolUsuario.empleado,
				codigosReservados: {'EMP002'},
			);
			expect(codigo, 'EMP003');
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

		test('guardarRemoto replica hash y respeta actualizadoEn', () async {
			await repo.guardar(
				const Usuario(
					id: 'u-local',
					nombre: 'Local',
					codigo: '3002',
					pin: '3456',
					rol: RolUsuario.empleado,
					activo: true,
					tiendaId: 't-1',
				),
			);
			final snapshot = await repo.obtenerSnapshotSync('u-local');
			expect(snapshot, isNotNull);

			final aplicado = await repo.guardarRemoto(
				id: 'u-remoto',
				nombre: 'Remoto',
				codigo: '3003',
				rol: RolUsuario.empleado,
				tiendaId: 't-1',
				activo: true,
				pinCredencial: snapshot!.pinCredencial,
				creadoEn: snapshot.creadoEn,
				actualizadoEn: snapshot.actualizadoEn,
			);
			expect(aplicado, isTrue);
			final remoto = await repo.autenticar('3003', '3456');
			expect(remoto?.nombre, 'Remoto');

			final rechazado = await repo.guardarRemoto(
				id: 'u-local',
				nombre: 'Viejo',
				codigo: '3002',
				rol: RolUsuario.empleado,
				tiendaId: 't-1',
				activo: true,
				pinCredencial: snapshot.pinCredencial,
				creadoEn: '2020-01-01T00:00:00.000Z',
				actualizadoEn: '2020-01-01T00:00:00.000Z',
			);
			expect(rechazado, isFalse);
			final sigue = await repo.obtenerPorId('u-local');
			expect(sigue?.nombre, 'Local');
		});

		test('listarTodos tolera rol invalido de insercion manual', () async {
			final ahora = DateTime.now().toUtc().toIso8601String();
			await base.insert('usuarios', {
				'id': 'u-manual',
				'nombre': 'Supervisor manual',
				'codigo': 'SUP999',
				'pin_credencial': HasherPin.codificar('1234'),
				'rol': 'Supervisor',
				'tienda_id': 't-1',
				'activo': 1,
				'creado_en': ahora,
				'actualizado_en': ahora,
			});
			final usuarios = await repo.listarTodos();
			final manual = usuarios.where((u) => u.id == 'u-manual').firstOrNull;
			expect(manual, isNotNull);
			expect(manual!.rol, RolUsuario.empleado);
		});
	});
}
