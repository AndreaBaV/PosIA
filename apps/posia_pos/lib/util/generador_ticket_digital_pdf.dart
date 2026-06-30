/// Renderiza tickets digitales como PDF o PNG con logo de marca.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:posia_core/posia_core.dart';
import 'package:printing/printing.dart';

const _verdeMarca = PdfColor.fromInt(0xFF2E7D32);
const _naranjaCredito = PdfColor.fromInt(0xFFE65100);
const _grisOscuro = PdfColor.fromInt(0xFF263238);
const _grisTexto = PdfColor.fromInt(0xFF546E7A);
const _grisClaro = PdfColor.fromInt(0xFFECEFF1);
const _grisFondo = PdfColor.fromInt(0xFFF5F7F8);

PdfColor _colorAcento(TipoDocumentoTicketDigital tipo) {
	return switch (tipo) {
		TipoDocumentoTicketDigital.pagare ||
		TipoDocumentoTicketDigital.liquidacionCredito => _naranjaCredito,
		_ => _verdeMarca,
	};
}

String _cantidadLinea(double cantidad) {
	if (cantidad == cantidad.roundToDouble()) {
		return cantidad.toStringAsFixed(0);
	}
	return cantidad.toStringAsFixed(2);
}

String _fechaLegible(DateTime fechaUtc) {
	final local = fechaUtc.toLocal();
	final dia = local.day.toString().padLeft(2, '0');
	final mes = local.month.toString().padLeft(2, '0');
	final hora = local.hour.toString().padLeft(2, '0');
	final minuto = local.minute.toString().padLeft(2, '0');
	return '$dia/$mes/${local.year}  $hora:$minuto';
}

double _calcularAltoPagina(TicketDigitalContenido contenido) {
	const base = 148.0;
	const metaLine = 12.5;
	const productLine = 26.0;
	const footerLine = 10.0;
	final metaCount =
		2 +
		contenido.campos.length +
		(contenido.nombreCliente != null ? 1 : 0);
	var extra = 0.0;
	if (contenido.descuentoTicket > 0) {
		extra += 12.0;
	}
	if (contenido.montoRecibido != null) {
		extra += 12.0;
	}
	if (contenido.cambio != null) {
		extra += 12.0;
	}
	if (contenido.etiquetaSecundaria != null) {
		extra += 10.0;
	}
	final altoMm =
		base +
		(metaCount * metaLine) +
		(contenido.lineas.length * productLine) +
		(contenido.notasPie.length * footerLine) +
		extra +
		40.0;
	return altoMm * PdfPageFormat.mm;
}

pw.Widget _lineaDivisora({PdfColor color = _grisClaro}) {
	return pw.Container(
		margin: const pw.EdgeInsets.symmetric(vertical: 7),
		height: 0.6,
		color: color,
	);
}

pw.Widget _lineaAcento(PdfColor color) {
	return pw.Container(
		margin: const pw.EdgeInsets.only(top: 4, bottom: 10),
		height: 2,
		width: 48,
		color: color,
	);
}

pw.Widget _filaMeta(String etiqueta, String valor) {
	return pw.Padding(
		padding: const pw.EdgeInsets.only(bottom: 3),
		child: pw.Row(
			crossAxisAlignment: pw.CrossAxisAlignment.start,
			children: [
				pw.SizedBox(
					width: 68,
					child: pw.Text(
						etiqueta,
						style: const pw.TextStyle(fontSize: 8, color: _grisTexto),
					),
				),
				pw.Expanded(
					child: pw.Text(
						valor,
						style: pw.TextStyle(
							fontSize: 8.5,
							color: _grisOscuro,
							fontWeight: pw.FontWeight.bold,
						),
					),
				),
			],
		),
	);
}

pw.Widget _celdaTabla(
	String texto, {
	bool bold = false,
	pw.TextAlign align = pw.TextAlign.left,
	PdfColor? color,
}) {
	return pw.Padding(
		padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
		child: pw.Text(
			texto,
			textAlign: align,
			style: pw.TextStyle(
				fontSize: 8,
				color: color ?? _grisOscuro,
				fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
			),
		),
	);
}

