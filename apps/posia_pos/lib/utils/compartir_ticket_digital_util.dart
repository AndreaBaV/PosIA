/// Comparte tickets digitales por WhatsApp como imagen con logo.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:share_plus/share_plus.dart';

import '../util/generador_ticket_digital_pdf.dart';
import '../util/marca_la_fortuna.dart';
import 'compartir_whatsapp_util.dart';

/// Comparte ticket digital: imagen PNG con logo + texto resumen.
Future<void> compartirTicketDigitalWhatsApp(
	BuildContext context, {
	required TicketDigitalContenido contenido,
	String? telefono,
}) async {
	try {
		final logo = await cargarLogoTicketMarca();
		final pngBytes = await generarTicketDigitalPngBytes(
			contenido: contenido,
			logoPng: logo,
		);
		final tempDir = await getTemporaryDirectory();
		final archivo = File(
			'${tempDir.path}${Platform.pathSeparator}'
			'ticket_${contenido.folio}_${DateTime.now().millisecondsSinceEpoch}.png',
		);
		await archivo.writeAsBytes(pngBytes);
		final caption = formatearTicketDigitalWhatsApp(contenido);
		final box = context.findRenderObject() as RenderBox?;
		final origin = box != null
			? box.localToGlobal(Offset.zero) & box.size
			: null;
		final resultado = await Share.shareXFiles(
			[XFile(archivo.path, mimeType: 'image/png')],
			text: caption,
			subject: '${contenido.tituloDocumento} · ${contenido.folio}',
			sharePositionOrigin: origin,
		);
		if (!context.mounted) {
			return;
		}
		if (resultado.status == ShareResultStatus.unavailable && telefono != null) {
			await compartirTextoWhatsAppConAviso(
				context,
				texto: caption,
				telefono: telefono,
			);
		}
	} catch (error) {
		if (!context.mounted) {
			return;
		}
		await compartirTextoWhatsAppConAviso(
			context,
			texto: formatearTicketDigitalWhatsApp(contenido),
			telefono: telefono,
		);
	}
}
