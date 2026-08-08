/// Pruebas de desafio PIN activo (comparacion de fechas en Dart).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/src/database/migraciones_esquema.dart';
import 'package:posia_database/src/repositories/asistencia_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	sqfliteFfiInit();

	late Directory dir;
	late Database db;
	late AsistenciaRepository repo;

	setUp(() async {
		dir = await Directory.systemTemp.createTemp('posia_asist_');
		db = await databaseFactoryFfi.openDatabase('${dir.path}/t.db');
		await MigracionesEsquema.crearEsquemaCompleto(db);
		await db.insert('stores', {
			'id': 'tienda-1',
			'nombre': 'Centro',
			'direccion': '',
			'activa': 1,
			'latitud': 19.4,
			'longitud': -99.1,
			'radio_metros': 150,
		});
		repo = AsistenciaRepository(baseDatos: db);
	});

	tearDown(() async {
		await db.close();
		if (await dir.exists()) {
			await dir.delete(recursive: true);
		}
	});

	test('obtenerDesafioActivo ignora expirados y devuelve el vigente', () async {
		final ahora = DateTime.now().toUtc();
		await repo.guardarDesafio(
			DesafioAsistencia(
				id: 'viejo',
				tiendaId: 'tienda-1',
				pinHash: 'hash-viejo',
				expiraEn: ahora.subtract(const Duration(minutes: 1)),
				creadoPor: 'admin',
				latitud: 19.4,
				longitud: -99.1,
				activo: true,
			),
		);
		await repo.guardarDesafio(
			DesafioAsistencia(
				id: 'nuevo',
				tiendaId: 'tienda-1',
				pinHash: 'hash-nuevo',
				expiraEn: ahora.add(const Duration(minutes: 10)),
				creadoPor: 'admin',
				latitud: 19.4,
				longitud: -99.1,
				activo: true,
			),
		);

		final activo = await repo.obtenerDesafioActivo('tienda-1');
		expect(activo, isNotNull);
		expect(activo!.id, 'nuevo');
		expect(activo.pinHash, 'hash-nuevo');
	});

	test('desactivarDesafiosTienda deja sin PIN activo', () async {
		final ahora = DateTime.now().toUtc();
		await repo.guardarDesafio(
			DesafioAsistencia(
				id: 'd1',
				tiendaId: 'tienda-1',
				pinHash: 'h',
				expiraEn: ahora.add(const Duration(minutes: 5)),
				creadoPor: 'admin',
				activo: true,
			),
		);
		await repo.desactivarDesafiosTienda('tienda-1');
		expect(await repo.obtenerDesafioActivo('tienda-1'), isNull);
	});

	test('obtenerDesafioPorPin encuentra PIN de otra tienda', () async {
		await db.insert('stores', {
			'id': 'tienda-2',
			'nombre': 'Norte',
			'direccion': '',
			'activa': 1,
			'latitud': 19.5,
			'longitud': -99.2,
			'radio_metros': 150,
		});
		final pin = '4321';
		final hash = HasherPin.codificar(pin);
		await repo.guardarDesafio(
			DesafioAsistencia(
				id: 'otro',
				tiendaId: 'tienda-2',
				pinHash: hash,
				expiraEn: DateTime.now().toUtc().add(const Duration(minutes: 8)),
				creadoPor: 'admin',
				latitud: 19.5,
				longitud: -99.2,
				activo: true,
			),
		);
		final hallado = await repo.obtenerDesafioPorPin(pin);
		expect(hallado, isNotNull);
		expect(hallado!.tiendaId, 'tienda-2');
		expect(await repo.obtenerDesafioPorPin('0000'), isNull);
	});
}
