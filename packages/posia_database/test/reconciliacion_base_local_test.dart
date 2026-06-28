/// Pruebas de limpieza y diagnostico de SQLite local.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	sqfliteFfiInit();

	Future<Database> abrirBaseTenant() async {
		final base = await databaseFactoryFfi.openDatabase(
			inMemoryDatabasePath,
			options: OpenDatabaseOptions(singleInstance: false),
		);
		await MigracionesEsquema.crearEsquemaCompleto(base);
		return base;
	}

	test('DiagnosticoBaseLocal detecta base vacia tras limpiar ejemplo', () async {
		final base = await abrirBaseTenant();
		var diagnostico = await DiagnosticoBaseLocal.evaluar(base);
		expect(diagnostico.tieneDatosEjemplo, isTrue);
		expect(diagnostico.estaVaciaOperativa, isTrue);

		await LimpiadorBaseLocal.eliminarDatosEjemplo(base);
		diagnostico = await DiagnosticoBaseLocal.evaluar(base);
		expect(diagnostico.tieneDatosEjemplo, isFalse);
		expect(diagnostico.estaVaciaOperativa, isTrue);
		await base.close();
	});

	test('DiagnosticoBaseLocal distingue datos reales de placeholders', () async {
		final base = await abrirBaseTenant();
		await base.insert('stores', {
			'id': 'tienda-real-1',
			'nombre': 'Norte',
			'direccion': 'Calle 1',
			'activa': 1,
		});
		final diagnostico = await DiagnosticoBaseLocal.evaluar(base);
		expect(diagnostico.tieneDatosReales, isTrue);
		expect(diagnostico.tiendasReales, 1);
		expect(diagnostico.tieneDatosEjemplo, isTrue);
		await base.close();
	});

	test('TiendaRepository excluye tienda placeholder de listarActivasOperativas', () async {
		final base = await abrirBaseTenant();
		await base.insert('stores', {
			'id': 'tienda-real-1',
			'nombre': 'Norte',
			'direccion': 'Calle 1',
			'activa': 1,
		});
		final repo = TiendaRepository(baseDatos: base);
		expect((await repo.listarActivas()).length, greaterThanOrEqualTo(2));
		final operativas = await repo.listarActivasOperativas();
		expect(operativas.any((t) => t.id == 'tienda-real-1'), isTrue);
		expect(operativas.any((t) => t.id == 'id-ejemplo-tienda'), isFalse);
		await base.close();
	});

	test('LimpiadorBaseLocal vacia tablas operativas conservando sync_state', () async {
		final base = await abrirBaseTenant();
		await base.insert('stores', {
			'id': 'tienda-real-1',
			'nombre': 'Norte',
			'direccion': 'Calle 1',
			'activa': 1,
		});
		await base.insert('sync_state', {
			'clave': 'last_synced_event_seq',
			'valor': '15',
		});
		await LimpiadorBaseLocal.vaciarDatosOperativos(base);
		final tiendas = await base.query('stores');
		final sync = await base.query('sync_state');
		expect(tiendas, isEmpty);
		expect(sync, isNotEmpty);
		expect(sync.first['valor'], '15');
		await base.close();
	});
}
