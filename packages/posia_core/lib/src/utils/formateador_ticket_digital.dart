/// Construccion y formateo de tickets digitales para PDF, PNG e impresion.
library;

import '../constants/posia_constants.dart';
import '../enums/estado_pedido.dart';
import '../enums/metodo_pago.dart';
import '../models/compra.dart';
import '../models/cotizacion.dart';
import '../models/linea_venta.dart';
import '../models/pedido.dart';
import '../models/ticket_digital.dart';
import '../models/traspaso.dart';
import '../models/turno_caja.dart';
import '../models/venta.dart';
import 'cliente_credito_util.dart';
import 'moneda_util.dart';

String _etiquetaMetodoPago(Venta venta) {
  return switch (venta.metodoPago) {
    MetodoPago.efectivo => 'Efectivo',
    MetodoPago.tarjeta => 'Tarjeta',
    MetodoPago.mixto => () {
      final partes = <String>[
        'Efectivo ${formatearMoneda(venta.montoEfectivo ?? 0)}',
        'Tarjeta ${formatearMoneda(venta.montoTarjeta ?? 0)}',
      ];
      if ((venta.montoTransferencia ?? 0) > 0) {
        partes.add(
          'Transferencia ${formatearMoneda(venta.montoTransferencia!)}',
        );
      }
      return 'Mixto (${partes.join(' · ')})';
    }(),
    MetodoPago.credito => 'Crédito / Fiado',
    MetodoPago.transferencia => 'Transferencia',
  };
}

/// Folio legible para el cliente (fecha corta + sufijo alfanumérico).
String formatearFolioTicket(String id, DateTime fechaUtc) {
  final local = fechaUtc.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final anio = (local.year % 100).toString().padLeft(2, '0');
  final compacto = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  final sufijo = compacto.length >= 4
      ? compacto.substring(compacto.length - 4)
      : compacto.padLeft(4, '0');
  return '$dia$mes$anio-$sufijo';
}

String _formatearFechaTicket(DateTime fechaUtc) {
  final local = fechaUtc.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} · $hora:$minuto';
}

String _formatearCantidadLinea(double cantidad) {
  if (cantidad == cantidad.roundToDouble()) {
    return cantidad.toStringAsFixed(0);
  }
  return cantidad.toStringAsFixed(2);
}

List<LineaTicketDigital> _lineasDesdeVenta(List<LineaVenta> lineas) {
  return lineas
      .map(
        (l) => LineaTicketDigital(
          descripcion: l.nombreProducto,
          cantidad: l.cantidad,
          precioUnitario: l.precioUnitario,
          subtotal: l.calcularSubtotal(),
          descuentoLinea: l.descuentoLinea,
        ),
      )
      .toList();
}

/// Arma ticket digital de una venta cerrada.
TicketDigitalContenido construirTicketDigitalVenta({
  required Venta venta,
  required String nombreTienda,
  String? direccionTienda,
  String? nombreVendedor,
  String? codigoVendedor,
  String? nombreCliente,
  String? telefonoCliente,
  String? rfcCliente,
  String? direccionCliente,
  double? montoRecibido,
}) {
  final campos = <String, String>{};

  if (nombreVendedor != null && nombreVendedor.trim().isNotEmpty) {
    campos['Atendió'] = nombreVendedor.trim();
  }
  if (telefonoCliente != null && telefonoCliente.trim().isNotEmpty) {
    campos['Teléfono'] = telefonoCliente.trim();
  }
  if (direccionCliente != null && direccionCliente.trim().isNotEmpty) {
    campos['Dirección'] = direccionCliente.trim();
  }
  if (rfcCliente != null && rfcCliente.trim().isNotEmpty) {
    campos['RFC'] = rfcCliente.trim();
  }
  campos['Pago'] = _etiquetaMetodoPago(venta);

  double? cambio;
  if (montoRecibido != null && venta.metodoPago == MetodoPago.efectivo) {
    final diff = montoRecibido - venta.total;
    if (diff >= 0) {
      cambio = diff;
    }
  }

  final notasPie = <String>['Gracias por su compra - 722 652 7751'];

  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.venta,
    folio: formatearFolioTicket(venta.id, venta.creadaEn),
    fecha: venta.creadaEn,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    nombreCliente: nombreCliente?.trim().isNotEmpty == true
        ? nombreCliente!.trim()
        : 'Publico en general',
    lineas: _lineasDesdeVenta(venta.lineas),
    total: venta.total,
    descuentoTicket: venta.descuentoTicket,
    campos: campos,
    notasPie: notasPie,
    montoRecibido: montoRecibido,
    cambio: cambio,
  );
}

