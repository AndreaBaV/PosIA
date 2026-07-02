/// Pruebas del enrutador de conexion (lecturas readOnly / escrituras WAL).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/src/database/conexion_operativa_ruteada.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	sqfliteFfiInit();

	late Directory dirTemporal;
	late Database escritura;
	late Database lectura;
	late ConexionOperativaRuteada ruteada;

	setUp(() async {
		dirTemporal = await Directory.systemTemp.createTemp('posia_ruteada_');
		final ruta = '${dirTemporal.path}/operativa.db';
		escritura = await databaseFactoryFfi.openDatabase(
			ruta,
			options: OpenDatabaseOptions(
				singleInstance: false,
				onConfigure: (db) async {
					await db.rawQuery('PRAGMA journal_mode=WAL');
					await db.execute('PRAGMA synchronous=NORMAL');
					await db.rawQuery('PRAGMA busy_timeout=5000');
				},
			),
		);
		await MigracionesEsquema.crearEsquemaCompleto(escritura);
		lectura = await databaseFactoryFfi.openDatabase(
			ruta,
			options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
		);
		ruteada = ConexionOperativaRuteada(escritura: escritura, lectura: lectura);
	});

	tearDown(() async {
		await lectura.close();
		await escritura.close();
		if (await dirTemporal.exists()) {
			await dirTemporal.delete(recursive: true);
		}
	});

	test('la conexion de escritura esta en modo WAL', () async {
		final modo = await escritura.rawQuery('PRAGMA journal_mode');
		expect(
			(modo.first.values.first as String).toLowerCase(),
			equals('wal'),
		);
	});

	test('una escritura por el enrutador es visible en la lectura readOnly',
			() async {
		await ruteada.insert('stores', {
			'id': 'tienda-1',
			'nombre': 'Centro',
			'direccion': 'Calle 1',
			'activa': 1,
		});

		final filas = await ruteada.query(
			'stores',
			where: 'id = ?',
			whereArgs: ['tienda-1'],
		);
		expect(filas, hasLength(1));
		expect(filas.first['nombre'], equals('Centro'));
	});

	test('una transaccion por el enrutador queda commiteada y es legible',
			() async {
		await ruteada.transaction((txn) async {
			await txn.insert('stores', {
				'id': 'tienda-2',
				'nombre': 'Norte',
				'direccion': 'Calle 2',
				'activa': 1,
			});
		});

		final filas = await ruteada.rawQuery(
			'SELECT nombre FROM stores WHERE id = ?',
			['tienda-2'],
		);
		expect(filas, hasLength(1));
		expect(filas.first['nombre'], equals('Norte'));
	});

	test('la conexion de lectura no puede escribir (es de solo-lectura)',
			() async {
		expect(
			() => lectura.insert('stores', {
				'id': 'x',
				'nombre': 'x',
				'direccion': 'x',
				'activa': 1,
			}),
			throwsA(isA<DatabaseException>()),
		);
	});
}
