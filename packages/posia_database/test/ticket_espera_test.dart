/// Pruebas de tickets en espera en caja.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';

import 'fixture_servicio_admin.dart';

void main() {
	group('Tickets en espera', () {
		test('poner y recuperar carrito conserva lineas', () async {
			final fixture = await FixtureAdmin.abrir();
			final productoRepo = ProductoRepository(baseDatos: fixture.base);
			final clienteRepo = ClienteRepository(baseDatos: fixture.base);
			final ticketRepo = TicketEsperaRepository(baseDatos: fixture.base);
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
			final inventarioRepo = fixture.inventarioRepository;
			final servicio = ServicioCaja(
				productoRepository: productoRepo,
				inventarioRepository: inventarioRepo,
				baseDatos: fixture.base,
				clienteRepository: clienteRepo,
				ventaRepository: fixture.ventaRepository,
				motorPrecio: MotorPrecio(
					repositorioPrecio: PrecioRepository(baseDatos: fixture.base),
				),
				gestorInventario: GestorInventario(repositorioInventario: inventarioRepo),
				syncOrchestrator: SyncOrchestrator(
					colaLocal: SyncEventRepository(baseDatos: fixture.base),
					clienteHub: null,
					clienteLan: null,
					tiendaId: fixture.tiendaOrigenId,
					dispositivoId: cajaPruebaId,
				),
				ticketEsperaRepository: ticketRepo,
				tiendaId: fixture.tiendaOrigenId,
				cajaId: cajaPruebaId,
			);
			await servicio.agregarProducto(producto, cantidad: 2.0);
			expect(servicio.carritoTieneLineas(), isTrue);
			final ticketId = await servicio.ponerCarritoEnEspera(notas: 'Mesa 1');
			expect(servicio.carritoTieneLineas(), isFalse);
			expect(await servicio.contarTicketsEnEspera(), 1);
			await servicio.recuperarTicketEnEspera(ticketId);
			expect(servicio.obtenerCarrito(), hasLength(1));
			expect(servicio.calcularTotalCarrito(), 40.0);
			expect(await servicio.contarTicketsEnEspera(), 0);
			await fixture.cerrar();
		});
	});
}
