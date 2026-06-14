/// Generador de texto plano para ticket de venta.
library;

import '../models/turno_caja.dart';
import '../models/venta.dart';
import 'moneda_util.dart';

String _etiquetaMetodoPago(Venta venta) {
	switch (venta.metodoPago.name) {
		case 'mixto':
			return 'Mixto (E:${formatearMoneda(venta.montoEfectivo ?? 0)} '
				'T:${formatearMoneda(venta.montoTarjeta ?? 0)})';
		case 'transferencia':
			return 'Transferencia';
		case 'credito':
			return 'Credito / Fiado';
		default:
			return venta.metodoPago.name;
	}
}

/// Formatea venta como ticket legible de 40 columnas.
String generarTextoTicket({
	required Venta venta,
	required String nombreTienda,
	double? montoRecibido,
}) {
	final buffer = StringBuffer()
		..writeln('========== POSIA ==========')
		..writeln(nombreTienda)
		..writeln('Venta: ${venta.id.substring(0, 8)}')
		..writeln('Fecha: ${venta.creadaEn.toLocal()}')
		..writeln('----------------------------');
	for (final linea in venta.lineas) {
		buffer.writeln(linea.nombreProducto);
		var detalle =
			'  ${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}'
			' = ${formatearMoneda(linea.calcularSubtotal())}';
		if (linea.descuentoLinea > 0.0) {
			detalle = '$detalle (desc ${formatearMoneda(linea.descuentoLinea)})';
		}
		buffer.writeln(detalle);
	}
	buffer.writeln('----------------------------');
	if (venta.descuentoTicket > 0.0) {
		buffer.writeln('Descuento ticket: -${formatearMoneda(venta.descuentoTicket)}');
	}
	buffer
		..writeln('TOTAL: ${formatearMoneda(venta.total)}')
		..writeln('Pago: ${_etiquetaMetodoPago(venta)}');
	if (montoRecibido != null && venta.metodoPago.name == 'efectivo') {
		final cambio = montoRecibido - venta.total;
		if (cambio >= 0.0) {
			buffer
				..writeln('Recibido: ${formatearMoneda(montoRecibido)}')
				..writeln('Cambio: ${formatearMoneda(cambio)}');
		}
	}
	buffer
		..writeln('============================')
		..writeln('Gracias por su compra');
	return buffer.toString();
}

/// Formatea corte de caja como ticket de texto.
String generarTextoCorteCaja({
	required TurnoCaja turno,
	required String nombreTienda,
}) {
	final buffer = StringBuffer()
		..writeln('======== CORTE DE CAJA ========')
		..writeln(nombreTienda)
		..writeln('Turno: ${turno.id.substring(0, 8)}')
		..writeln('Apertura: ${turno.abiertoEn.toLocal()}')
		..writeln('Cierre: ${turno.cerradoEn?.toLocal() ?? '-'}')
		..writeln('------------------------------')
		..writeln('Fondo inicial: ${formatearMoneda(turno.fondoInicial)}')
		..writeln('Ventas efectivo: ${formatearMoneda(turno.totalEfectivo)}')
		..writeln('Ventas tarjeta: ${formatearMoneda(turno.totalTarjeta)}')
		..writeln('Ventas transferencia: ${formatearMoneda(turno.totalTransferencia)}')
		..writeln('Total ventas: ${formatearMoneda(turno.totalVentas)}')
		..writeln('Tickets: ${turno.cantidadVentas}')
		..writeln('------------------------------')
		..writeln('Efectivo esperado: ${formatearMoneda(turno.calcularEfectivoEsperado())}')
		..writeln('==============================');
	return buffer.toString();
}
