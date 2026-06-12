/// Pruebas de repositorios de configuracion y cursor sync.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 16:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 16:10:00 (UTC-6)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	sqfliteFfiInit();

	/// Abre base en memoria con tablas de configuracion.
	Future<Database> abrirBasePrueba() async {
		final base = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
		await base.execute(
			'CREATE TABLE app_config (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
		);
		await base.execute(
			'CREATE TABLE sync_state (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
		);
		return base;
	}

	test('ConfigRepository guarda y normaliza URL del hub', () async {
		final base = await abrirBasePrueba();
		final repositorio = ConfigRepository(baseDatos: base);
		await repositorio.guardarHubUrl('http://servidor:8080/');
		final url = await repositorio.obtenerHubUrl();
		expect(url, 'http://servidor:8080');
		await base.close();
	});

	test('ConfigRepository retorna null sin URL configurada', () async {
		final base = await abrirBasePrueba();
		final repositorio = ConfigRepository(baseDatos: base);
		final url = await repositorio.obtenerHubUrl();
		expect(url, isNull);
		await base.close();
	});

	test('ConfigRepository guarda PIN administrativo', () async {
		final base = await abrirBasePrueba();
		final repositorio = ConfigRepository(baseDatos: base);
		await repositorio.guardarValor(CLAVE_CONFIG_PIN_ADMIN, '5678');
		final pin = await repositorio.obtenerValor(CLAVE_CONFIG_PIN_ADMIN);
		expect(pin, '5678');
		await base.close();
	});

	test('SyncStateRepository persiste cursor del hub', () async {
		final base = await abrirBasePrueba();
		final repositorio = SyncStateRepository(baseDatos: base);
		expect(await repositorio.leerCursorHub(), 0);
		await repositorio.guardarCursorHub(42);
		expect(await repositorio.leerCursorHub(), 42);
		await base.close();
	});
}
