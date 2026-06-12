/// Impresora de tickets que guarda en carpeta local.
library;

import 'dart:io';

import 'receipt_printer.dart';

/// Escribe tickets como archivos de texto en disco.
class ArchivoReceiptPrinter implements ReceiptPrinter {
	ArchivoReceiptPrinter({required this.directorio});

	final String directorio;

	@override
	Future<void> imprimirTicket(String contenido) async {
		final carpeta = Directory(directorio);
		if (!carpeta.existsSync()) {
			carpeta.createSync(recursive: true);
		}
		final marca = DateTime.now().toUtc().millisecondsSinceEpoch;
		final archivo = File('${carpeta.path}${Platform.pathSeparator}ticket_$marca.txt');
		await archivo.writeAsString(contenido);
	}
}