/// Arma ticket digital de cotización.
TicketDigitalContenido construirTicketDigitalCotizacion({
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
  final notasPie = <String>[
    'Vigencia: $vigenciaDias día(s)',
    'Precios sujetos a cambio sin previo aviso.',
    'Documento informativo, no es comprobante fiscal.',
  ];
  if (notas != null && notas.trim().isNotEmpty) {
    notasPie.insert(0, 'Notas: ${notas.trim()}');
  }

  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.cotizacion,
    folio: formatearFolioTicket(id, creadaEn),
    fecha: creadaEn,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    nombreCliente: nombreCliente?.trim().isNotEmpty == true
        ? nombreCliente!.trim()
        : null,
    lineas: lineas
        .map(
          (l) => LineaTicketDigital(
            descripcion: l.nombreProducto,
            cantidad: l.cantidad,
            precioUnitario: l.precioUnitario,
            subtotal: l.calcularSubtotal(),
            descuentoLinea: l.descuentoLinea,
          ),
        )
        .toList(),
    total: total,
    notasPie: notasPie,
  );
}

/// Arma ticket digital desde entidad [Cotizacion].
TicketDigitalContenido construirTicketDigitalDesdeCotizacion({
  required Cotizacion cotizacion,
  required String nombreTienda,
  String? direccionTienda,
}) {
  final lineasVenta = cotizacion.lineas
      .map(
        (l) => LineaVenta(
          productoId: l.productoId,
          nombreProducto: l.nombreProducto,
          cantidad: l.cantidad,
          precioUnitario: l.precioUnitario,
          reglaPrecio: l.reglaPrecio,
        ),
      )
      .toList();
  return construirTicketDigitalCotizacion(
    id: cotizacion.id,
    nombreTienda: nombreTienda,
    lineas: lineasVenta,
    total: cotizacion.total,
    creadaEn: cotizacion.creadaEn,
    nombreCliente: cotizacion.nombreCliente,
    notas: cotizacion.notas.isEmpty ? null : cotizacion.notas,
    direccionTienda: direccionTienda,
    vigenciaDias: cotizacion.vigenciaDias,
  );
}

/// Pagaré de crédito (copia cliente o administrador).
TicketDigitalContenido construirTicketDigitalPagare({
  required Venta venta,
  required String nombreTienda,
  required String nombreCliente,
  required String telefonoCliente,
  required String direccionCliente,
  required String etiquetaCopia,
  String? direccionTienda,
  String? rfcCliente,
}) {
  final campos = <String, String>{
    'Teléfono': telefonoCliente,
    'Dirección': direccionCliente,
  };
  if (rfcCliente != null && rfcCliente.trim().isNotEmpty) {
    campos['RFC'] = rfcCliente.trim();
  }
  final notasPie = <String>[
    if (venta.creditoDias != null && venta.creditoVenceEn != null)
      generarLeyendaCompromisoCredito(
        total: venta.total,
        diasCredito: venta.creditoDias!,
        fechaVencimiento: venta.creditoVenceEn!.toLocal(),
        nombreCliente: nombreCliente,
      ),
    'Pago en una sola exhibición.',
    'El deudor se obliga a pagar en la fecha de vencimiento.',
    '',
    'FIRMA DEL DEUDOR',
    'Acepto el adeudo y el plazo indicado.',
    'Nombre: $nombreCliente',
    'Firma: ______________________________',
    'Fecha: ________________________',
    '$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}',
  ];
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.pagare,
    folio: formatearFolioTicket(venta.id, venta.creadaEn),
    fecha: venta.creadaEn,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    nombreCliente: nombreCliente,
    lineas: _lineasDesdeVenta(venta.lineas),
    total: venta.total,
    campos: campos,
    notasPie: notasPie,
    etiquetaTotal: 'ADEUDO',
    etiquetaSecundaria: etiquetaCopia,
    creditoPlazoDias: venta.creditoDias,
    creditoVenceEn: venta.creditoVenceEn,
  );
}

