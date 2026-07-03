/// Impresora de tickets que guarda en carpeta local.
library;

import 'dart:io';
import 'dart:typed_data';

import 'receipt_printer.dart';

/// Escribe tickets como archivos de texto o PNG en disco.
class ArchivoReceiptPrinter implements ReceiptPrinter {
	ArchivoReceiptPrinter({required this.directorio});

	final String directorio;

	@override
	Future<void> imprimirTicket(
		String contenido, {
		Uint8List? logoPng,
		Uint8List? imagenTicketPng,
	}) async {
		final carpeta = Directory(directorio);
		if (!carpeta.existsSync()) {
			carpeta.createSync(recursive: true);
		}
		final marca = DateTime.now().toUtc().millisecondsSinceEpoch;
		if (imagenTicketPng != null && imagenTicketPng.isNotEmpty) {
			final archivo = File(
				'${carpeta.path}${Platform.pathSeparator}ticket_$marca.png',
			);
			await archivo.writeAsBytes(imagenTicketPng);
			return;
		}
		final archivo = File(
			'${carpeta.path}${Platform.pathSeparator}ticket_$marca.txt',
		);
		await archivo.writeAsString(contenido);
	}
}
