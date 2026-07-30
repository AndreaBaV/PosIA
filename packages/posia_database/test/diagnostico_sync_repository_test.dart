/// Cuarentena de eventos remotos y registro del ultimo error de ciclo.
///
/// Es lo que impide que un evento defectuoso vuelva a congelar el cursor de un
/// dispositivo y lo deje mostrando el catalogo de semanas atras.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SyncEvent _evento(String id, {int seq = 1}) {
	return SyncEvent(
		id: id,
		tiendaId: 'tienda-1',
		dispositivoId: 'caja-escritorio',
		tipo: TipoSyncEvento.productUpserted,
		payload: {'id': 'prod-$id', 'nombre': 'Refresco', 'precioBase': 25.5},
		creadoEn: DateTime.utc(2026, 7, 30, 10),
		estado: EstadoSyncEvento.enviado,
		seq: seq,
	);
}

void main() {
	late Database base;
	late DiagnosticoSyncRepository diagnostico;

	setUp(() async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
		base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		diagnostico = DiagnosticoSyncRepository(baseDatos: base);
	});

	tearDown(() => base.close());

	test('aparta un evento fallido conservando su payload para reintentarlo', () async {
		await diagnostico.registrarEventoFallido(
			evento: _evento('ev-7', seq: 7),
			error: StateError('FOREIGN KEY constraint failed'),
		);

		final apartados = await diagnostico.listarCuarentena();
		expect(apartados, hasLength(1));
		final apartado = apartados.first;
		expect(apartado.evento.id, 'ev-7');
		expect(apartado.evento.seq, 7);
		expect(apartado.evento.tipo, TipoSyncEvento.productUpserted);
		expect(apartado.evento.payload['nombre'], 'Refresco');
		expect(apartado.evento.payload['precioBase'], 25.5);
		expect(apartado.error, contains('FOREIGN KEY'));
		expect(apartado.intentos, 1);
	});

	test('reincidir suma intentos en vez de duplicar la fila', () async {
		await diagnostico.registrarEventoFallido(
			evento: _evento('ev-7'),
			error: 'primer intento',
		);
		await diagnostico.registrarEventoFallido(
			evento: _evento('ev-7'),
			error: 'segundo intento',
		);

		expect(await diagnostico.contarCuarentena(), 1);
		final apartado = (await diagnostico.listarCuarentena()).single;
		expect(apartado.intentos, 2);
		expect(apartado.error, 'segundo intento');
	});

	test('resolver saca el evento de la cuarentena', () async {
		await diagnostico.registrarEventoFallido(
			evento: _evento('ev-7'),
			error: 'error',
		);
		await diagnostico.resolverEventoFallido('ev-7');
		expect(await diagnostico.contarCuarentena(), 0);
	});

	test('la cuarentena sale ordenada por seq para respetar el historial', () async {
		await diagnostico.registrarEventoFallido(
			evento: _evento('ev-30', seq: 30),
			error: 'e',
		);
		await diagnostico.registrarEventoFallido(
			evento: _evento('ev-10', seq: 10),
			error: 'e',
		);

		final ids = (await diagnostico.listarCuarentena())
			.map((a) => a.evento.id)
			.toList();
		expect(ids, ['ev-10', 'ev-30']);
	});

	test('el ultimo error de ciclo se guarda y se limpia con null', () async {
		expect(await diagnostico.leerUltimoErrorCiclo(), isNull);

		await diagnostico.registrarErrorCiclo(StateError('hub inalcanzable'));
		final error = await diagnostico.leerUltimoErrorCiclo();
		expect(error, isNotNull);
		expect(error!.mensaje, contains('hub inalcanzable'));

		await diagnostico.registrarErrorCiclo(null);
		expect(await diagnostico.leerUltimoErrorCiclo(), isNull);
	});

	test('el error registrado no arrastra saltos de linea ni crece sin limite', () async {
		await diagnostico.registrarErrorCiclo(
			Exception('línea1\n${'x' * 900}'),
		);
		final error = await diagnostico.leerUltimoErrorCiclo();
		expect(error!.mensaje.contains('\n'), isFalse);
		expect(error.mensaje.length, lessThanOrEqualTo(500));
	});
}
