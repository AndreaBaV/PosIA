/// Comparte tickets digitales por WhatsApp como imagen o PDF con logo.
library;

import 'package:posia_ui/posia_ui.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';

import '../util/generador_ticket_digital_pdf.dart';
import '../util/marca_la_fortuna.dart';
import 'compartir_whatsapp_util.dart';

String _nombreArchivoTicket(String folio, String extension) {
	final marca = DateTime.now().millisecondsSinceEpoch;
	return 'ticket_${folio}_$marca.$extension';
}

/// Comparte ticket digital: PNG con logo y detalle; PDF como respaldo.
Future<void> compartirTicketDigitalWhatsApp(
	BuildContext context, {
	required TicketDigitalContenido contenido,
	String? telefono,
}) async {
	final leyenda = formatearLeyendaCompartirTicketDigital(contenido);
	final nombreBase = 'ticket_${contenido.folio}';
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
		await compartirArchivoWhatsAppConAviso(
			context,
			rutaArchivo: pngFile.path,
			mimeType: 'image/png',
			leyenda: leyenda,
			telefono: telefono,
			nombreDescarga: '$nombreBase.png',
		);
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
			await compartirArchivoWhatsAppConAviso(
				context,
				rutaArchivo: pdfFile.path,
				mimeType: 'application/pdf',
				leyenda: leyenda,
				telefono: telefono,
				nombreDescarga: '$nombreBase.pdf',
			);
		} catch (error) {
			if (!context.mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text('No se pudo generar el documento: $error'),
					backgroundColor: Colors.red.shade700,
				),
			);
		}
	}
}
