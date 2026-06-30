/// Comparte tickets digitales por WhatsApp como imagen o PDF con logo.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:share_plus/share_plus.dart';

import '../util/generador_ticket_digital_pdf.dart';
import '../util/marca_la_fortuna.dart';
import 'compartir_whatsapp_util.dart';

String _nombreArchivoTicket(String folio, String extension) {
	final marca = DateTime.now().millisecondsSinceEpoch;
	return 'ticket_${folio}_$marca.$extension';
}

Rect? _origenCompartir(BuildContext context) {
	final box = context.findRenderObject() as RenderBox?;
	if (box == null) {
		return null;
	}
	return box.localToGlobal(Offset.zero) & box.size;
}

Future<ShareResult> _compartirArchivoTicket({
	required BuildContext context,
	required List<XFile> archivos,
	required String leyenda,
	required String asunto,
}) {
	return Share.shareXFiles(
		archivos,
		text: leyenda,
		subject: asunto,
		sharePositionOrigin: _origenCompartir(context),
	);
}

/// Comparte ticket digital: PNG con logo y detalle; PDF como respaldo.
Future<void> compartirTicketDigitalWhatsApp(
	BuildContext context, {
	required TicketDigitalContenido contenido,
	String? telefono,
}) async {
	final leyenda = formatearLeyendaCompartirTicketDigital(contenido);
	final asunto = '${contenido.tituloDocumento} · ${contenido.folio}';
	try {
		final logo = await cargarLogoTicketMarca();
		final tempDir = await getTemporaryDirectory();
		final pngBytes = await generarTicketDigitalPngBytes(
			contenido: contenido,
			logoPng: logo,
		);
		final pngFile = File(
			'${tempDir.path}${Platform.pathSeparator}'
			'${_nombreArchivoTicket(contenido.folio, 'png')}',
		);
		await pngFile.writeAsBytes(pngBytes);
		if (!context.mounted) {
			return;
		}
		final resultado = await _compartirArchivoTicket(
			context: context,
			archivos: [XFile(pngFile.path, mimeType: 'image/png')],
			leyenda: leyenda,
			asunto: asunto,
		);
		if (!context.mounted) {
			return;
		}
		if (resultado.status == ShareResultStatus.unavailable) {
			await compartirTextoWhatsAppConAviso(
				context,
				texto: leyenda,
				telefono: telefono,
			);
		}
	} catch (_) {
		try {
			final logo = await cargarLogoTicketMarca();
			final tempDir = await getTemporaryDirectory();
			final pdfBytes = await generarTicketDigitalPdfBytes(
				contenido: contenido,
				logoPng: logo,
			);
			final pdfFile = File(
				'${tempDir.path}${Platform.pathSeparator}'
				'${_nombreArchivoTicket(contenido.folio, 'pdf')}',
			);
			await pdfFile.writeAsBytes(pdfBytes);
			if (!context.mounted) {
				return;
			}
			final resultado = await _compartirArchivoTicket(
				context: context,
				archivos: [XFile(pdfFile.path, mimeType: 'application/pdf')],
				leyenda: leyenda,
				asunto: asunto,
			);
			if (!context.mounted) {
				return;
			}
			if (resultado.status == ShareResultStatus.unavailable) {
				await compartirTextoWhatsAppConAviso(
					context,
					texto: leyenda,
					telefono: telefono,
				);
			}
		} catch (error) {
			if (!context.mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('No se pudo generar el documento: $error'),
					backgroundColor: Colors.red.shade700,
				),
			);
		}
	}
}
