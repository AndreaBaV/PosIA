/// Generador de texto plano para ticket de venta.
library;

import '../constants/posia_constants.dart';
import '../enums/estado_pedido.dart';
import '../enums/metodo_pago.dart';
import '../models/compra.dart';
import '../models/linea_venta.dart';
import '../models/pedido.dart';
import '../models/turno_caja.dart';
import '../models/traspaso.dart';
import '../models/venta.dart';
import 'cliente_credito_util.dart';
import 'formateador_ticket_digital.dart';
import 'moneda_util.dart';

String _formatearFechaHora(DateTime fechaUtc) {
  final local = fechaUtc.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} $hora:$minuto';
}

void _escribirEncabezadoMarca(
  StringBuffer buffer, {
  required bool conLogoImpreso,
  String? tituloDocumento,
}) {
  if (tituloDocumento != null) {
    buffer.writeln(tituloDocumento);
  } else if (!conLogoImpreso) {
    buffer.writeln('====== ${NOMBRE_COMERCIAL_APP.toUpperCase()} ======');
  }
}

/// Formatea venta como ticket legible de 40 columnas.
String generarTextoTicket({
  required Venta venta,
  required String nombreTienda,
  double? montoRecibido,
  String? direccionTienda,
  String? nombreVendedor,
  String? codigoVendedor,
  String? nombreCliente,
  String? telefonoCliente,
  String? rfcCliente,
  String? direccionCliente,
  bool conLogoImpreso = false,
}) {
  final digital = construirTicketDigitalVenta(
    venta: venta,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    nombreVendedor: nombreVendedor,
    codigoVendedor: codigoVendedor,
    nombreCliente: nombreCliente,
    telefonoCliente: telefonoCliente,
    rfcCliente: rfcCliente,
    direccionCliente: direccionCliente,
    montoRecibido: montoRecibido,
  );
  final buffer = StringBuffer();
  if (!conLogoImpreso) {
    buffer.writeln('====== ${NOMBRE_COMERCIAL_APP.toUpperCase()} ======');
  }
  buffer.write(formatearTicketDigitalImpresion(digital));
  if (venta.metodoPago.name == 'credito' &&
      venta.creditoDias != null &&
      venta.creditoVenceEn != null &&
      nombreCliente != null &&
      nombreCliente.trim().isNotEmpty) {
    buffer
      ..writeln('----------------------------')
      ..writeln('*** VENTA A CREDITO ***')
      ..writeln(
        generarLeyendaCompromisoCredito(
          total: venta.total,
          diasCredito: venta.creditoDias!,
          fechaVencimiento: venta.creditoVenceEn!.toLocal(),
          nombreCliente: nombreCliente.trim(),
        ),
      )
      ..writeln('Plazo: ${venta.creditoDias} dia(s)')
      ..writeln(
        'Pagar a mas tardar: ${formatearFechaCredito(venta.creditoVenceEn!.toLocal())}',
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
  bool conLogoImpreso = false,
}) {
  final digital = construirTicketDigitalPagare(
    venta: venta,
    nombreTienda: nombreTienda,
    nombreCliente: nombreCliente,
    telefonoCliente: telefonoCliente,
    direccionCliente: direccionCliente,
    etiquetaCopia: etiquetaCopia,
    direccionTienda: direccionTienda,
    rfcCliente: rfcCliente,
  );
  final buffer = StringBuffer();
  if (!conLogoImpreso) {
    buffer.writeln(
      '====== PAGARE ${NOMBRE_COMERCIAL_APP.toUpperCase()} ======',
    );
  } else {
    buffer.writeln('PAGARE');
  }
  buffer.write(formatearTicketDigitalImpresion(digital));
  buffer
    ..writeln('----------------------------')
    ..writeln('FIRMA DEL DEUDOR')
    ..writeln('')
    ..writeln('Nombre: $nombreCliente')
    ..writeln('Firma:')
    ..writeln('')
    ..writeln('______________________________')
    ..writeln('Fecha: ________________________');
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
  bool conLogoImpreso = false,
}) {
  final digital = construirTicketDigitalCotizacion(
    id: id,
    nombreTienda: nombreTienda,
    lineas: lineas,
    total: total,
    creadaEn: creadaEn,
    nombreCliente: nombreCliente,
    notas: notas,
    direccionTienda: direccionTienda,
    vigenciaDias: vigenciaDias,
  );
  final buffer = StringBuffer();
  if (!conLogoImpreso) {
    buffer.writeln('====== COTIZACION ======');
  }
  buffer.write(formatearTicketDigitalImpresion(digital));
  return buffer.toString();
}

/// Comprobante de liquidacion de credito al recibir el pago.
String generarTextoLiquidacionCredito({
  required Venta venta,
  required String nombreTienda,
  required String nombreCliente,
  String? direccionTienda,
  String? telefonoCliente,
  bool conLogoImpreso = false,
}) {
  final digital = construirTicketDigitalLiquidacionCredito(
    venta: venta,
    nombreTienda: nombreTienda,
    nombreCliente: nombreCliente,
    direccionTienda: direccionTienda,
    telefonoCliente: telefonoCliente,
  );
  final buffer = StringBuffer();
  if (!conLogoImpreso) {
    buffer.writeln('=== LIQUIDACION DE CREDITO ===');
  }
  buffer.write(formatearTicketDigitalImpresion(digital));
  return buffer.toString();
}

