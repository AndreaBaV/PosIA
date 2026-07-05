/// Impresora de tickets que guarda PNG en carpeta local.
library;

import 'dart:io';
import 'dart:typed_data';

import 'receipt_printer.dart';

/// Escribe tickets como archivos PNG en disco.
class ArchivoReceiptPrinter implements ReceiptPrinter {
	ArchivoReceiptPrinter({required this.directorio});

	final String directorio;

	@override
	Future<void> imprimirTicket({
		required Uint8List imagenTicketPng,
	}) async {
		final carpeta = Directory(directorio);
		if (!carpeta.existsSync()) {
			carpeta.createSync(recursive: true);
		}
		final marca = DateTime.now().toUtc().millisecondsSinceEpoch;
		final archivo = File(
			'${carpeta.path}${Platform.pathSeparator}ticket_$marca.png',
		);
		await archivo.writeAsBytes(imagenTicketPng);
	}
}
