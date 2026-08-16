/// Eliminar una categoria exige reasignar sus productos a otra.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/sync/aplicador_eventos_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixture_servicio_admin.dart';

void main() {
	test('no elimina una categoria con productos si no hay destino', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		await servicio.registrarProductoCompleto(
			AltaProductoRequest(
				nombre: 'Arroz',
				codigoBarras: '7501',
				precioBase: 10,
				categoriaId: fixture.categoriaId,
			),
		);
		await expectLater(
			servicio.eliminarCategoria(fixture.categoriaId),
			throwsA(isA<StateError>()),
		);
		final categorias = await servicio.listarCategorias();
		expect(categorias.map((c) => c.id), contains(fixture.categoriaId));
		await fixture.cerrar();
	});

	test('pasa los productos a la categoria destino y oculta la eliminada',
		() async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final destino = await servicio.registrarCategoria(nombre: 'Abarrotes');
		final producto = await servicio.registrarProductoCompleto(
			AltaProductoRequest(
				nombre: 'Frijol',
				codigoBarras: '7502',
				precioBase: 20,
				categoriaId: fixture.categoriaId,
			),
		);

		await servicio.eliminarCategoria(
			fixture.categoriaId,
			categoriaDestinoId: destino.id,
		);

		final categorias = await servicio.listarCategorias();
		expect(categorias.map((c) => c.id), isNot(contains(fixture.categoriaId)));
		expect(categorias.map((c) => c.id), contains(destino.id));

		final movido = await ProductoRepository(baseDatos: fixture.base)
			.obtenerPorId(producto.id);
		expect(movido!.categoriaId, destino.id);

		final cola = SyncEventRepository(baseDatos: fixture.base);
		final eventos = await cola.obtenerPendientes();
		final borrado = eventos.where(
			(e) => e.tipo == TipoSyncEvento.categoryDeleted,
		);
		expect(borrado, isNotEmpty);
		expect(borrado.last.payload['id'], fixture.categoriaId);
		expect(borrado.last.payload['categoriaDestinoId'], destino.id);
		await fixture.cerrar();
	});

	test('permite eliminar una categoria vacia sin destino', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final vacia = await servicio.registrarCategoria(nombre: 'Temporal');
		await servicio.eliminarCategoria(vacia.id);
		final categorias = await servicio.listarCategorias();
		expect(categorias.map((c) => c.id), isNot(contains(vacia.id)));
		await fixture.cerrar();
	});

	test('un evento remoto reasigna productos al destino', () async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
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
		final categorias = CategoriaRepository(baseDatos: base);
		final productos = ProductoRepository(baseDatos: base);
		await categorias.guardar(
			const Categoria(
				id: 'cat-vieja',
				nombre: 'Vieja',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 0,
				activa: true,
			),
		);
		await categorias.guardar(
			const Categoria(
				id: 'cat-nueva',
				nombre: 'Nueva',
				icono: 'shopping_basket',
				colorHex: '#2196F3',
				orden: 1,
				activa: true,
			),
		);
		await productos.guardar(
			const Producto(
				id: 'prod-1',
				nombre: 'Leche',
				codigoBarras: '1',
				precioBase: 15,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
				categoriaId: 'cat-vieja',
			),
		);
		final aplicador = AplicadorEventosSqlite(
			baseDatos: base,
			productoRepository: productos,
			clienteRepository: ClienteRepository(baseDatos: base),
			ventaRepository: VentaRepository(baseDatos: base),
			inventarioRepository: InventarioRepository(baseDatos: base),
			categoriaRepository: categorias,
		);
		await aplicador.aplicarEvento(
			SyncEvent(
				id: 'ev-cat-del',
				tiendaId: 'tienda-1',
				dispositivoId: 'otra-caja',
				tipo: TipoSyncEvento.categoryDeleted,
				payload: const {
					'id': 'cat-vieja',
					'categoriaDestinoId': 'cat-nueva',
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
		expect((await productos.obtenerPorId('prod-1'))!.categoriaId, 'cat-nueva');
		expect((await categorias.obtenerPorId('cat-vieja'))!.activa, isFalse);
		await base.close();
	});

	test('mueve productos por lote sin borrar la categoria origen', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final destino = await servicio.registrarCategoria(nombre: 'Limpia');
		final producto = await servicio.registrarProductoCompleto(
			AltaProductoRequest(
				nombre: 'Azucar',
				codigoBarras: '7503',
				precioBase: 18,
				categoriaId: fixture.categoriaId,
			),
		);

		final movidos = await servicio.moverProductosDeCategoria(
			origenId: fixture.categoriaId,
			destinoId: destino.id,
		);
		expect(movidos, 1);
		expect(
			(await ProductoRepository(baseDatos: fixture.base).obtenerPorId(producto.id))
				!.categoriaId,
			destino.id,
		);
		final categorias = await servicio.listarCategorias();
		expect(categorias.map((c) => c.id), contains(fixture.categoriaId));
		expect(categorias.map((c) => c.id), contains(destino.id));

		final grupos = await servicio.listarGruposProductosCategoria();
		final deDestino = grupos.where((g) => g.origenId == destino.id).single;
		expect(deDestino.muestras, contains('Azucar'));

		final cola = SyncEventRepository(baseDatos: fixture.base);
		final upserts = (await cola.obtenerPendientes()).where(
			(e) =>
				e.tipo == TipoSyncEvento.productUpserted &&
				e.payload['id'] == producto.id,
		);
		expect(upserts, isNotEmpty);
		expect(upserts.last.payload['categoriaId'], destino.id);
		await fixture.cerrar();
	});
}
