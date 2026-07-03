/// Comparte tickets digitales por WhatsApp como PDF con diseno completo.
library;

import 'package:posia_ui/posia_ui.dart';

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../util/generador_ticket_digital_pdf.dart';
import '../util/marca_la_fortuna.dart';
import '../util/renderizador_ticket_bitmap.dart';
import 'compartir_whatsapp_util.dart';
import 'ticket_archivo_util.dart';

/// Genera PDF con diseno completo, lo guarda y abre WhatsApp.
///
/// En impresora termica se usa bitmap; para WhatsApp siempre PDF formateado.
/// Si el PDF falla, intenta PNG como ultimo recurso.
Future<void> compartirTicketDigitalWhatsApp(
	BuildContext context, {
	required TicketDigitalContenido contenido,
	String? telefono,
	int anchoRolloMm = 80,
}) async {
	final leyenda = formatearLeyendaCompartirTicketDigital(contenido);
	try {
		final logo = await cargarLogoTicketMarca();
		final pdfBytes = await generarTicketDigitalPdfBytes(
			contenido: contenido,
			logoPng: logo,
		);
		final archivo = await guardarTicketEnDocumentos(
			folio: contenido.folio,
			bytes: pdfBytes,
			extension: 'pdf',
		);
		if (archivo == null) {
			throw StateError('No se pudo guardar el ticket');
		}
		if (!context.mounted) {
			return;
		}
		await compartirArchivoWhatsAppConAviso(
			context,
			rutaArchivo: archivo.path,
			mimeType: 'application/pdf',
			leyenda: leyenda,
			telefono: telefono,
		);
	} catch (errorPdf) {
		try {
			final logo = await cargarLogoTicketMarca();
			final pngBytes = renderizarTicketDigitalPng(
				contenido: contenido,
				logoPng: logo,
				anchoRolloMm: anchoRolloMm,
			);
			final archivo = await guardarTicketEnDocumentos(
				folio: contenido.folio,
				bytes: pngBytes,
				extension: 'png',
			);
			if (archivo == null) {
				throw StateError('No se pudo guardar el ticket');
			}
			if (!context.mounted) {
				return;
			}
			await compartirArchivoWhatsAppConAviso(
				context,
				rutaArchivo: archivo.path,
				mimeType: 'image/png',
				leyenda: leyenda,
				telefono: telefono,
			);
		} catch (errorPng) {
			if (!context.mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(
				context,
				SnackBar(
					content: Text(
						'No se pudo generar el ticket.\n'
						'PDF: $errorPdf\nPNG: $errorPng',
					),
					backgroundColor: Colors.red.shade700,
					duration: const Duration(seconds: 8),
				),
			);
		}
	}
}
