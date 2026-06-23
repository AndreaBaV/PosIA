/// Pruebas de validacion y leyenda de credito a clientes.
library;

import 'package:test/test.dart';
import 'package:posia_core/posia_core.dart';

Cliente _clienteBase({
	bool creditoHabilitado = true,
	String telefono = '5551234567',
	String direccion = 'Calle 1 #2',
}) {
	return Cliente(
		id: 'c1',
		nombre: 'Juan Perez',
		listaPreciosId: null,
		creditoHabilitado: creditoHabilitado,
		activo: true,
		telefono: telefono,
		direccion: direccion,
	);
}

void main() {
	test('clienteTieneDatosCredito exige telefono y direccion', () {
		expect(clienteTieneDatosCredito(_clienteBase()), true);
		expect(
			clienteTieneDatosCredito(_clienteBase(telefono: '')),
			false,
		);
		expect(
			clienteTieneDatosCredito(_clienteBase(direccion: '')),
			false,
		);
	});

	test('validarClienteParaCredito rechaza sin datos', () {
		expect(
			validarClienteParaCredito(_clienteBase(telefono: '')),
			isNotNull,
		);
		expect(validarClienteParaCredito(_clienteBase()), isNull);
	});

	test('generarLeyendaCompromisoCredito incluye plazo y monto', () {
		final leyenda = generarLeyendaCompromisoCredito(
			total: 500.0,
			diasCredito: 15,
			fechaVencimiento: DateTime(2026, 7, 7),
			nombreCliente: 'Juan Perez',
		);
		expect(leyenda, contains('500'));
		expect(leyenda, contains('15 dia(s)'));
		expect(leyenda, contains('07/07/2026'));
	});

	test('ticket de credito incluye firma y leyenda', () {
		final venta = Venta(
			id: 'venta-credito-001',
			tiendaId: 't1',
			cajaId: 'c1',
			clienteId: 'c1',
			total: 250.0,
			metodoPago: MetodoPago.credito,
			estado: EstadoVenta.completada,
			creadaEn: DateTime.utc(2026, 6, 22, 18),
			creditoDias: 30,
			creditoVenceEn: DateTime.utc(2026, 7, 22),
			lineas: const [
				LineaVenta(
					productoId: 'p1',
					nombreProducto: 'Refresco',
					cantidad: 2,
					precioUnitario: 125.0,
					reglaPrecio: ReglaPrecio.precioBase,
				),
			],
		);
		final texto = generarTextoTicket(
			venta: venta,
			nombreTienda: 'Tienda Centro',
			nombreCliente: 'Maria Lopez',
			telefonoCliente: '5559998888',
			direccionCliente: 'Av. Norte 100',
		);
		expect(texto, contains('VENTA A CREDITO'));
		expect(texto, contains('FIRMA DEL CLIENTE'));
		expect(texto, contains('30 dia(s)'));
		expect(texto, contains('Dir: Av. Norte 100'));
	});
}