/// Comprobante al liquidar un crédito pendiente.
TicketDigitalContenido construirTicketDigitalLiquidacionCredito({
  required Venta venta,
  required String nombreTienda,
  required String nombreCliente,
  String? direccionTienda,
  String? telefonoCliente,
}) {
  final campos = <String, String>{
    'Estado': 'CRÉDITO LIQUIDADO',
    'Fecha de pago': _formatearFechaTicket(
      venta.creditoLiquidadoEn ?? DateTime.now().toUtc(),
    ),
  };
  if (telefonoCliente != null && telefonoCliente.trim().isNotEmpty) {
    campos['Teléfono'] = telefonoCliente.trim();
  }
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.liquidacionCredito,
    folio: formatearFolioTicket(venta.id, venta.creadaEn),
    fecha: venta.creditoLiquidadoEn ?? DateTime.now().toUtc(),
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    nombreCliente: nombreCliente,
    lineas: _lineasDesdeVenta(venta.lineas),
    total: venta.total,
    campos: campos,
    notasPie: [
      'Pago en una sola exhibición',
      'Gracias por su pago',
      '$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}',
    ],
    etiquetaTotal: 'MONTO LIQUIDADO',
  );
}

/// Resumen de corte al cerrar turno de caja.
TicketDigitalContenido construirTicketDigitalCorteCaja({
  required TurnoCaja turno,
  required String nombreTienda,
  String? direccionTienda,
}) {
  final campos = <String, String>{
    'Turno': turno.id.substring(0, 8).toUpperCase(),
    'Apertura': _formatearFechaTicket(turno.abiertoEn),
    'Cierre': turno.cerradoEn != null
        ? _formatearFechaTicket(turno.cerradoEn!)
        : '-',
    'Fondo inicial': formatearMoneda(turno.fondoInicial),
    'Ventas efectivo': formatearMoneda(turno.totalEfectivo),
    'Ventas tarjeta': formatearMoneda(turno.totalTarjeta),
    'Ventas transferencia': formatearMoneda(turno.totalTransferencia),
    'Total ventas': formatearMoneda(turno.totalVentas),
    'Tickets': '${turno.cantidadVentas}',
  };
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.corteCaja,
    folio: turno.id.substring(0, 8).toUpperCase(),
    fecha: turno.cerradoEn ?? turno.abiertoEn,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    lineas: const [],
    total: turno.calcularEfectivoEsperado(),
    campos: campos,
    notasPie: [
      'Documento de control interno',
      '$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}',
    ],
    etiquetaTotal: 'EFECTIVO ESPERADO',
  );
}

List<LineaTicketDigital> _lineasDesdeTraspaso(List<LineaTraspaso> lineas) {
  return lineas
      .map(
        (l) => LineaTicketDigital(
          descripcion: l.nombreProducto,
          cantidad: l.cantidadSolicitada,
          precioUnitario: 0,
          subtotal: 0,
        ),
      )
      .toList();
}

/// Ticket resumido de productos enviados en traspaso.
TicketDigitalContenido construirTicketDigitalTraspaso({
  required Traspaso traspaso,
  required String nombreTiendaOrigen,
  required String nombreTiendaDestino,
  String? nombreOperador,
  String? direccionTienda,
}) {
  final campos = <String, String>{
    'Origen': nombreTiendaOrigen,
    'Destino': nombreTiendaDestino,
  };
  if (nombreOperador != null && nombreOperador.trim().isNotEmpty) {
    campos['Operador'] = nombreOperador.trim();
  }
  if (traspaso.notas.trim().isNotEmpty) {
    campos['Notas'] = traspaso.notas.trim();
  }
  final totalUnidades = traspaso.lineas.fold<double>(
    0,
    (suma, linea) => suma + linea.cantidadSolicitada,
  );
  final notasPie = <String>[
    'Total unidades: ${_formatearCantidadLinea(totalUnidades)}',
    'Documento de control interno',
    '$NOMBRE_COMERCIAL_APP',
  ];
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.traspaso,
    folio: traspaso.id.substring(0, 8).toUpperCase(),
    fecha: traspaso.solicitadoEn,
    nombreTienda: nombreTiendaOrigen,
    direccionTienda: direccionTienda,
    lineas: _lineasDesdeTraspaso(traspaso.lineas),
    total: totalUnidades,
    campos: campos,
    notasPie: notasPie,
    etiquetaTotal: 'UNIDADES',
  );
}