List<pw.Widget> _construirContenido({
	required TicketDigitalContenido contenido,
	required pw.MemoryImage logo,
}) {
	final acento = _colorAcento(contenido.tipo);
	return [
		pw.Center(child: pw.Image(logo, width: 148)),
		pw.SizedBox(height: 6),
		pw.Text(
			NOMBRE_COMERCIAL_APP.toUpperCase(),
			textAlign: pw.TextAlign.center,
			style: const pw.TextStyle(
				fontSize: 7.5,
				color: _grisTexto,
				letterSpacing: 2.4,
			),
		),
		pw.SizedBox(height: 4),
		pw.Text(
			contenido.tituloDocumento,
			textAlign: pw.TextAlign.center,
			style: pw.TextStyle(
				fontSize: 11,
				fontWeight: pw.FontWeight.bold,
				color: _grisOscuro,
				letterSpacing: 0.6,
			),
		),
		if (contenido.etiquetaSecundaria != null)
			pw.Padding(
				padding: const pw.EdgeInsets.only(top: 2),
				child: pw.Text(
					contenido.etiquetaSecundaria!,
					textAlign: pw.TextAlign.center,
					style: const pw.TextStyle(fontSize: 8, color: _grisTexto),
				),
			),
		pw.Text(
			contenido.subtituloDocumento,
			textAlign: pw.TextAlign.center,
			style: const pw.TextStyle(fontSize: 7.5, color: _grisTexto),
		),
		pw.Center(child: _lineaAcento(acento)),
		pw.Text(
			contenido.nombreTienda,
			style: pw.TextStyle(
				fontSize: 10,
				fontWeight: pw.FontWeight.bold,
				color: _grisOscuro,
			),
		),
		if (contenido.direccionTienda != null &&
			contenido.direccionTienda!.trim().isNotEmpty)
			pw.Text(
				contenido.direccionTienda!.trim(),
				style: const pw.TextStyle(fontSize: 8, color: _grisTexto),
			),
		_lineaDivisora(),
		_filaMeta('Folio', contenido.folio),
		_filaMeta('Fecha', _fechaLegible(contenido.fecha)),
		if (contenido.nombreCliente != null)
			_filaMeta('Cliente', contenido.nombreCliente!),
		for (final entry in contenido.campos.entries)
			_filaMeta(entry.key, entry.value),
		_lineaDivisora(),
		pw.Container(
			padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
			decoration: const pw.BoxDecoration(color: _grisFondo),
			child: pw.Row(
				children: [
					pw.Expanded(
						child: _celdaTabla('Producto', bold: true, color: _grisTexto),
					),
					pw.SizedBox(
						width: 36,
						child: _celdaTabla(
							'Cant.',
							bold: true,
							align: pw.TextAlign.center,
							color: _grisTexto,
						),
					),
					pw.SizedBox(
						width: 52,
						child: _celdaTabla(
							'Importe',
							bold: true,
							align: pw.TextAlign.right,
							color: _grisTexto,
						),
					),
				],
			),
		),
		for (final linea in contenido.lineas)
			pw.Padding(
				padding: const pw.EdgeInsets.symmetric(vertical: 3),
				child: pw.Column(
					crossAxisAlignment: pw.CrossAxisAlignment.stretch,
					children: [
						pw.Row(
							crossAxisAlignment: pw.CrossAxisAlignment.start,
							children: [
								pw.Expanded(
									child: pw.Text(
										linea.descripcion,
										style: const pw.TextStyle(
											fontSize: 8.5,
											color: _grisOscuro,
										),
									),
								),
								pw.SizedBox(
									width: 36,
									child: pw.Text(
										_cantidadLinea(linea.cantidad),
										textAlign: pw.TextAlign.center,
										style: const pw.TextStyle(
											fontSize: 8,
											color: _grisTexto,
										),
									),
								),
								pw.SizedBox(
									width: 52,
									child: pw.Text(
										formatearMoneda(linea.subtotal),
										textAlign: pw.TextAlign.right,
										style: pw.TextStyle(
											fontSize: 8.5,
											fontWeight: pw.FontWeight.bold,
											color: _grisOscuro,
										),
									),
								),
							],
						),
						pw.Text(
							'${_cantidadLinea(linea.cantidad)} x '
							'${formatearMoneda(linea.precioUnitario)}',
							style: const pw.TextStyle(fontSize: 7.5, color: _grisTexto),
						),
						if (linea.descuentoLinea > 0)
							pw.Text(
								'Desc. -${formatearMoneda(linea.descuentoLinea)}',
								style: const pw.TextStyle(fontSize: 7.5, color: _grisTexto),
							),
					],
				),
			),
		_lineaDivisora(color: acento),
		if (contenido.descuentoTicket > 0)
			pw.Row(
				mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
				children: [
					pw.Text(
						'Descuento',
						style: const pw.TextStyle(fontSize: 8.5, color: _grisTexto),
					),
					pw.Text(
						'-${formatearMoneda(contenido.descuentoTicket)}',
						style: const pw.TextStyle(fontSize: 8.5, color: _grisTexto),
					),
				],
			),
		pw.SizedBox(height: 4),
		pw.Row(
			mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
			crossAxisAlignment: pw.CrossAxisAlignment.end,
			children: [
				pw.Text(
					contenido.etiquetaTotal,
					style: pw.TextStyle(
						fontSize: 9.5,
						fontWeight: pw.FontWeight.bold,
						color: acento,
						letterSpacing: 0.4,
					),
				),
				pw.Text(
					formatearMoneda(contenido.total),
					style: pw.TextStyle(
						fontSize: 14,
						fontWeight: pw.FontWeight.bold,
						color: _grisOscuro,
					),
				),
			],
		),
		if (contenido.montoRecibido != null) ...[
			pw.SizedBox(height: 6),
			_filaMeta('Recibido', formatearMoneda(contenido.montoRecibido!)),
		],
		if (contenido.cambio != null)
			_filaMeta('Cambio', formatearMoneda(contenido.cambio!)),
		_lineaDivisora(),
		for (final nota in contenido.notasPie)
			pw.Padding(
				padding: const pw.EdgeInsets.only(bottom: 2),
				child: pw.Text(
					nota,
					textAlign: pw.TextAlign.center,
					style: const pw.TextStyle(fontSize: 7.5, color: _grisTexto),
				),
			),
	];
}

