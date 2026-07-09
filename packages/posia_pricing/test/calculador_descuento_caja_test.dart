/// Pruebas de descuentos manuales en caja con precio minimo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:test/test.dart';

Producto _producto({
	double precioBase = 200.0,
	double costoUnitario = 100.0,
}) {
	return Producto(
		id: 'p1',
		nombre: 'Producto prueba',
		codigoBarras: '123',
		precioBase: precioBase,
		unidadMedida: UnidadMedida.pieza,
		rutaImagen: '',
		activo: true,
		tiendaId: 't1',
		costoUnitario: costoUnitario,
	);
}

LineaCarrito _linea({
	double cantidad = 2.0,
	double precioUnitario = 200.0,
	double costoUnitario = 100.0,
	double factorABase = 1.0,
}) {
	return LineaCarrito(
		producto: _producto(precioBase: precioUnitario, costoUnitario: costoUnitario),
		cantidad: cantidad,
		precioUnitario: precioUnitario,
		reglaPrecio: ReglaPrecio.precioBase,
		factorABase: factorABase,
	);
}

void main() {
	test('calcularDescuentoMaximoLinea respeta precio minimo', () {
		final linea = _linea(cantidad: 2.0, precioUnitario: 200.0, costoUnitario: 100.0);
		// Bruto 400, minimo 2 * 101 = 202, max descuento 198
		expect(calcularDescuentoMaximoLinea(linea), 198.0);
	});

	test('errorDescuentoLinea rechaza descuento sobre el maximo', () {
		final linea = _linea();
		expect(errorDescuentoLinea(linea, 199.0), isNotNull);
		expect(errorDescuentoLinea(linea, 198.0), isNull);
	});

	test('calcularDescuentoLineaDesdePorcentaje redondea a 2 decimales', () {
		final linea = _linea(cantidad: 3.0, precioUnitario: 33.33);
		expect(
			calcularDescuentoLineaDesdePorcentaje(linea, 10.0),
			10.0,
		);
	});

	test('calcularDescuentoMaximoTicket considera minimos por linea', () {
		final lineas = [
			_linea(cantidad: 1.0, precioUnitario: 150.0, costoUnitario: 100.0),
			_linea(cantidad: 1.0, precioUnitario: 80.0, costoUnitario: 50.0),
		];
		// Subtotal 230, minimo 101 + 50.5 = 151.5, max ticket 78.5
		expect(calcularDescuentoMaximoTicket(lineas), 78.5);
	});

	test('presentacion usa precio minimo de empaque', () {
		final linea = _linea(
			cantidad: 1.0,
			precioUnitario: 240.0,
			costoUnitario: 10.0,
			factorABase: 12.0,
		);
		final minimo = calcularPrecioMinimoPresentacion(10.0, 12.0);
		expect(calcularTotalMinimoLinea(linea), minimo);
		expect(calcularDescuentoMaximoLinea(linea), redondearMonto(240.0 - minimo));
	});
}