/// Comprobante formal con seccion de recepcion y firmas.
TicketDigitalContenido construirTicketDigitalComprobanteTraspaso({
  required Traspaso traspaso,
  required String nombreTiendaOrigen,
  required String nombreTiendaDestino,
  String? nombreOperadorEnvio,
  String? direccionTienda,
}) {
  final campos = <String, String>{
    'Origen': nombreTiendaOrigen,
    'Destino': nombreTiendaDestino,
  };
  if (traspaso.notas.trim().isNotEmpty) {
    campos['Notas'] = traspaso.notas.trim();
  }
  final notasPie = <String>[
    'PRODUCTOS RECIBIDOS (confirmar al recibir)',
    ...traspaso.lineas.map(
      (l) =>
          '${l.nombreProducto}: Env ${_formatearCantidadLinea(l.cantidadSolicitada)} · Rec ________',
    ),
    'ENVIA:',
    'Nombre: ${nombreOperadorEnvio?.trim().isNotEmpty == true ? nombreOperadorEnvio!.trim() : '________________________'}',
    'Firma: ______________________________',
    'RECIBE:',
    'Nombre: ________________________',
    'Firma: ______________________________',
    'Fecha recepcion: _______________',
    '$NOMBRE_COMERCIAL_APP',
  ];
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.comprobanteTraspaso,
    folio: traspaso.id.substring(0, 8).toUpperCase(),
    fecha: traspaso.solicitadoEn,
    nombreTienda: nombreTiendaOrigen,
    direccionTienda: direccionTienda,
    lineas: _lineasDesdeTraspaso(traspaso.lineas),
    total: traspaso.lineas.fold<double>(
      0,
      (suma, linea) => suma + linea.cantidadSolicitada,
    ),
    campos: campos,
    notasPie: notasPie,
    etiquetaTotal: 'UNIDADES ENVIADAS',
  );
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

/// Ticket de compra a proveedor.
TicketDigitalContenido construirTicketDigitalCompra({
  required Compra compra,
  required String nombreProveedor,
  required String nombreTienda,
  String? direccionTienda,
}) {
  final campos = <String, String>{
    'Proveedor': nombreProveedor,
    'Fecha compra': _formatearFechaTicket(compra.fechaCompra),
    'Registrado': _formatearFechaTicket(compra.creadaEn),
  };
  if (compra.notas.trim().isNotEmpty) {
    campos['Notas'] = compra.notas.trim();
  }
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.compra,
    folio: compra.id.substring(0, 8).toUpperCase(),
    fecha: compra.fechaCompra,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    lineas: compra.lineas
        .map(
          (l) => LineaTicketDigital(
            descripcion: l.nombreProducto,
            cantidad: l.cantidad,
            precioUnitario: l.costoUnitario,
            subtotal: l.subtotal,
          ),
        )
        .toList(),
    total: compra.total,
    campos: campos,
    notasPie: [
      'Documento de control interno',
      '$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}',
    ],
  );
}

/// Resumen de pedido para entrega.
TicketDigitalContenido construirTicketDigitalPedido({
  required Pedido pedido,
  required String nombreTienda,
  String? direccionTienda,
}) {
  final campos = <String, String>{
    'Estado': _etiquetaEstadoPedido(pedido.estado),
    'Teléfono': pedido.telefonoEntrega,
    'Dirección': pedido.direccionEntrega,
    'Pago': _etiquetaMetodoPagoPedido(pedido.metodoPago),
  };
  if (pedido.esCredito) {
    campos['Crédito'] =
        '${pedido.creditoDias ?? '?'} día(s)'
        '${pedido.creditoVenceEn != null ? ' · vence ${_formatearFechaTicket(pedido.creditoVenceEn!)}' : ''}';
  }
  if (pedido.asignadoAUsuarioNombre != null &&
      pedido.asignadoAUsuarioNombre!.trim().isNotEmpty) {
    campos['Asignado a'] = pedido.asignadoAUsuarioNombre!.trim();
  }
  if (pedido.notas.trim().isNotEmpty) {
    campos['Notas'] = pedido.notas.trim();
  }
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.pedido,
    folio: pedido.id.substring(0, 8).toUpperCase(),
    fecha: pedido.creadoEn,
    nombreTienda: nombreTienda,
    direccionTienda: direccionTienda,
    nombreCliente: pedido.nombreEntrega,
    lineas: pedido.lineas
        .map(
          (l) => LineaTicketDigital(
            descripcion: l.nombreProducto,
            cantidad: l.cantidad,
            precioUnitario: l.precioUnitario,
            subtotal: l.subtotal,
          ),
        )
        .toList(),
    total: pedido.total,
    campos: campos,
    notasPie: ['$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}'],
  );
}

