/// Pruebas de validacion de precios contra costo.
library;

import 'package:test/test.dart';
import 'package:posia_core/posia_core.dart';

void main() {
	test('calcularPrecioMinimoVenta aplica margen sobre costo', () {
		expect(calcularPrecioMinimoVenta(100.0), 101.0);
		expect(calcularPrecioMinimoVenta(0.0), 0.01);
	});

	test('precioVentaEsValido rechaza precio bajo costo', () {
		expect(precioVentaEsValido(100.0, 100.0), false);
		expect(precioVentaEsValido(101.0, 100.0), true);
		expect(precioVentaEsValido(50.0, 100.0), false);
	});

	test('calcularPrecioVentaDesdeUtilidad sobre costo', () {
		expect(
			calcularPrecioVentaDesdeUtilidad(
				costoUnitario: 100.0,
				porcentajeUtilidad: 25.0,
				modo: ModoCalculoUtilidad.sobreCosto,
			),
			125.0,
		);
	});

	test('calcularPrecioVentaDesdeUtilidad sobre precio venta', () {
		expect(
			calcularPrecioVentaDesdeUtilidad(
				costoUnitario: 75.0,
				porcentajeUtilidad: 25.0,
				modo: ModoCalculoUtilidad.sobrePrecioVenta,
			),
			100.0,
		);
	});

	test('calcularUtilidadPorcentaje es inverso del calculo', () {
		const costo = 80.0;
		const precio = 100.0;
		expect(
			calcularUtilidadPorcentaje(
				costoUnitario: costo,
				precioVenta: precio,
				modo: ModoCalculoUtilidad.sobreCosto,
			),
			25.0,
		);
		expect(
			calcularUtilidadPorcentaje(
				costoUnitario: costo,
				precioVenta: precio,
				modo: ModoCalculoUtilidad.sobrePrecioVenta,
			),
			20.0,
		);
	});

	test('precioPresentacionEsValido valida precio total del paquete', () {
		expect(calcularPrecioMinimoPresentacion(10.0, 12.0), 121.2);
		expect(precioPresentacionEsValido(120.0, 10.0, 12.0), false);
		expect(precioPresentacionEsValido(121.2, 10.0, 12.0), true);
	});

	test('errorPrecioVentaDesdeTexto interpreta coma decimal', () {
		expect(
			errorPrecioVentaDesdeTexto('101,00', costoUnitario: 100.0),
			isNull,
		);
		expect(
			errorPrecioVentaDesdeTexto('100,00', costoUnitario: 100.0),
			isNotNull,
		);
	});
}
