/// Generador de texto plano para ticket de venta.
library;

import '../models/linea_venta.dart';
import '../models/turno_caja.dart';
import '../models/traspaso.dart';
import '../models/venta.dart';
import 'cliente_credito_util.dart';
import 'moneda_util.dart';

String _etiquetaMetodoPago(Venta venta) {
  switch (venta.metodoPago.name) {
    case 'mixto':
      final partes = <String>[
        'E:${formatearMoneda(venta.montoEfectivo ?? 0)}',
        'T:${formatearMoneda(venta.montoTarjeta ?? 0)}',
      ];
      if ((venta.montoTransferencia ?? 0) > 0) {
        partes.add('Tr:${formatearMoneda(venta.montoTransferencia!)}');
      }
      return 'Mixto (${partes.join(' ')})';
    case 'transferencia':
      return 'Transferencia';
    case 'credito':
      return 'Crédito / Fiado';
    default:
      return venta.metodoPago.name;
  }
}

String _formatearFechaHora(DateTime fechaUtc) {
  final local = fechaUtc.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} $hora:$minuto';
}

void _escribirSiNoVacio(StringBuffer buffer, String etiqueta, String? valor) {
  if (valor != null && valor.trim().isNotEmpty) {
    buffer.writeln('$etiqueta: $valor');
  }
}

