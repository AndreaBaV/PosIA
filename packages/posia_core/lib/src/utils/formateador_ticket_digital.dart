/// Construccion y formateo de tickets digitales para PDF, PNG e impresion.
library;

import '../constants/posia_constants.dart';
import '../enums/metodo_pago.dart';
import '../enums/regla_precio.dart';
import '../models/cotizacion.dart';
import '../models/linea_cotizacion.dart';
import '../models/linea_venta.dart';
import '../models/ticket_digital.dart';
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

List<LineaTicketDigital> _lineasDesdeCotizacion(List<LineaCotizacion> lineas) {
	return lineas
		.map(
			(l) => LineaTicketDigital(
				descripcion: l.nombreProducto,
				cantidad: l.cantidad,
				precioUnitario: l.precioUnitario,
				subtotal: l.cantidad * l.precioUnitario,
			),
		)
		.toList();
}

/// Arma ticket digital de una venta cerrada.
TicketDigitalContenido construirTicketDigitalVenta({
	required Venta venta,
	required String nombreTienda,
	String? direccionTienda,
	String? etiquetaCaja,
	String? nombreVendedor,
	String? codigoVendedor,
	String? nombreCliente,
	String? telefonoCliente,
	String? rfcCliente,
	String? direccionCliente,
	double? montoRecibido,
}) {
	final campos = <String, String>{};
	if (etiquetaCaja != null && etiquetaCaja.trim().isNotEmpty) {
		campos['Caja'] = etiquetaCaja.trim();
	}
	if (nombreVendedor != null && nombreVendedor.trim().isNotEmpty) {
		final vendedor = codigoVendedor != null && codigoVendedor.trim().isNotEmpty
			? '${nombreVendedor.trim()} (${codigoVendedor.trim()})'
			: nombreVendedor.trim();
		campos['Vendedor'] = vendedor;
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
	if (venta.turnoCajaId != null) {
		campos['Turno'] = venta.turnoCajaId!.substring(0, 8).toUpperCase();
	}

	double? cambio;
	if (montoRecibido != null && venta.metodoPago == MetodoPago.efectivo) {
		final diff = montoRecibido - venta.total;
		if (diff >= 0) {
			cambio = diff;
		}
	}

	final notasPie = <String>[
		'Gracias por su compra',
		'$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}',
	];

	return TicketDigitalContenido(
		tipo: TipoDocumentoTicketDigital.venta,
		folio: venta.id.substring(0, 8).toUpperCase(),
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
		folio: id.substring(0, 8).toUpperCase(),
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
		'Documento': etiquetaCopia,
		'Teléfono': telefonoCliente,
		'Dirección': direccionCliente,
	};
	if (rfcCliente != null && rfcCliente.trim().isNotEmpty) {
		campos['RFC'] = rfcCliente.trim();
	}
	if (venta.creditoDias != null && venta.creditoVenceEn != null) {
		campos['Plazo'] = '${venta.creditoDias} día(s)';
		campos['Vence'] = formatearFechaCredito(venta.creditoVenceEn!.toLocal());
	}
	final notasPie = <String>[
		if (venta.creditoDias != null && venta.creditoVenceEn != null)
			generarLeyendaCompromisoCredito(
				total: venta.total,
				diasCredito: venta.creditoDias!,
				fechaVencimiento: venta.creditoVenceEn!.toLocal(),
				nombreCliente: nombreCliente,
			),
		'Pago en una sola exhibición',
		'El deudor se obliga a pagar en la fecha de vencimiento.',
		'$NOMBRE_COMERCIAL_APP · ${nombreTienda.trim()}',
	];
	return TicketDigitalContenido(
		tipo: TipoDocumentoTicketDigital.pagare,
		folio: venta.id.substring(0, 8).toUpperCase(),
		fecha: venta.creadaEn,
		nombreTienda: nombreTienda,
		direccionTienda: direccionTienda,
		nombreCliente: nombreCliente,
		lineas: _lineasDesdeVenta(venta.lineas),
		total: venta.total,
		campos: campos,
		notasPie: notasPie,
		etiquetaTotal: 'MONTO ADEUDADO',
		etiquetaSecundaria: etiquetaCopia,
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
		folio: venta.id.substring(0, 8).toUpperCase(),
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

/// Leyenda breve para acompanar imagen o PDF al compartir (sin emojis).
String formatearLeyendaCompartirTicketDigital(TicketDigitalContenido contenido) {
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
		buffer.writeln(
			'Descuento: -${formatearMoneda(contenido.descuentoTicket)}',
		);
	}
	buffer.writeln('${contenido.etiquetaTotal}: ${formatearMoneda(contenido.total)}');
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
