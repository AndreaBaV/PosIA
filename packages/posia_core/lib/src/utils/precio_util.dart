/// Validacion de precios de venta contra costo y utilidad minima.
library;

import '../constants/posia_constants.dart';
import '../enums/modo_calculo_utilidad.dart';
import 'moneda_util.dart';

/// Calcula el precio minimo permitido segun costo y margen minimo.
double calcularPrecioMinimoVenta(double costoUnitario) {
	if (costoUnitario <= 0.0) {
		return 0.01;
	}
	final factor = 1.0 + (MARGEN_UTILIDAD_MINIMA_PORCENTAJE / 100.0);
	return redondearMonto(costoUnitario * factor);
}

/// Indica si el precio cumple costo y utilidad minima.
bool precioVentaEsValido(double precioUnitario, double costoUnitario) {
	if (precioUnitario <= 0.0) {
		return false;
	}
	return precioUnitario >= calcularPrecioMinimoVenta(costoUnitario);
}

/// Mensaje de error cuando el precio queda bajo costo o margen minimo.
String mensajePrecioMinimoInvalido(double costoUnitario) {
	final minimo = calcularPrecioMinimoVenta(costoUnitario);
	if (costoUnitario <= 0.0) {
		return 'El precio debe ser mayor a cero';
	}
	return 'El precio no puede ser menor a ${formatearMoneda(minimo)} '
		'(costo ${formatearMoneda(costoUnitario)} + '
		'utilidad mínima $MARGEN_UTILIDAD_MINIMA_PORCENTAJE%)';
}

/// Precio minimo total de una presentacion (precio por paquete).
double calcularPrecioMinimoPresentacion(
	double costoUnitario,
	double factorABase,
) {
	if (factorABase <= 0.0) {
		return calcularPrecioMinimoVenta(costoUnitario);
	}
	return redondearMonto(calcularPrecioMinimoVenta(costoUnitario) * factorABase);
}

/// Valida precio total de presentacion contra costo unitario y factor.
bool precioPresentacionEsValido(
	double precioPaquete,
	double costoUnitario,
	double factorABase,
) {
	if (precioPaquete <= 0.0) {
		return false;
	}
	if (factorABase <= 0.0) {
		return precioVentaEsValido(precioPaquete, costoUnitario);
	}
	return precioVentaEsValido(precioPaquete / factorABase, costoUnitario);
}

/// Mensaje de error para precio de presentacion bajo utilidad minima.
String mensajePrecioMinimoPresentacionInvalido(
	double costoUnitario,
	double factorABase,
) {
	final minimo = calcularPrecioMinimoPresentacion(costoUnitario, factorABase);
	final costoPaquete = factorABase > 0.0
		? redondearMonto(costoUnitario * factorABase)
		: costoUnitario;
	if (costoUnitario <= 0.0) {
		return 'El precio debe ser mayor a cero';
	}
	return 'El precio no puede ser menor a ${formatearMoneda(minimo)} '
		'(costo ${formatearMoneda(costoPaquete)} + '
		'utilidad mínima $MARGEN_UTILIDAD_MINIMA_PORCENTAJE%)';
}

/// Interpreta texto de captura de precio (acepta coma decimal).
double? parsearPrecioTexto(String texto) {
	final limpio = texto.trim().replaceAll(',', '.');
	if (limpio.isEmpty) {
		return null;
	}
	return double.tryParse(limpio);
}

/// Devuelve mensaje de error o null si el precio unitario es valido.
String? errorPrecioVentaDesdeTexto(
	String texto, {
	required double costoUnitario,
	bool obligatorio = true,
}) {
	final precio = parsearPrecioTexto(texto);
	if (precio == null) {
		return obligatorio ? 'Ingrese un precio válido' : null;
	}
	if (precio <= 0.0) {
		return 'Ingrese un precio válido';
	}
	if (!precioVentaEsValido(precio, costoUnitario)) {
		return mensajePrecioMinimoInvalido(costoUnitario);
	}
	return null;
}

/// Devuelve mensaje de error o null si el precio de presentacion es valido.
String? errorPrecioPresentacionDesdeTexto(
	String texto, {
	required double costoUnitario,
	required double factorABase,
	bool obligatorio = false,
}) {
	final precio = parsearPrecioTexto(texto);
	if (precio == null) {
		return obligatorio ? 'Ingrese un precio válido' : null;
	}
	if (precio <= 0.0) {
		return 'Ingrese un precio válido';
	}
	if (!precioPresentacionEsValido(precio, costoUnitario, factorABase)) {
		return mensajePrecioMinimoPresentacionInvalido(costoUnitario, factorABase);
	}
	return null;
}

/// Texto de ayuda con el precio minimo permitido.
String? ayudaPrecioMinimoUnitario(double costoUnitario) {
	if (costoUnitario <= 0.0) {
		return null;
	}
	return 'Mínimo permitido: ${formatearMoneda(calcularPrecioMinimoVenta(costoUnitario))}';
}

/// Texto de ayuda con el precio minimo de una presentacion.
String? ayudaPrecioMinimoPresentacion(double costoUnitario, double factorABase) {
	if (costoUnitario <= 0.0 || factorABase <= 0.0) {
		return null;
	}
	return 'Mínimo permitido: ${formatearMoneda(calcularPrecioMinimoPresentacion(costoUnitario, factorABase))}';
}

/// Etiqueta legible del modo de calculo de utilidad.
String etiquetaModoCalculoUtilidad(ModoCalculoUtilidad modo) {
	switch (modo) {
		case ModoCalculoUtilidad.sobreCosto:
			return 'Utilidad sobre costo';
		case ModoCalculoUtilidad.sobrePrecioVenta:
			return 'Margen sobre venta';
	}
}

/// Calcula precio de venta segun costo, modo y porcentaje de utilidad.
double calcularPrecioVentaDesdeUtilidad({
	required double costoUnitario,
	required double porcentajeUtilidad,
	ModoCalculoUtilidad modo = ModoCalculoUtilidad.sobreCosto,
}) {
	if (costoUnitario <= 0.0) {
		return 0.01;
	}
	if (porcentajeUtilidad < 0.0) {
		return calcularPrecioMinimoVenta(costoUnitario);
	}
	switch (modo) {
		case ModoCalculoUtilidad.sobreCosto:
			return redondearMonto(costoUnitario * (1.0 + porcentajeUtilidad / 100.0));
		case ModoCalculoUtilidad.sobrePrecioVenta:
			if (porcentajeUtilidad >= 100.0) {
				throw ArgumentError('El margen sobre venta debe ser menor a 100%');
			}
			return redondearMonto(costoUnitario / (1.0 - porcentajeUtilidad / 100.0));
	}
}

/// Porcentaje de utilidad implicito entre costo y precio de venta.
double calcularUtilidadPorcentaje({
	required double costoUnitario,
	required double precioVenta,
	ModoCalculoUtilidad modo = ModoCalculoUtilidad.sobreCosto,
}) {
	if (costoUnitario <= 0.0 || precioVenta <= 0.0) {
		return 0.0;
	}
	switch (modo) {
		case ModoCalculoUtilidad.sobreCosto:
			return redondearMonto(((precioVenta - costoUnitario) / costoUnitario) * 100.0);
		case ModoCalculoUtilidad.sobrePrecioVenta:
			return redondearMonto(((precioVenta - costoUnitario) / precioVenta) * 100.0);
	}
}
