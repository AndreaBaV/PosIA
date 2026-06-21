/// Etiquetas en espanol para valores mostrados en la UI.
library;

import 'package:posia_core/posia_core.dart';

/// Texto legible del metodo de pago.
String etiquetaMetodoPago(MetodoPago metodo) {
	switch (metodo) {
		case MetodoPago.efectivo:
			return 'Efectivo';
		case MetodoPago.tarjeta:
			return 'Tarjeta';
		case MetodoPago.mixto:
			return 'Mixto';
		case MetodoPago.credito:
			return 'Crédito';
		case MetodoPago.transferencia:
			return 'Transferencia';
	}
}

/// Texto legible del estado de una venta.
String etiquetaEstadoVenta(EstadoVenta estado) {
	switch (estado) {
		case EstadoVenta.completada:
			return 'Completada';
		case EstadoVenta.cancelada:
			return 'Cancelada';
		case EstadoVenta.devuelta:
			return 'Devuelta';
	}
}

/// Texto legible del estado de un traspaso.
String etiquetaEstadoTraspaso(EstadoTraspaso estado) {
	switch (estado) {
		case EstadoTraspaso.solicitado:
			return 'Solicitado';
		case EstadoTraspaso.enTransito:
			return 'En tránsito';
		case EstadoTraspaso.completado:
			return 'Completado';
		case EstadoTraspaso.cancelado:
			return 'Cancelado';
	}
}

/// Texto legible del tipo de movimiento de inventario.
String etiquetaTipoMovimiento(TipoMovimientoInventario tipo) {
	switch (tipo) {
		case TipoMovimientoInventario.entrada:
			return 'Entrada';
		case TipoMovimientoInventario.salida:
			return 'Salida';
		case TipoMovimientoInventario.ajuste:
			return 'Ajuste';
		case TipoMovimientoInventario.traspasoSalida:
			return 'Traspaso (salida)';
		case TipoMovimientoInventario.traspasoEntrada:
			return 'Traspaso (entrada)';
		case TipoMovimientoInventario.reversionVenta:
			return 'Reversión de venta';
	}
}