/// Formatea venta como ticket legible de 40 columnas.
String generarTextoTicket({
  required Venta venta,
  required String nombreTienda,
  double? montoRecibido,
  String? direccionTienda,
  String? etiquetaCaja,
  String? nombreVendedor,
  String? codigoVendedor,
  String? nombreCliente,
  String? telefonoCliente,
  String? rfcCliente,
  String? direccionCliente,
}) {
  final buffer = StringBuffer()
    ..writeln('========== POSIA ==========')
    ..writeln(nombreTienda);
  if (direccionTienda != null && direccionTienda.trim().isNotEmpty) {
    buffer.writeln(direccionTienda.trim());
  }
  buffer.writeln('----------------------------');
  _escribirSiNoVacio(buffer, 'Tienda', nombreTienda);
  _escribirSiNoVacio(buffer, 'Caja', etiquetaCaja);
  if (nombreVendedor != null && nombreVendedor.trim().isNotEmpty) {
    final vendedor = codigoVendedor != null && codigoVendedor.trim().isNotEmpty
        ? '${nombreVendedor.trim()} (${codigoVendedor.trim()})'
        : nombreVendedor.trim();
    buffer.writeln('Vendedor: $vendedor');
  }
  if (nombreCliente != null && nombreCliente.trim().isNotEmpty) {
    buffer.writeln('Cliente: ${nombreCliente.trim()}');
    _escribirSiNoVacio(buffer, 'Tel', telefonoCliente);
    _escribirSiNoVacio(buffer, 'Dir', direccionCliente);
    _escribirSiNoVacio(buffer, 'RFC', rfcCliente);
  } else {
    buffer.writeln('Cliente: Publico en general');
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('Ticket: ${venta.id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha: ${_formatearFechaHora(venta.creadaEn)}');
  if (venta.turnoCajaId != null) {
    buffer.writeln(
      'Turno: ${venta.turnoCajaId!.substring(0, 8).toUpperCase()}',
    );
  }
  buffer.writeln('----------------------------');
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
    buffer.writeln(
      'Descuento ticket: -${formatearMoneda(venta.descuentoTicket)}',
    );
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
  if (venta.metodoPago.name == 'credito' &&
      venta.creditoDias != null &&
      venta.creditoVenceEn != null &&
      nombreCliente != null &&
      nombreCliente.trim().isNotEmpty) {
    buffer
      ..writeln('----------------------------')
      ..writeln('*** VENTA A CRÉDITO ***')
      ..writeln(
        generarLeyendaCompromisoCredito(
          total: venta.total,
          diasCredito: venta.creditoDias!,
          fechaVencimiento: venta.creditoVenceEn!.toLocal(),
          nombreCliente: nombreCliente.trim(),
        ),
      )
      ..writeln('Plazo: ${venta.creditoDias} día(s)')
      ..writeln(
        'Pagar a más tardar: ${formatearFechaCredito(venta.creditoVenceEn!.toLocal())}',
      )
      ..writeln('Saldo pendiente: ${formatearMoneda(venta.total)}')
      ..writeln('----------------------------')
      ..writeln('FIRMA DEL CLIENTE')
      ..writeln('Acepto el adeudo y el plazo indicado.')
      ..writeln('')
      ..writeln('Nombre: ${nombreCliente.trim()}')
      ..writeln('Firma:')
      ..writeln('')
      ..writeln('______________________________')
      ..writeln('Fecha: ________________________');
  }
  buffer
    ..writeln('============================')
    ..writeln('Gracias por su compra');
  return buffer.toString();
}

/// Genera pagare de credito a una sola exhibicion (copia admin o cliente).
String generarTextoPagareCredito({
  required Venta venta,
  required String nombreTienda,
  required String nombreCliente,
  required String telefonoCliente,
  required String direccionCliente,
  required String etiquetaCopia,
  String? direccionTienda,
  String? rfcCliente,
}) {
  final buffer = StringBuffer()
    ..writeln('====== PAGARE POSIA ======')
    ..writeln(etiquetaCopia.toUpperCase())
    ..writeln(nombreTienda);
  if (direccionTienda != null && direccionTienda.trim().isNotEmpty) {
    buffer.writeln(direccionTienda.trim());
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('Folio: ${venta.id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha: ${_formatearFechaHora(venta.creadaEn)}')
    ..writeln('----------------------------')
    ..writeln('DEUDOR')
    ..writeln('Nombre: $nombreCliente')
    ..writeln('Teléfono: $telefonoCliente')
    ..writeln('Dirección: $direccionCliente');
  if (rfcCliente != null && rfcCliente.trim().isNotEmpty) {
    buffer.writeln('RFC: $rfcCliente');
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('DETALLE DE COMPRA');
  for (final linea in venta.lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  ${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}'
      ' = ${formatearMoneda(linea.calcularSubtotal())}',
    );
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('MONTO ADEUDADO: ${formatearMoneda(venta.total)}')
    ..writeln('PAGO EN UNA SOLA EXHIBICIÓN');
  if (venta.creditoDias != null && venta.creditoVenceEn != null) {
    buffer.writeln(
      generarLeyendaCompromisoCredito(
        total: venta.total,
        diasCredito: venta.creditoDias!,
        fechaVencimiento: venta.creditoVenceEn!.toLocal(),
        nombreCliente: nombreCliente,
      ),
    );
    buffer.writeln('Vence: ${formatearFechaCredito(venta.creditoVenceEn!.toLocal())}');
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('El deudor se obliga a pagar el monto')
    ..writeln('indicado en la fecha de vencimiento.')
    ..writeln('----------------------------')
    ..writeln('FIRMA DEL DEUDOR')
    ..writeln('')
    ..writeln('Nombre: $nombreCliente')
    ..writeln('Firma:')
    ..writeln('')
    ..writeln('______________________________')
    ..writeln('Fecha: ________________________')
    ..writeln('==============================');
  return buffer.toString();
}

/// Ticket de cotizacion sin validez fiscal.
String generarTextoCotizacion({
  required String id,
  required String nombreTienda,
  required List<LineaVenta> lineas,
  required double total,
  required DateTime creadaEn,
  String? nombreCliente,
  String? notas,
  String? direccionTienda,
  int vigenciaDias = 7,
}) {
  final buffer = StringBuffer()
    ..writeln('====== COTIZACION ======')
    ..writeln(nombreTienda);
  if (direccionTienda != null && direccionTienda.trim().isNotEmpty) {
    buffer.writeln(direccionTienda.trim());
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('Folio: ${id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha: ${_formatearFechaHora(creadaEn)}')
    ..writeln('Vigencia: $vigenciaDias dias');
  if (nombreCliente != null && nombreCliente.trim().isNotEmpty) {
    buffer.writeln('Cliente: ${nombreCliente.trim()}');
  }
  buffer.writeln('----------------------------');
  for (final linea in lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  ${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}'
      ' = ${formatearMoneda(linea.calcularSubtotal())}',
    );
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('TOTAL: ${formatearMoneda(total)}')
    ..writeln('Documento informativo, no es comprobante fiscal.')
    ..writeln('Precios sujetos a cambio sin previo aviso.');
  if (notas != null && notas.trim().isNotEmpty) {
    buffer.writeln('Notas: ${notas.trim()}');
  }
  buffer.writeln('==============================');
  return buffer.toString();
}

/// Comprobante de liquidacion de credito al recibir el pago.
String generarTextoLiquidacionCredito({
  required Venta venta,
  required String nombreTienda,
  required String nombreCliente,
  String? direccionTienda,
  String? telefonoCliente,
}) {
  final buffer = StringBuffer()
    ..writeln('=== LIQUIDACIÓN DE CRÉDITO ===')
    ..writeln(nombreTienda);
  if (direccionTienda != null && direccionTienda.trim().isNotEmpty) {
    buffer.writeln(direccionTienda.trim());
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('Folio venta: ${venta.id.substring(0, 8).toUpperCase()}')
    ..writeln('Cliente: $nombreCliente');
  if (telefonoCliente != null && telefonoCliente.trim().isNotEmpty) {
    buffer.writeln('Teléfono: $telefonoCliente');
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('MONTO LIQUIDADO: ${formatearMoneda(venta.total)}')
    ..writeln('PAGO EN UNA SOLA EXHIBICIÓN')
    ..writeln('Estado: CRÉDITO LIQUIDADO')
    ..writeln(
      'Fecha liquidación: ${_formatearFechaHora(venta.creditoLiquidadoEn ?? DateTime.now().toUtc())}',
    )
    ..writeln('----------------------------')
    ..writeln('Gracias por su pago')
    ..writeln('==============================');
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
    ..writeln(
      'Ventas transferencia: ${formatearMoneda(turno.totalTransferencia)}',
    )
    ..writeln('Total ventas: ${formatearMoneda(turno.totalVentas)}')
    ..writeln('Tickets: ${turno.cantidadVentas}')
    ..writeln('------------------------------')
    ..writeln(
      'Efectivo esperado: ${formatearMoneda(turno.calcularEfectivoEsperado())}',
    )
    ..writeln('==============================');
  return buffer.toString();
}

String _formatearCantidadTraspaso(double cantidad) {
  if (cantidad == cantidad.roundToDouble()) {
    return cantidad.toStringAsFixed(0);
  }
  return cantidad.toStringAsFixed(2);
}

/// Ticket resumido de productos enviados en traspaso.
String generarTextoTicketTraspaso({
  required Traspaso traspaso,
  required String nombreTiendaOrigen,
  required String nombreTiendaDestino,
  String? nombreOperador,
}) {
  final buffer = StringBuffer()
    ..writeln('====== TRASPASO POSIA ======')
    ..writeln('Folio: ${traspaso.id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha: ${_formatearFechaHora(traspaso.solicitadoEn)}')
    ..writeln('Origen: $nombreTiendaOrigen')
    ..writeln('Destino: $nombreTiendaDestino')
    ..writeln('----------------------------')
    ..writeln('PRODUCTOS (${traspaso.lineas.length})')
    ..writeln('----------------------------');
  var totalUnidades = 0.0;
  for (final linea in traspaso.lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  Cant: ${_formatearCantidadTraspaso(linea.cantidadSolicitada)} u.',
    );
    totalUnidades = totalUnidades + linea.cantidadSolicitada;
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('Total unidades: ${_formatearCantidadTraspaso(totalUnidades)}');
  if (traspaso.notas.trim().isNotEmpty) {
    buffer.writeln('Notas: ${traspaso.notas.trim()}');
  }
  if (nombreOperador != null && nombreOperador.trim().isNotEmpty) {
    buffer.writeln('Operador: ${nombreOperador.trim()}');
  }
  buffer
    ..writeln('============================')
    ..writeln('Documento de control interno');
  return buffer.toString();
}

/// Comprobante formal con seccion recibido y firmas.
String generarTextoComprobanteTraspaso({
  required Traspaso traspaso,
  required String nombreTiendaOrigen,
  required String nombreTiendaDestino,
  String? nombreOperadorEnvio,
}) {
  final buffer = StringBuffer()
    ..writeln('==== COMPROBANTE TRASPASO ====')
    ..writeln('Folio: ${traspaso.id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha envio: ${_formatearFechaHora(traspaso.solicitadoEn)}')
    ..writeln('Origen: $nombreTiendaOrigen')
    ..writeln('Destino: $nombreTiendaDestino')
    ..writeln('------------------------------')
    ..writeln('PRODUCTOS ENVIADOS')
    ..writeln('------------------------------');
  for (final linea in traspaso.lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  Enviado: ${_formatearCantidadTraspaso(linea.cantidadSolicitada)} u.',
    );
  }
  buffer
    ..writeln('------------------------------')
    ..writeln('PRODUCTOS RECIBIDOS')
    ..writeln('(confirmar al recibir)')
    ..writeln('------------------------------');
  for (final linea in traspaso.lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  Env: ${_formatearCantidadTraspaso(linea.cantidadSolicitada)}'
      '  Rec: ________',
    );
  }
  if (traspaso.notas.trim().isNotEmpty) {
    buffer
      ..writeln('------------------------------')
      ..writeln('Notas: ${traspaso.notas.trim()}');
  }
  buffer
    ..writeln('------------------------------')
    ..writeln('ENVIA:')
    ..writeln(
      'Nombre: ${nombreOperadorEnvio?.trim().isNotEmpty == true ? nombreOperadorEnvio!.trim() : '________________________'}',
    )
    ..writeln('Firma:')
    ..writeln('')
    ..writeln('______________________________')
    ..writeln('------------------------------')
    ..writeln('RECIBE:')
    ..writeln('Nombre: ________________________')
    ..writeln('Firma:')
    ..writeln('')
    ..writeln('______________________________')
    ..writeln('Fecha recepción: _______________')
    ..writeln('==============================');
  return buffer.toString();
}
