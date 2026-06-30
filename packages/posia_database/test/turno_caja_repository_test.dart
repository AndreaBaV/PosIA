import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	sqfliteFfiInit();
	databaseFactory = databaseFactoryFfi;

	group('TurnoCajaRepository', () {
		late Database base;
		late TurnoCajaRepository repo;

		setUp(() async {
			base = await openDatabase(
				inMemoryDatabasePath,
				version: SCHEMA_VERSION,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			repo = TurnoCajaRepository(baseDatos: base);
		});

		tearDown(() async {
			await base.close();
		});

		test('obtenerTurnoAbierto devuelve turno de la tienda sin importar caja', () async {
			const tiendaId = 'tienda-1';
			const cajaA = 'caja-dispositivo-a';
			const cajaB = 'caja-dispositivo-b';
			final turno = TurnoCaja(
				id: 'turno-1',
				tiendaId: tiendaId,
				cajaId: cajaA,
				vendedorId: null,
				fondoInicial: 500,
				totalEfectivo: 0,
				totalTarjeta: 0,
				totalTransferencia: 0,
				totalVentas: 0,
				cantidadVentas: 0,
				abiertoEn: DateTime.utc(2026, 6, 30, 10),
				cerradoEn: null,
				estado: EstadoTurnoCaja.abierto,
			);
			await repo.guardar(turno);

			final encontrado = await repo.obtenerTurnoAbierto(tiendaId);

			expect(encontrado, isNotNull);
			expect(encontrado!.id, 'turno-1');
			expect(encontrado.cajaId, cajaA);

			final otroDispositivo = await repo.obtenerTurnoAbierto(tiendaId);
			expect(otroDispositivo!.id, turno.id);
			expect(otroDispositivo.cajaId, isNot(cajaB));
		});

		test('guardar cierra otros turnos abiertos de la misma tienda', () async {
			const tiendaId = 'tienda-1';
			await repo.guardar(
				TurnoCaja(
					id: 'turno-viejo',
					tiendaId: tiendaId,
					cajaId: 'caja-a',
					vendedorId: null,
					fondoInicial: 100,
					totalEfectivo: 0,
					totalTarjeta: 0,
					totalTransferencia: 0,
					totalVentas: 0,
					cantidadVentas: 0,
					abiertoEn: DateTime.utc(2026, 6, 30, 8),
					cerradoEn: null,
					estado: EstadoTurnoCaja.abierto,
				),
			);
			await repo.guardar(
				TurnoCaja(
					id: 'turno-nuevo',
					tiendaId: tiendaId,
					cajaId: 'caja-b',
					vendedorId: null,
					fondoInicial: 200,
					totalEfectivo: 0,
					totalTarjeta: 0,
					totalTransferencia: 0,
					totalVentas: 0,
					cantidadVentas: 0,
					abiertoEn: DateTime.utc(2026, 6, 30, 9),
					cerradoEn: null,
					estado: EstadoTurnoCaja.abierto,
				),
			);

			final abierto = await repo.obtenerTurnoAbierto(tiendaId);
			expect(abierto?.id, 'turno-nuevo');
		});
	});
}
