/// Renderiza tickets digitales como PDF o PNG con logo de marca.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:posia_core/posia_core.dart';
import 'package:printing/printing.dart';

const _verdeMarca = PdfColor.fromInt(0xFF2E7D32);
const _naranjaCredito = PdfColor.fromInt(0xFFE65100);
const _grisTexto = PdfColor.fromInt(0xFF455A64);
const _grisClaro = PdfColor.fromInt(0xFFECEFF1);

PdfColor _colorEncabezado(TipoDocumentoTicketDigital tipo) {
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

pw.Widget _lineaDivisora() {
	return pw.Container(
		margin: const pw.EdgeInsets.symmetric(vertical: 8),
		height: 1,
		color: _grisClaro,
	);
}

pw.Widget _filaMeta(String etiqueta, String valor) {
	return pw.Padding(
		padding: const pw.EdgeInsets.only(bottom: 3),
		child: pw.Row(
			crossAxisAlignment: pw.CrossAxisAlignment.start,
			children: [
				pw.SizedBox(
					width: 72,
					child: pw.Text(
						etiqueta,
						style: pw.TextStyle(fontSize: 8.5, color: _grisTexto),
					),
				),
				pw.Expanded(
					child: pw.Text(
						valor,
						style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
					),
				),
			],
		),
	);
}

/// Genera bytes PDF del ticket digital con logo.
Future<Uint8List> generarTicketDigitalPdfBytes({
	required TicketDigitalContenido contenido,
	required Uint8List logoPng,
}) async {
	final logo = pw.MemoryImage(logoPng);
	final colorEncabezado = _colorEncabezado(contenido.tipo);
	final documento = pw.Document();
	documento.addPage(
		pw.MultiPage(
			pageFormat: PdfPageFormat.roll80,
			margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
			build: (context) => [
				pw.Container(
					padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
					decoration: pw.BoxDecoration(
						color: colorEncabezado,
						borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
					),
					child: pw.Column(
						children: [
							pw.Center(child: pw.Image(logo, width: 140)),
							pw.SizedBox(height: 8),
							pw.Text(
								contenido.tituloDocumento,
								style: pw.TextStyle(
									color: PdfColors.white,
									fontSize: 11,
									fontWeight: pw.FontWeight.bold,
									letterSpacing: 1.2,
								),
							),
							if (contenido.etiquetaSecundaria != null)
								pw.Text(
									contenido.etiquetaSecundaria!,
									style: const pw.TextStyle(
										color: PdfColors.white,
										fontSize: 8,
									),
								),
							pw.Text(
								contenido.subtituloDocumento,
								style: const pw.TextStyle(
									color: PdfColors.white,
									fontSize: 8,
								),
							),
						],
					),
				),
				pw.SizedBox(height: 10),
				pw.Text(
					contenido.nombreTienda,
					style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
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
				pw.Table(
					border: const pw.TableBorder(
						bottom: pw.BorderSide(color: _grisClaro),
					),
					columnWidths: const {
						0: pw.FlexColumnWidth(3),
						1: pw.FlexColumnWidth(1),
						2: pw.FlexColumnWidth(1.4),
					},
					children: [
						pw.TableRow(
							decoration: const pw.BoxDecoration(color: _grisClaro),
							children: [
								_celdaTabla('Producto', bold: true),
								_celdaTabla('Cant.', bold: true, align: pw.TextAlign.center),
								_celdaTabla('Importe', bold: true, align: pw.TextAlign.right),
							],
						),
						...contenido.lineas.map(
							(linea) => pw.TableRow(
								children: [
									pw.Padding(
										padding: const pw.EdgeInsets.symmetric(vertical: 5),
										child: pw.Column(
											crossAxisAlignment: pw.CrossAxisAlignment.start,
											children: [
												pw.Text(
													linea.descripcion,
													style: const pw.TextStyle(fontSize: 8.5),
												),
												pw.Text(
													'${_cantidadLinea(linea.cantidad)} × '
													'${formatearMoneda(linea.precioUnitario)}',
													style: const pw.TextStyle(
														fontSize: 7.5,
														color: _grisTexto,
													),
												),
											],
										),
									),
									_celdaTabla(
										_cantidadLinea(linea.cantidad),
										align: pw.TextAlign.center,
									),
									_celdaTabla(
										formatearMoneda(linea.subtotal),
										align: pw.TextAlign.right,
										bold: true,
									),
								],
							),
						),
					],
				),
				_lineaDivisora(),
				if (contenido.descuentoTicket > 0)
					pw.Row(
						mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
						children: [
							pw.Text('Descuento', style: const pw.TextStyle(fontSize: 9)),
							pw.Text(
								'-${formatearMoneda(contenido.descuentoTicket)}',
								style: const pw.TextStyle(fontSize: 9),
							),
						],
					),
				pw.Container(
					margin: const pw.EdgeInsets.only(top: 6),
					padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
					decoration: pw.BoxDecoration(
						color: colorEncabezado,
						borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
					),
					child: pw.Row(
						mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
						children: [
							pw.Text(
								contenido.etiquetaTotal,
								style: pw.TextStyle(
									color: PdfColors.white,
									fontSize: 11,
									fontWeight: pw.FontWeight.bold,
								),
							),
							pw.Text(
								formatearMoneda(contenido.total),
								style: pw.TextStyle(
									color: PdfColors.white,
									fontSize: 13,
									fontWeight: pw.FontWeight.bold,
								),
							),
						],
					),
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
				pw.SizedBox(height: 4),
				pw.Text(
					NOMBRE_COMERCIAL_APP,
					textAlign: pw.TextAlign.center,
					style: pw.TextStyle(
						fontSize: 8,
						fontWeight: pw.FontWeight.bold,
						color: colorEncabezado,
					),
				),
			],
		),
	);
	return documento.save();
}

pw.Widget _celdaTabla(
	String texto, {
	bool bold = false,
	pw.TextAlign align = pw.TextAlign.left,
}) {
	return pw.Padding(
		padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
		child: pw.Text(
			texto,
			textAlign: align,
			style: pw.TextStyle(
				fontSize: 8,
				fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
			),
		),
	);
}

/// Rasteriza la primera pagina del ticket como PNG para WhatsApp.
Future<Uint8List> generarTicketDigitalPngBytes({
	required TicketDigitalContenido contenido,
	required Uint8List logoPng,
}) async {
	final pdfBytes = await generarTicketDigitalPdfBytes(
		contenido: contenido,
		logoPng: logoPng,
	);
	final paginas = await Printing.raster(pdfBytes, dpi: 180).toList();
	if (paginas.isEmpty) {
		throw StateError('No se pudo generar imagen del ticket');
	}
	return paginas.first.toPng();
}
