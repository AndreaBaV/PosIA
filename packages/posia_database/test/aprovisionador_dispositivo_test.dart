import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	sqfliteFfiInit();
	databaseFactory = databaseFactoryFfi;

	group('AprovisionadorDispositivo', () {
		late Database base;
		late ConfigRepository config;

		setUp(() async {
			base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: MigracionesEsquema.crearEsquemaDispositivo,
			);
			config = ConfigRepository(baseDatos: base);
		});

		tearDown(() => base.close());

		test('asigna caja unica sin marcar instalacion completa', () async {
			expect(await config.esInstalacionCompleta(), isFalse);

			await AprovisionadorDispositivo.asegurar(config);

			expect(await config.esInstalacionCompleta(), isFalse);
			final dispositivo = await config.obtenerConfigDispositivo();
			expect(dispositivo.tenantId, isEmpty);
			expect(dispositivo.cajaId, isNotEmpty);
			expect(dispositivo.cajaId.length, greaterThan(20));
		});

		test('es idempotente tras la primera ejecucion', () async {
			await AprovisionadorDispositivo.asegurar(config);
			final primera = await config.obtenerConfigDispositivo();

			await AprovisionadorDispositivo.asegurar(config);
			final segunda = await config.obtenerConfigDispositivo();

			expect(segunda.cajaId, primera.cajaId);
		});
	});
}
