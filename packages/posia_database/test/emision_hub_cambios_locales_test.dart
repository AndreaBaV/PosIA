/// Emisión al hub de cambios que antes quedaban solo locales.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'fixture_servicio_admin.dart';

void main() {
	test('liquidarCreditoVenta encola saleCompleted con creditoLiquidado', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final cliente = await servicio.registrarCliente(
			nombre: 'Fiado',
			creditoHabilitado: true,
		);
		final venta = Venta(
			id: 'venta-credito-1',
			tiendaId: fixture.tiendaOrigenId,
			cajaId: cajaPruebaId,
			clienteId: cliente.id,
			lineas: const [],
			metodoPago: MetodoPago.credito,
			total: 40.0,
			creadaEn: DateTime.now().toUtc(),
			creditoDias: 15,
		);
		await fixture.ventaRepository.guardar(venta);
		final liquidada = await servicio.liquidarCreditoVenta(venta.id);
		expect(liquidada.creditoLiquidado, isTrue);

		final cola = SyncEventRepository(baseDatos: fixture.base);
		final pendientes = await cola.obtenerPendientes();
		expect(
			pendientes.any(
				(e) =>
					e.tipo == TipoSyncEvento.saleCompleted &&
					e.payload['ventaId'] == venta.id &&
					e.payload['creditoLiquidado'] == true,
			),
			isTrue,
		);
		await fixture.cerrar();
	});

	test('eliminarVenta completada encola saleVoided', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final producto = await servicio.registrarProductoCompleto(
			AltaProductoRequest(
				nombre: 'Frijol',
				codigoBarras: 'void-001',
				precioBase: 15.0,
				categoriaId: fixture.categoriaId,
				stockInicial: 8.0,
			),
		);
		final venta = Venta(
			id: 'venta-borrar-1',
			tiendaId: fixture.tiendaOrigenId,
			cajaId: cajaPruebaId,
			clienteId: null,
			lineas: [
				LineaVenta(
					productoId: producto.id,
					nombreProducto: producto.nombre,
					cantidad: 1.0,
					precioUnitario: 15.0,
					reglaPrecio: ReglaPrecio.precioBase,
				),
			],
			metodoPago: MetodoPago.efectivo,
			total: 15.0,
			creadaEn: DateTime.now().toUtc(),
			estado: EstadoVenta.completada,
		);
		await fixture.ventaRepository.guardar(venta);

		final ok = await servicio.eliminarVenta(venta.id);
		expect(ok, isTrue);
		expect(await fixture.ventaRepository.obtenerPorId(venta.id), isNull);

		final cola = SyncEventRepository(baseDatos: fixture.base);
		final pendientes = await cola.obtenerPendientes();
		expect(
			pendientes.any(
				(e) =>
					e.tipo == TipoSyncEvento.saleVoided &&
					e.payload['ventaId'] == venta.id,
			),
			isTrue,
		);
		await fixture.cerrar();
	});

	test('eliminarCliente encola customerUpserted inactivo', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		final cliente = await servicio.registrarCliente(nombre: 'Temporal');
		await servicio.eliminarCliente(cliente.id);

		final cola = SyncEventRepository(baseDatos: fixture.base);
		final pendientes = await cola.obtenerPendientes();
		final evento = pendientes.lastWhere(
			(e) =>
				e.tipo == TipoSyncEvento.customerUpserted &&
				e.payload['id'] == cliente.id,
		);
		expect(evento.payload['activo'], isFalse);
		await fixture.cerrar();
	});
}