/// Formatea corte de caja como ticket de texto.
String generarTextoCorteCaja({
  required TurnoCaja turno,
  required String nombreTienda,
  bool conLogoImpreso = false,
}) {
  final buffer = StringBuffer();
  _escribirEncabezadoMarca(
    buffer,
    conLogoImpreso: conLogoImpreso,
    tituloDocumento: '======== CORTE DE CAJA ========',
  );
  buffer
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
  bool conLogoImpreso = false,
}) {
  final buffer = StringBuffer();
  _escribirEncabezadoMarca(
    buffer,
    conLogoImpreso: conLogoImpreso,
    tituloDocumento: conLogoImpreso
        ? 'TRASPASO'
        : '====== TRASPASO ${NOMBRE_COMERCIAL_APP.toUpperCase()} ======',
  );
  buffer
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

String _etiquetaMetodoPagoPedido(MetodoPago metodo) {
  return switch (metodo) {
    MetodoPago.efectivo => 'Efectivo',
    MetodoPago.tarjeta => 'Tarjeta',
    MetodoPago.mixto => 'Mixto',
    MetodoPago.credito => 'Crédito / Fiado',
    MetodoPago.transferencia => 'Transferencia',
  };
}

String _etiquetaEstadoPedido(EstadoPedido estado) {
  return switch (estado) {
    EstadoPedido.recibido => 'Recibido',
    EstadoPedido.asignado => 'Asignado',
    EstadoPedido.entregado => 'Entregado',
    EstadoPedido.cancelado => 'Cancelado',
  };
}

String _formatearCantidadDocumento(double cantidad) {
  if (cantidad == cantidad.roundToDouble()) {
    return cantidad.toStringAsFixed(0);
  }
  return cantidad.toStringAsFixed(2);
}

/// Ticket de compra a proveedor.
String generarTextoCompra({
  required Compra compra,
  required String nombreProveedor,
  String? nombreTienda,
  bool conLogoImpreso = false,
}) {
  final buffer = StringBuffer();
  _escribirEncabezadoMarca(
    buffer,
    conLogoImpreso: conLogoImpreso,
    tituloDocumento: '====== COMPRA / ENTRADA ======',
  );
  if (nombreTienda != null && nombreTienda.trim().isNotEmpty) {
    buffer.writeln(nombreTienda.trim());
  }
  buffer
    ..writeln('Proveedor: $nombreProveedor')
    ..writeln('----------------------------')
    ..writeln('Folio: ${compra.id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha compra: ${_formatearFechaHora(compra.fechaCompra)}')
    ..writeln('Registrado: ${_formatearFechaHora(compra.creadaEn)}')
    ..writeln('----------------------------');
  for (final linea in compra.lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  ${_formatearCantidadDocumento(linea.cantidad)} x '
      '${formatearMoneda(linea.costoUnitario)}'
      ' = ${formatearMoneda(linea.subtotal)}',
    );
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('TOTAL: ${formatearMoneda(compra.total)}');
  if (compra.notas.trim().isNotEmpty) {
    buffer.writeln('Notas: ${compra.notas.trim()}');
  }
  buffer
    ..writeln('Documento de control interno')
    ..writeln('==============================');
  return buffer.toString();
}

/// Resumen de pedido para entrega.
String generarTextoPedido({
  required Pedido pedido,
  String? nombreTienda,
  bool conLogoImpreso = false,
}) {
  final buffer = StringBuffer();
  _escribirEncabezadoMarca(
    buffer,
    conLogoImpreso: conLogoImpreso,
    tituloDocumento: '========== PEDIDO ==========',
  );
  if (nombreTienda != null && nombreTienda.trim().isNotEmpty) {
    buffer.writeln(nombreTienda.trim());
  }
  buffer
    ..writeln('Folio: ${pedido.id.substring(0, 8).toUpperCase()}')
    ..writeln('Fecha: ${_formatearFechaHora(pedido.creadoEn)}')
    ..writeln('Estado: ${_etiquetaEstadoPedido(pedido.estado)}')
    ..writeln('----------------------------')
    ..writeln('ENTREGA')
    ..writeln('Nombre: ${pedido.nombreEntrega}')
    ..writeln('Teléfono: ${pedido.telefonoEntrega}')
    ..writeln('Dirección: ${pedido.direccionEntrega}')
    ..writeln('----------------------------')
    ..writeln('Pago: ${_etiquetaMetodoPagoPedido(pedido.metodoPago)}');
  if (pedido.esCredito) {
    buffer.writeln(
      'Crédito: ${pedido.creditoDias ?? '?'} días'
      '${pedido.creditoVenceEn != null ? ' · vence ${_formatearFechaHora(pedido.creditoVenceEn!)}' : ''}',
    );
  }
  if (pedido.asignadoAUsuarioNombre != null &&
      pedido.asignadoAUsuarioNombre!.trim().isNotEmpty) {
    buffer.writeln('Asignado a: ${pedido.asignadoAUsuarioNombre!.trim()}');
  }
  buffer.writeln('----------------------------');
  for (final linea in pedido.lineas) {
    buffer.writeln(linea.nombreProducto);
    buffer.writeln(
      '  ${_formatearCantidadDocumento(linea.cantidad)} x '
      '${formatearMoneda(linea.precioUnitario)}'
      ' = ${formatearMoneda(linea.subtotal)}',
    );
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('TOTAL: ${formatearMoneda(pedido.total)}');
  if (pedido.notas.trim().isNotEmpty) {
    buffer.writeln('Notas: ${pedido.notas.trim()}');
  }
  buffer.writeln('==============================');
  return buffer.toString();
}
