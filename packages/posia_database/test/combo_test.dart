/// Pruebas de combos de precio fijo (llevar productos distintos) en caja.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';

import 'fixture_servicio_admin.dart';

Future<ServicioCaja> _crearServicioCaja(FixtureAdmin fixture) async {
	final base = fixture.base;
	final lotePromocionRepo = LotePromocionRepository(baseDatos: base);
	final comboRepo = ComboRepository(baseDatos: base);
	final productoRepo = ProductoRepository(baseDatos: base);
	final clienteRepo = ClienteRepository(baseDatos: base);
	final inventarioRepo = fixture.inventarioRepository;
	return ServicioCaja(
		productoRepository: productoRepo,
		inventarioRepository: inventarioRepo,
		lotePromocionRepository: lotePromocionRepo,
		comboRepository: comboRepo,
		baseDatos: base,
		clienteRepository: clienteRepo,
		ventaRepository: fixture.ventaRepository,
		motorPrecio: MotorPrecio(
			repositorioPrecio: PrecioRepository(
				baseDatos: base,
				lotePromocionRepository: lotePromocionRepo,
			),
		),
		gestorInventario: GestorInventario(repositorioInventario: inventarioRepo),
		syncOrchestrator: SyncOrchestrator(
			colaLocal: SyncEventRepository(baseDatos: base),
			clienteHub: null,
			clienteLan: null,
			tiendaId: fixture.tiendaOrigenId,
			dispositivoId: cajaPruebaId,
		),
		servicioCarniceria: ServicioCarniceria(),
		tiendaId: fixture.tiendaOrigenId,
		cajaId: cajaPruebaId,
	);
}

void main() {
	group('Combo de precio fijo en carrito', () {
		test('completar el combo descuenta el total del carrito', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final shampoo = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Shampoo',
					codigoBarras: 'combo-001',
					precioBase: 100.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			final acondicionador = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Acondicionador',
					codigoBarras: 'combo-002',
					precioBase: 80.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			await ComboRepository(baseDatos: fixture.base).reemplazarCombo(
				Combo(
					id: 'combo-test-1',
					nombre: 'Kit shampoo + acondicionador',
					precioCombo: 150.0,
					miembros: [
						ComboMiembro(productoId: shampoo.id),
						ComboMiembro(productoId: acondicionador.id),
					],
				),
			);

			final caja = await _crearServicioCaja(fixture);
			await caja.agregarProducto(shampoo, cantidad: 1.0);
			expect(
				caja.calcularTotalCarrito(),
				100.0,
				reason: 'sin el acondicionador el combo no completa',
			);
			await caja.agregarProducto(acondicionador, cantidad: 1.0);
			expect(caja.calcularTotalCarrito(), 150.0);
			expect(caja.obtenerDescuentoCombos(), 30.0);
			final aplicados = await caja.obtenerCombosAplicadosEnCarrito();
			expect(aplicados, hasLength(1));
			expect(aplicados.first.veces, 1);
			await fixture.cerrar();
		});

		test('quitar un miembro del carrito retira el descuento del combo', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final shampoo = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Shampoo',
					codigoBarras: 'combo-011',
					precioBase: 100.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			final acondicionador = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Acondicionador',
					codigoBarras: 'combo-012',
					precioBase: 80.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			await ComboRepository(baseDatos: fixture.base).reemplazarCombo(
				Combo(
					id: 'combo-test-2',
					nombre: 'Kit shampoo + acondicionador',
					precioCombo: 150.0,
					miembros: [
						ComboMiembro(productoId: shampoo.id),
						ComboMiembro(productoId: acondicionador.id),
					],
				),
			);

			final caja = await _crearServicioCaja(fixture);
			await caja.agregarProducto(shampoo, cantidad: 1.0);
			await caja.agregarProducto(acondicionador, cantidad: 1.0);
			expect(caja.calcularTotalCarrito(), 150.0);

			await caja.eliminarLinea(1);
			expect(caja.obtenerDescuentoCombos(), 0.0);
			expect(caja.calcularTotalCarrito(), 100.0);
			await fixture.cerrar();
		});

		test('cobrar con combo aplicado persiste el total correcto', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final shampoo = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Shampoo',
					codigoBarras: 'combo-021',
					precioBase: 100.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			final acondicionador = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Acondicionador',
					codigoBarras: 'combo-022',
					precioBase: 80.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			await ComboRepository(baseDatos: fixture.base).reemplazarCombo(
				Combo(
					id: 'combo-test-3',
					nombre: 'Kit shampoo + acondicionador',
					precioCombo: 150.0,
					miembros: [
						ComboMiembro(productoId: shampoo.id),
						ComboMiembro(productoId: acondicionador.id),
					],
				),
			);

			final caja = await _crearServicioCaja(fixture);
			await caja.agregarProducto(shampoo, cantidad: 1.0);
			await caja.agregarProducto(acondicionador, cantidad: 1.0);
			final venta = await caja.cobrar(
				const CobroRequest(metodoPago: MetodoPago.efectivo, montoRecibido: 150.0),
			);
			expect(venta, isNotNull);
			expect(venta!.total, 150.0);
			expect(venta.descuentoTicket, 30.0);
			await fixture.cerrar();
		});
	});
}
