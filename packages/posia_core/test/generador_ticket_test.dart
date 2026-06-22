import 'package:test/test.dart';
import 'package:posia_core/posia_core.dart';

void main() {
	test('generarTextoTicket incluye total y tienda', () {
		final venta = Venta(
			id: 'venta-test-001',
			tiendaId: 'tienda-test',
			cajaId: 'caja-1',
			clienteId: null,
			total: 100.0,
			metodoPago: MetodoPago.efectivo,
			estado: EstadoVenta.completada,
			creadaEn: DateTime.utc(2026, 6, 11),
			lineas: const [
				LineaVenta(
					productoId: 'prod-1',
					nombreProducto: 'Producto demo',
					cantidad: 2,
					precioUnitario: 50.0,
					reglaPrecio: ReglaPrecio.precioBase,
				),
			],
		);
		final texto = generarTextoTicket(venta: venta, nombreTienda: 'Tienda Centro');
		expect(texto, contains('Tienda Centro'));
		expect(texto, contains('TOTAL'));
		expect(texto, contains('100'));
	});

	test('generarTextoCorteCaja incluye efectivo esperado', () {
		final turno = TurnoCaja(
			id: 'turno-test-001',
			tiendaId: 'tienda-test',
			cajaId: 'caja-1',
			vendedorId: null,
			fondoInicial: 500.0,
			totalEfectivo: 1200.0,
			totalTarjeta: 0.0,
			totalTransferencia: 0.0,
			totalVentas: 1200.0,
			cantidadVentas: 8,
			abiertoEn: DateTime.utc(2026, 6, 11, 8),
			cerradoEn: DateTime.utc(2026, 6, 11, 20),
			estado: EstadoTurnoCaja.cerrado,
		);
		final texto = generarTextoCorteCaja(turno: turno, nombreTienda: 'Tienda Centro');
		expect(texto, contains('CORTE DE CAJA'));
		expect(texto, contains('1700'));
	});
}
