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

		test(
			'no borra la API key guardada si el build no trae POSIA_HUB_API_KEY',
			() async {
				// Regresión: antes se sobreescribia siempre con el valor de
				// build. Si un tecnico corregia la clave a mano desde
				// "Configuración técnica" pero el APK/IPA se compilo sin
				// POSIA_HUB_API_KEY, el siguiente arranque la borraba y volvía
				// a fallar con "Clave API inválida".
				await config.guardarHubUrl('https://hub.ejemplo.code.run');
				await config.guardarHubApiKey('clave-correcta-puesta-a-mano');

				await AprovisionadorDispositivo.refrescarHubConValores(
					config: config,
					urlBuild: 'https://hub.ejemplo.code.run',
					claveBuild: '',
				);

				final clave = await config.obtenerValor(claveConfigHubApiKey);
				expect(clave, 'clave-correcta-puesta-a-mano');
			},
		);

		test('rota la API key cuando el build trae una distinta no vacia',
			() async {
				await config.guardarHubUrl('https://hub.ejemplo.code.run');
				await config.guardarHubApiKey('clave-vieja');

				await AprovisionadorDispositivo.refrescarHubConValores(
					config: config,
					urlBuild: 'https://hub.ejemplo.code.run',
					claveBuild: 'clave-nueva',
				);

				final clave = await config.obtenerValor(claveConfigHubApiKey);
				expect(clave, 'clave-nueva');
			},
		);

		test('normaliza la URL de build quitando barras finales', () async {
			await AprovisionadorDispositivo.refrescarHubConValores(
				config: config,
				urlBuild: 'https://hub.ejemplo.code.run///',
				claveBuild: 'clave',
			);

			final url = await config.obtenerHubUrl();
			expect(url, 'https://hub.ejemplo.code.run');
		});
	});
}
