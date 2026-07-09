/// Pruebas de fusion de lineas del carrito en caja.
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
	final productoRepo = ProductoRepository(baseDatos: base);
	final clienteRepo = ClienteRepository(baseDatos: base);
	final inventarioRepo = fixture.inventarioRepository;
	return ServicioCaja(
		productoRepository: productoRepo,
		inventarioRepository: inventarioRepo,
		baseDatos: base,
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
		servicioCarniceria: ServicioCarniceria(),
		tiendaId: fixture.tiendaOrigenId,
		cajaId: cajaPruebaId,
	);
}

void main() {
	group('Fusion de lineas en carrito', () {
		test('producto general suma cantidades en una sola linea', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Refresco',
					codigoBarras: '88001',
					precioBase: 15.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 20.0,
				),
			);
			final servicio = await _crearServicioCaja(fixture);
			await servicio.agregarProducto(producto, cantidad: 2.0);
			await servicio.agregarProducto(producto, cantidad: 3.0);
			final lineas = servicio.obtenerCarrito();
			expect(lineas, hasLength(1));
			expect(lineas.first.cantidad, 5.0);
			await fixture.cerrar();
		});

		test('producto por peso fusiona aunque haya otro articulo en medio', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final huevo = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Huevo',
					codigoBarras: '88002',
					precioBase: 50.0,
					categoriaId: fixture.categoriaId,
					unidadMedida: UnidadMedida.kilogramo,
					stockInicial: 100.0,
				),
			);
			final leche = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Leche',
					codigoBarras: '88003',
					precioBase: 12.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 30.0,
				),
			);
			final servicio = await _crearServicioCaja(fixture);
			expect(await servicio.agregarProductoConPeso(huevo, 0.5), isEmpty);
			await servicio.agregarProducto(leche, cantidad: 12.0);
			expect(await servicio.agregarProductoConPeso(huevo, 4.0), isEmpty);
			final lineas = servicio.obtenerCarrito();
			expect(lineas, hasLength(2));
			final lineaHuevo = lineas.firstWhere((l) => l.producto.id == huevo.id);
			expect(lineaHuevo.cantidad, closeTo(4.5, 0.001));
			final lineaLeche = lineas.firstWhere((l) => l.producto.id == leche.id);
			expect(lineaLeche.cantidad, 12.0);
			await fixture.cerrar();
		});

		test('dos medios kilos con sobrecargo conservan total de cada pesaje', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final escalas = construirEscalasDesdePreciosCorte(
				precioKilo: 30.0,
				precioMedio: 20.0,
				precioCuarto: 22.0,
			)
				.map(
					(e) => EscalaMayoreo(
						productoId: '',
						cantidadMinima: e.cantidadMinima,
						precioUnitario: e.precioUnitario,
					),
				)
				.toList();
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Arroz a granel',
					codigoBarras: '88004',
					precioBase: 30.0,
					categoriaId: fixture.categoriaId,
					unidadMedida: UnidadMedida.kilogramo,
					stockInicial: 100.0,
					escalasMayoreo: escalas,
				),
			);
			final servicio = await _crearServicioCaja(fixture);
			expect(await servicio.agregarProductoConPeso(producto, 0.5), isEmpty);
			expect(await servicio.agregarProductoConPeso(producto, 0.5), isEmpty);
			final linea = servicio.obtenerCarrito().single;
			expect(linea.cantidad, closeTo(1.0, 0.001));
			expect(redondearMonto(linea.cantidad * linea.precioUnitario), 40.0);
			await fixture.cerrar();
		});

		test('26 kg sueltos aplican precio de bulto 20 kg desde empaque', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Arroz Morelos',
					codigoBarras: '88005',
					precioBase: 27.0,
					categoriaId: fixture.categoriaId,
					unidadMedida: UnidadMedida.kilogramo,
					stockInicial: 200.0,
				),
			);
			await PresentacionRepository(baseDatos: fixture.base).guardarPresentacion(
				PresentacionProducto(
					id: 'pres-bulto-arroz',
					productoId: producto.id,
					tipoPresentacionId: 'tp-kg',
					nombre: 'Bulto 20 kg',
					factorABase: 20.0,
					esPresentacionBase: false,
					precio: 500.0,
					activo: true,
				),
			);
			final servicio = await _crearServicioCaja(fixture);
			expect(await servicio.agregarProductoConPeso(producto, 26.0), isEmpty);
			final linea = servicio.obtenerCarrito().single;
			expect(linea.cantidad, closeTo(26.0, 0.001));
			expect(linea.precioUnitario, 25.0);
			expect(linea.reglaPrecio, ReglaPrecio.escalaMayoreo);
			expect(redondearMonto(linea.cantidad * linea.precioUnitario), 650.0);
			await fixture.cerrar();
		});

		test('pesajes que suman bulto recalculan precio de mayoreo', () async {
			final fixture = await FixtureAdmin.abrir();
			final servicioAdmin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final producto = await servicioAdmin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Frijol',
					codigoBarras: '88006',
					precioBase: 35.0,
					categoriaId: fixture.categoriaId,
					unidadMedida: UnidadMedida.kilogramo,
					stockInicial: 200.0,
				),
			);
			await PresentacionRepository(baseDatos: fixture.base).guardarPresentacion(
				PresentacionProducto(
					id: 'pres-bulto-frijol',
					productoId: producto.id,
					tipoPresentacionId: 'tp-kg',
					nombre: 'Bulto 20 kg',
					factorABase: 20.0,
					esPresentacionBase: false,
					precio: 600.0,
					activo: true,
				),
			);
			final servicio = await _crearServicioCaja(fixture);
			expect(await servicio.agregarProductoConPeso(producto, 15.0), isEmpty);
			expect(await servicio.agregarProductoConPeso(producto, 11.0), isEmpty);
			final linea = servicio.obtenerCarrito().single;
			expect(linea.cantidad, closeTo(26.0, 0.001));
			expect(linea.precioUnitario, 30.0);
			expect(redondearMonto(linea.cantidad * linea.precioUnitario), 780.0);
			await fixture.cerrar();
		});
	});
}
