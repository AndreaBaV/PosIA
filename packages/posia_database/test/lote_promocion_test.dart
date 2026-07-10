/// Pruebas de mayoreo compartido por lote de promocion (mix-and-match).
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
	final productoRepo = ProductoRepository(baseDatos: base);
	final clienteRepo = ClienteRepository(baseDatos: base);
	final inventarioRepo = fixture.inventarioRepository;
	return ServicioCaja(
		productoRepository: productoRepo,
		inventarioRepository: inventarioRepo,
		lotePromocionRepository: lotePromocionRepo,
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
	group('Lote promocion mix-and-match', () {
		test('suma cantidades de distintos SKU del mismo lote', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final a = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Spaguetti',
					codigoBarras: 'lp-001',
					precioBase: 9.0,
					categoriaId: fixture.categoriaId,
					piezasPorCaja: 20,
					precioCaja: 152.0,
					stockInicial: 100.0,
				),
			);
			final b = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Tallarin',
					codigoBarras: 'lp-002',
					precioBase: 9.0,
					categoriaId: fixture.categoriaId,
					piezasPorCaja: 20,
					precioCaja: 152.0,
					stockInicial: 100.0,
				),
			);
			final lote = LotePromocion(
				id: 'lote-test-1',
				codigoExterno: '1',
				nombre: 'Pastas La Moderna',
				cantidadMinima: 20.0,
				precioUnitario: 7.6,
				productoIds: [a.id, b.id],
			);
			await LotePromocionRepository(baseDatos: fixture.base).reemplazarLote(lote);

			final caja = await _crearServicioCaja(fixture);
			await caja.agregarProducto(a, cantidad: 12.0);
			await caja.agregarProducto(b, cantidad: 8.0);
			final lineas = caja.obtenerCarrito();
			expect(lineas, hasLength(2));
			expect(lineas.every((l) => l.precioUnitario == 7.6), isTrue);
			expect(
				lineas.every((l) => l.reglaPrecio == ReglaPrecio.lotePromocion),
				isTrue,
			);
			await fixture.cerrar();
		});

		test('bajo el umbral mantiene precio menudeo', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final a = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Spaguetti',
					codigoBarras: 'lp-011',
					precioBase: 9.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			final b = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Tallarin',
					codigoBarras: 'lp-012',
					precioBase: 9.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 50.0,
				),
			);
			await LotePromocionRepository(baseDatos: fixture.base).reemplazarLote(
				LotePromocion(
					id: 'lote-test-2',
					codigoExterno: '2',
					cantidadMinima: 20.0,
					precioUnitario: 7.6,
					productoIds: [a.id, b.id],
				),
			);
			final caja = await _crearServicioCaja(fixture);
			await caja.agregarProducto(a, cantidad: 5.0);
			await caja.agregarProducto(b, cantidad: 5.0);
			final lineas = caja.obtenerCarrito();
			expect(lineas.every((l) => l.precioUnitario == 9.0), isTrue);
			expect(
				lineas.every((l) => l.reglaPrecio == ReglaPrecio.precioBase),
				isTrue,
			);
			await fixture.cerrar();
		});
	});
}
