/// Pruebas de tickets en espera en caja.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/utils/asegurador_padres_fk.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';

import 'fixture_servicio_admin.dart';

Future<ServicioCaja> _crearServicioCaja(FixtureAdmin fixture) async {
	final base = fixture.base;
	final productoRepo = ProductoRepository(baseDatos: base);
	final clienteRepo = ClienteRepository(baseDatos: base);
	final inventarioRepo = fixture.inventarioRepository;
	return ServicioCaja(
		productoRepository: productoRepo,
		inventarioRepository: inventarioRepo,
		baseDatos: base,
		presentacionRepository: PresentacionRepository(baseDatos: base),
		clienteRepository: clienteRepo,
		ventaRepository: fixture.ventaRepository,
		motorPrecio: MotorPrecio(
			repositorioPrecio: PrecioRepository(baseDatos: base),
		),
		gestorInventario: GestorInventario(repositorioInventario: inventarioRepo),
		syncOrchestrator: SyncOrchestrator(
			colaLocal: SyncEventRepository(baseDatos: base),
			clienteHub: null,
			clienteLan: null,
			tiendaId: fixture.tiendaOrigenId,
			dispositivoId: cajaPruebaId,
		),
		ticketEsperaRepository: TicketEsperaRepository(baseDatos: base),
		tiendaId: fixture.tiendaOrigenId,
		cajaId: cajaPruebaId,
	);
}

void main() {
	group('Tickets en espera', () {
		test('poner y recuperar carrito conserva lineas', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = await _crearServicioCaja(fixture);
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Apartado',
					codigoBarras: '99001',
					precioBase: 20.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 5.0,
				),
			);
			await servicio.agregarProducto(producto, cantidad: 2.0);
			expect(servicio.carritoTieneLineas(), isTrue);
			final ticketId = await servicio.ponerCarritoEnEspera(notas: 'Mesa 1');
			expect(servicio.carritoTieneLineas(), isFalse);
			expect(await servicio.contarTicketsEnEspera(), 1);
			await servicio.recuperarTicketEnEspera(ticketId);
			expect(servicio.obtenerCarrito(), hasLength(1));
			expect(servicio.obtenerCarrito().single.producto.nombre, 'Apartado');
			expect(servicio.calcularTotalCarrito(), 40.0);
			expect(await servicio.contarTicketsEnEspera(), 0);
			await fixture.cerrar();
		});

		test('recuperar no usa stub FK generico si hay snapshot', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = await _crearServicioCaja(fixture);
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Aceite 1L',
					codigoBarras: '99002',
					precioBase: 35.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 10.0,
				),
			);
			await servicio.agregarProducto(producto, cantidad: 1.0);
			final ticketId = await servicio.ponerCarritoEnEspera();

			// Contamina el catalogo como lo haria un stub de auto-healing / FK.
			await fixture.base.update(
				'products',
				{
					'nombre': 'Producto',
					'codigo_barras': '',
					'precio_base': 0.0,
					'costo_unitario': 0.0,
					'notas': '__stub_fk__',
				},
				where: 'id = ?',
				whereArgs: [producto.id],
			);

			await servicio.recuperarTicketEnEspera(ticketId);
			final linea = servicio.obtenerCarrito().single;
			expect(linea.producto.nombre, 'Aceite 1L');
			expect(linea.producto.esStubFk, isFalse);
			expect(linea.precioUnitario, 35.0);
			await fixture.cerrar();
		});

		test('presentacion conserva concepto y factor al recuperar', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = await _crearServicioCaja(fixture);
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Refresco Cola',
					codigoBarras: '99003',
					precioBase: 18.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 100.0,
				),
			);
			const presentacionId = 'pres-caja-cola';
			await PresentacionRepository(baseDatos: fixture.base).guardarPresentacion(
				PresentacionProducto(
					id: presentacionId,
					productoId: producto.id,
					tipoPresentacionId: 'tp-caja',
					nombre: 'Caja 12',
					factorABase: 12.0,
					esPresentacionBase: false,
					precio: 200.0,
					activo: true,
				),
			);
			final presentacion = (await PresentacionRepository(baseDatos: fixture.base)
					.obtenerPorId(presentacionId))!;
			await servicio.agregarPresentacion(presentacion, cantidad: 2.0);
			expect(servicio.obtenerCarrito().single.producto.nombre, 'Refresco Cola - Caja 12');
			expect(servicio.obtenerCarrito().single.factorABase, 12.0);
			expect(servicio.obtenerCarrito().single.productoStockId, producto.id);

			final ticketId = await servicio.ponerCarritoEnEspera();

			// El id de presentacion no vive en products: el asegurador crea fila.
			// Aunque quede como stub generico, el snapshot debe ganar.
			final filaStub = await fixture.base.query(
				'products',
				where: 'id = ?',
				whereArgs: [presentacionId],
			);
			expect(filaStub, isNotEmpty);

			await servicio.recuperarTicketEnEspera(ticketId);
			final linea = servicio.obtenerCarrito().single;
			expect(linea.producto.nombre, 'Refresco Cola - Caja 12');
			expect(linea.producto.nombre, isNot(equals('Producto')));
			expect(linea.factorABase, 12.0);
			expect(linea.productoStockId, producto.id);
			expect(linea.precioUnitario, 200.0);
			await fixture.cerrar();
		});

		test('asegurarProducto usa snapshot en stub de ticket en espera', () async {
			final fixture = await FixtureAdmin.abrir();
			final padres = AseguradorPadresFk(fixture.base);
			await padres.asegurarProducto(
				'id-fantasma-presentacion',
				tiendaId: fixture.tiendaOrigenId,
				nombreSnapshot: 'Galletas - Caja 24',
				codigoBarrasSnapshot: '750999',
				precioSnapshot: 120.0,
			);
			final filas = await fixture.base.query(
				'products',
				where: 'id = ?',
				whereArgs: ['id-fantasma-presentacion'],
			);
			expect(filas.single['nombre'], 'Galletas - Caja 24');
			expect(filas.single['codigo_barras'], '750999');
			expect(filas.single['precio_base'], 120.0);
			expect(filas.single['notas'], '__stub_fk__');
			await fixture.cerrar();
		});
	});
}
