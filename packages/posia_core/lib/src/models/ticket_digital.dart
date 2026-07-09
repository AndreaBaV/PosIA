/// Modelo estructurado para ticket digital (WhatsApp, PDF, vista previa).
library;

/// Tipo de documento comercial a mostrar.
enum TipoDocumentoTicketDigital {
  venta,
  cotizacion,
  pagare,
  liquidacionCredito,
  corteCaja,
  traspaso,
  comprobanteTraspaso,
  compra,
  pedido,
}

/// Linea de producto en ticket digital.
class LineaTicketDigital {
  const LineaTicketDigital({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.descuentoLinea = 0.0,
  });

  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final double descuentoLinea;
}

/// Contenido de ticket digital listo para formatear o renderizar.
class TicketDigitalContenido {
  const TicketDigitalContenido({
    required this.tipo,
    required this.folio,
    required this.fecha,
    required this.nombreTienda,
    required this.lineas,
    required this.total,
    this.direccionTienda,
    this.nombreCliente,
    this.campos = const {},
    this.descuentoTicket = 0.0,
    this.notasPie = const [],
    this.montoRecibido,
    this.cambio,
    this.etiquetaTotal = 'TOTAL',
    this.etiquetaSecundaria,
    this.creditoPlazoDias,
    this.creditoVenceEn,
  });

  final TipoDocumentoTicketDigital tipo;
  final String folio;
  final DateTime fecha;
  final String nombreTienda;
  final String? direccionTienda;
  final String? nombreCliente;
  final List<LineaTicketDigital> lineas;
  final double total;
  final double descuentoTicket;
  final Map<String, String> campos;
  final List<String> notasPie;
  final double? montoRecibido;
  final double? cambio;
  final String etiquetaTotal;
  final String? etiquetaSecundaria;
  /// Plazo en dias para pagares y documentos de credito.
  final int? creditoPlazoDias;
  /// Fecha limite de pago del credito.
  final DateTime? creditoVenceEn;

  String get tituloDocumento => switch (tipo) {
    TipoDocumentoTicketDigital.venta => 'TICKET DE VENTA',
    TipoDocumentoTicketDigital.cotizacion => 'COTIZACIÓN',
    TipoDocumentoTicketDigital.pagare => 'PAGARÉ',
    TipoDocumentoTicketDigital.liquidacionCredito => 'LIQUIDACIÓN DE CRÉDITO',
    TipoDocumentoTicketDigital.corteCaja => 'CORTE DE CAJA',
    TipoDocumentoTicketDigital.traspaso => 'TRASPASO',
    TipoDocumentoTicketDigital.comprobanteTraspaso => 'COMPROBANTE TRASPASO',
    TipoDocumentoTicketDigital.compra => 'COMPRA / ENTRADA',
    TipoDocumentoTicketDigital.pedido => 'PEDIDO',
  };

  String get subtituloDocumento => switch (tipo) {
    TipoDocumentoTicketDigital.venta => 'Comprobante de compra',
    TipoDocumentoTicketDigital.cotizacion => 'Documento informativo',
    TipoDocumentoTicketDigital.pagare => 'Venta a crédito · una exhibición',
    TipoDocumentoTicketDigital.liquidacionCredito => 'Comprobante de pago',
    TipoDocumentoTicketDigital.corteCaja => 'Resumen de turno',
    TipoDocumentoTicketDigital.traspaso => 'Documento de control interno',
    TipoDocumentoTicketDigital.comprobanteTraspaso => 'Envío y recepción',
    TipoDocumentoTicketDigital.compra => 'Entrada de mercancía',
    TipoDocumentoTicketDigital.pedido => 'Resumen de entrega',
  };

  /// Si es false, la tabla muestra cantidades en lugar de importes.
  bool get mostrarImportes => switch (tipo) {
    TipoDocumentoTicketDigital.traspaso ||
    TipoDocumentoTicketDigital.comprobanteTraspaso => false,
    _ => true,
  };
}
