/// Regresion: un snapshot remoto incompleto no debe borrar empaques locales.
///
/// `productPresentationsReplaced` viaja como lista completa y se aplicaba con un
/// DELETE de todas las presentaciones del producto. Un equipo con el catalogo
/// atrasado borraba asi el empaque recien creado en otro equipo — y de paso los
/// que ya existian.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/sync/aplicador_eventos_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PresentacionProducto _pres(String id, String nombre, double factor) =>
	PresentacionProducto(
		id: id,
		productoId: 'prod-arroz',
		tipoPresentacionId: 'tp-kg',
		nombre: nombre,
		factorABase: factor,
		esPresentacionBase: false,
		codigoBarras: '',
		precio: factor * 24.0,
		activo: true,
	);

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	Future<Database> abrir() async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');
		await base.insert('stores', {
			'id': 'tienda-1',
			'nombre': 'Centro',
			'direccion': '',
			'activa': 1,
		});
		await ProductoRepository(baseDatos: base).guardar(
			const Producto(
				id: 'prod-arroz',
				nombre: 'Arroz Morelos',
				codigoBarras: '750001',
				precioBase: 25.0,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
			),
		);
		return base;
	}

	test('snapshot vacio no borra los empaques existentes', () async {
		final base = await abrir();
		final repo = PresentacionRepository(baseDatos: base);
		await repo.guardarPresentacion(_pres('p1', 'Bulto 25 kg', 25.0));
		await repo.guardarPresentacion(_pres('p2', 'Caja x12', 12.0));

		final aplicador = AplicadorEventosSqlite(
			baseDatos: base,
			productoRepository: ProductoRepository(baseDatos: base),
			clienteRepository: ClienteRepository(baseDatos: base),
			ventaRepository: VentaRepository(baseDatos: base),
			inventarioRepository: InventarioRepository(baseDatos: base),
			presentacionRepository: repo,
		);
		await aplicador.aplicarEvento(
			SyncEvent(
				id: 'ev-vacio',
				tiendaId: 'tienda-1',
				dispositivoId: 'otro-equipo',
				tipo: TipoSyncEvento.productPresentationsReplaced,
				payload: const {'productoId': 'prod-arroz', 'presentaciones': []},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);

		final quedan = await repo.listarPorProducto('prod-arroz');
		expect(
			quedan.map((p) => p.nombre),
			containsAll(['Bulto 25 kg', 'Caja x12']),
			reason: 'un snapshot vacio no puede vaciar el producto',
		);
		await base.close();
	});

	test('snapshot parcial conserva lo que no menciona y agrega lo nuevo', () async {
		final base = await abrir();
		final repo = PresentacionRepository(baseDatos: base);
		await repo.guardarPresentacion(_pres('p1', 'Bulto 25 kg', 25.0));
		await repo.guardarPresentacion(_pres('p2', 'Caja x12', 12.0));

		final aplicador = AplicadorEventosSqlite(
			baseDatos: base,
			productoRepository: ProductoRepository(baseDatos: base),
			clienteRepository: ClienteRepository(baseDatos: base),
			ventaRepository: VentaRepository(baseDatos: base),
			inventarioRepository: InventarioRepository(baseDatos: base),
			presentacionRepository: repo,
		);
		// Equipo atrasado: solo conoce p1 y ademas trae uno nuevo.
		await aplicador.aplicarEvento(
			SyncEvent(
				id: 'ev-parcial',
				tiendaId: 'tienda-1',
				dispositivoId: 'otro-equipo',
				tipo: TipoSyncEvento.productPresentationsReplaced,
				payload: const {
					'productoId': 'prod-arroz',
					'presentaciones': [
						{
							'id': 'p1',
							'nombre': 'Bulto 25 kg',
							'factorABase': 25.0,
							'esPresentacionBase': false,
							'codigoBarras': '',
							'activo': true,
						},
						{
							'id': 'p3',
							'nombre': 'Caja x20',
							'factorABase': 20.0,
							'esPresentacionBase': false,
							'codigoBarras': '',
							'activo': true,
						},
					],
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);

		final quedan = (await repo.listarPorProducto('prod-arroz'))
			.map((p) => p.nombre)
			.toList();
		expect(quedan, contains('Caja x12'), reason: 'no mencionada, se conserva');
		expect(quedan, contains('Caja x20'), reason: 'nueva, se agrega');
		expect(quedan, contains('Bulto 25 kg'));
		await base.close();
	});
}
