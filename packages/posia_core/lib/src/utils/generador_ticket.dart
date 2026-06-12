/// Generador de texto plano para ticket de venta.
library;

import '../models/turno_caja.dart';
import '../models/venta.dart';
import 'moneda_util.dart';

/// Formatea venta como ticket legible de 40 columnas.
String generarTextoTicket({
	required Venta venta,
	required String nombreTienda,
}) {
	final buffer = StringBuffer()
		..writeln('========== POSIA ==========')
		..writeln(nombreTienda)
		..writeln('Venta: ${venta.id.substring(0, 8)}')
		..writeln('Fecha: ${venta.creadaEn.toLocal()}')
		..writeln('----------------------------');
	for (final linea in venta.lineas) {
		buffer.writeln(linea.nombreProducto);
		buffer.writeln(
			'  ${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}'
			' = ${formatearMoneda(linea.calcularSubtotal())}',
		);
	}
	buffer
		..writeln('----------------------------')
		..writeln('TOTAL: ${formatearMoneda(venta.total)}')
		..writeln('Pago: ${venta.metodoPago.name}')
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
		..writeln('Total ventas: ${formatearMoneda(turno.totalVentas)}')
		..writeln('Tickets: ${turno.cantidadVentas}')
		..writeln('------------------------------')
		..writeln('Efectivo esperado: ${formatearMoneda(turno.calcularEfectivoEsperado())}')
		..writeln('==============================');
	return buffer.toString();
}