/// Genera bytes PDF del ticket digital con logo.
Future<Uint8List> generarTicketDigitalPdfBytes({
	required TicketDigitalContenido contenido,
	required Uint8List logoPng,
}) async {
	final logo = pw.MemoryImage(logoPng);
	final documento = pw.Document();
	final pageFormat = PdfPageFormat(
		PdfPageFormat.roll80.width,
		_calcularAltoPagina(contenido),
		marginLeft: 10,
		marginRight: 10,
		marginTop: 10,
		marginBottom: 10,
	);
	documento.addPage(
		pw.Page(
			pageFormat: pageFormat,
			build: (context) => pw.Column(
				crossAxisAlignment: pw.CrossAxisAlignment.stretch,
				children: _construirContenido(contenido: contenido, logo: logo),
			),
		),
	);
	return documento.save();
}

/// Rasteriza el ticket como PNG para WhatsApp (pagina unica con todo el detalle).
Future<Uint8List> generarTicketDigitalPngBytes({
	required TicketDigitalContenido contenido,
	required Uint8List logoPng,
}) async {
	final pdfBytes = await generarTicketDigitalPdfBytes(
		contenido: contenido,
		logoPng: logoPng,
	);
	final paginas = await Printing.raster(pdfBytes, dpi: 200).toList();
	if (paginas.isEmpty) {
		throw StateError('No se pudo generar imagen del ticket');
	}
	return paginas.first.toPng();
}