/// Leyenda breve para acompanar imagen o PDF al compartir (sin emojis).
String formatearLeyendaCompartirTicketDigital(
  TicketDigitalContenido contenido,
) {
  final partes = <String>[
    NOMBRE_COMERCIAL_APP,
    contenido.tituloDocumento,
    'Folio ${contenido.folio}',
  ];
  return partes.join(' · ');
}

/// Alias de [formatearLeyendaCompartirTicketDigital] para compatibilidad.
String formatearTicketDigitalWhatsApp(TicketDigitalContenido contenido) {
  return formatearLeyendaCompartirTicketDigital(contenido);
}

/// Texto plano alineado para impresora termica (sin emojis).
String formatearTicketDigitalImpresion(TicketDigitalContenido contenido) {
  final buffer = StringBuffer()
    ..writeln(contenido.tituloDocumento)
    ..writeln(NOMBRE_COMERCIAL_APP.toUpperCase())
    ..writeln(contenido.nombreTienda);
  if (contenido.direccionTienda != null &&
      contenido.direccionTienda!.trim().isNotEmpty) {
    buffer.writeln(contenido.direccionTienda!.trim());
  }
  buffer
    ..writeln('----------------------------')
    ..writeln('Folio: ${contenido.folio}')
    ..writeln('Fecha: ${_formatearFechaTicket(contenido.fecha)}');
  if (contenido.nombreCliente != null) {
    buffer.writeln('Cliente: ${contenido.nombreCliente}');
  }
  if (contenido.etiquetaSecundaria != null &&
      contenido.etiquetaSecundaria!.trim().isNotEmpty) {
    buffer.writeln('Copia: ${contenido.etiquetaSecundaria!.trim()}');
  }
  for (final entry in contenido.campos.entries) {
    buffer.writeln('${entry.key}: ${entry.value}');
  }
  buffer.writeln('----------------------------');
  for (final linea in contenido.lineas) {
    buffer.writeln(linea.descripcion);
    buffer.writeln(
      '  ${_formatearCantidadLinea(linea.cantidad)} x '
      '${formatearMoneda(linea.precioUnitario)} = '
      '${formatearMoneda(linea.subtotal)}',
    );
    if (linea.descuentoLinea > 0) {
      buffer.writeln('  Desc: ${formatearMoneda(linea.descuentoLinea)}');
    }
  }
  buffer.writeln('----------------------------');
  if (contenido.descuentoTicket > 0) {
    buffer.writeln('Descuento: -${formatearMoneda(contenido.descuentoTicket)}');
  }
  buffer.writeln(
    '${contenido.etiquetaTotal}: ${formatearMoneda(contenido.total)}',
  );
  if (contenido.creditoPlazoDias != null && contenido.creditoVenceEn != null) {
    buffer
      ..writeln('----------------------------')
      ..writeln('Plazo: ${contenido.creditoPlazoDias} día(s)')
      ..writeln(
        'Vence: ${formatearFechaCredito(contenido.creditoVenceEn!.toLocal())}',
      );
  }
  if (contenido.montoRecibido != null) {
    buffer.writeln('Recibido: ${formatearMoneda(contenido.montoRecibido!)}');
  }
  if (contenido.cambio != null) {
    buffer.writeln('Cambio: ${formatearMoneda(contenido.cambio!)}');
  }
  for (final nota in contenido.notasPie) {
    buffer.writeln(nota);
  }
  buffer.writeln('============================');
  return buffer.toString();
}
