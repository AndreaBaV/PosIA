/// Calculo de descuentos manuales en caja respetando precio minimo.
library;

import 'package:posia_core/posia_core.dart';

/// Precio minimo por unidad de venta (pieza, kg o empaque).
double calcularPrecioMinimoUnitarioLinea(LineaCarrito linea) {
	final costo = linea.producto.costoUnitario;
	if (linea.factorABase > 1.0) {
		return calcularPrecioMinimoPresentacion(costo, linea.factorABase);
	}
	return calcularPrecioMinimoVenta(costo);
}

/// Total minimo permitido de una linea (costo + utilidad minima).
double calcularTotalMinimoLinea(LineaCarrito linea) {
	final minimoUnitario = calcularPrecioMinimoUnitarioLinea(linea);
	return redondearMonto(linea.cantidad * minimoUnitario);
}

/// Subtotal bruto de una linea sin descuentos.
double calcularSubtotalBrutoLinea(LineaCarrito linea) {
	return redondearMonto(linea.cantidad * linea.precioUnitario);
}

/// Descuento maximo en pesos aplicable a una linea.
double calcularDescuentoMaximoLinea(LineaCarrito linea) {
	final bruto = calcularSubtotalBrutoLinea(linea);
	final minimo = calcularTotalMinimoLinea(linea);
	final maximo = bruto - minimo;
	return redondearMonto(maximo < 0.0 ? 0.0 : maximo);
}

/// Convierte porcentaje a monto de descuento sobre el bruto de la linea.
double calcularDescuentoLineaDesdePorcentaje(
	LineaCarrito linea,
	double porcentaje,
) {
	if (porcentaje <= 0.0) {
		return 0.0;
	}
	final bruto = calcularSubtotalBrutoLinea(linea);
	return redondearMonto(bruto * (porcentaje / 100.0));
}

/// Total minimo del carrito (suma de minimos por linea).
double calcularTotalMinimoCarrito(Iterable<LineaCarrito> lineas) {
	var total = 0.0;
	for (final linea in lineas) {
		total = total + calcularTotalMinimoLinea(linea);
	}
	return redondearMonto(total);
}

/// Subtotal con descuentos de linea, sin descuento de ticket.
double calcularSubtotalConDescuentosLinea(Iterable<LineaCarrito> lineas) {
	var total = 0.0;
	for (final linea in lineas) {
		total = total + redondearMonto(linea.calcularSubtotal());
	}
	return redondearMonto(total);
}

/// Descuento maximo adicional a nivel ticket.
double calcularDescuentoMaximoTicket(Iterable<LineaCarrito> lineas) {
	final subtotal = calcularSubtotalConDescuentosLinea(lineas);
	final minimo = calcularTotalMinimoCarrito(lineas);
	final maximo = subtotal - minimo;
	return redondearMonto(maximo < 0.0 ? 0.0 : maximo);
}

/// Convierte porcentaje a monto de descuento sobre el subtotal actual.
double calcularDescuentoTicketDesdePorcentaje(
	Iterable<LineaCarrito> lineas,
	double porcentaje,
) {
	if (porcentaje <= 0.0) {
		return 0.0;
	}
	final base = calcularSubtotalConDescuentosLinea(lineas);
	return redondearMonto(base * (porcentaje / 100.0));
}

/// Valida descuento de linea; retorna mensaje de error o null si es valido.
String? errorDescuentoLinea(LineaCarrito linea, double descuento) {
	if (descuento < 0.0) {
		return 'El descuento no puede ser negativo';
	}
	if (descuento == 0.0) {
		return null;
	}
	final descuentoRedondeado = redondearMonto(descuento);
	final maximo = calcularDescuentoMaximoLinea(linea);
	if (descuentoRedondeado > maximo) {
		final minimoUnitario = calcularPrecioMinimoUnitarioLinea(linea);
		if (maximo <= 0.0) {
			return 'No se puede descontar: el precio ya está en el mínimo '
				'(${formatearMoneda(minimoUnitario)})';
		}
		return 'El descuento no puede dejar el precio menor a '
			'${formatearMoneda(minimoUnitario)} por unidad '
			'(máximo ${formatearMoneda(maximo)})';
	}
	return null;
}

/// Valida descuento global de ticket; retorna mensaje de error o null.
String? errorDescuentoTicket(
	Iterable<LineaCarrito> lineas,
	double descuento,
) {
	if (descuento < 0.0) {
		return 'El descuento no puede ser negativo';
	}
	if (descuento == 0.0) {
		return null;
	}
	final descuentoRedondeado = redondearMonto(descuento);
	final maximo = calcularDescuentoMaximoTicket(lineas);
	if (descuentoRedondeado > maximo) {
		if (maximo <= 0.0) {
			return 'No se puede descontar más: el total ya está en el mínimo permitido';
		}
		return 'El descuento de ticket no puede superar ${formatearMoneda(maximo)}';
	}
	return null;
}
