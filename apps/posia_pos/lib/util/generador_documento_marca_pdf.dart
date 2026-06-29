/// Genera tickets y cotizaciones como PDF con logo de marca.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Guarda un documento de ticket/cotizacion en PDF con logo centrado.
Future<File> guardarDocumentoMarcaPdf({
	required String contenido,
	required Uint8List logoPng,
	required String directorio,
	String prefijo = 'ticket',
}) async {
	final carpeta = Directory(directorio);
	if (!carpeta.existsSync()) {
		carpeta.createSync(recursive: true);
	}
	final marca = DateTime.now().toUtc().millisecondsSinceEpoch;
	final archivo = File('${carpeta.path}${Platform.pathSeparator}${prefijo}_$marca.pdf');
	final logo = pw.MemoryImage(logoPng);
	final documento = pw.Document();
	documento.addPage(
		pw.Page(
			pageFormat: PdfPageFormat.roll80,
			margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
			build: (context) {
				return pw.Column(
					crossAxisAlignment: pw.CrossAxisAlignment.stretch,
					children: [
						pw.Center(
							child: pw.Image(logo, width: 180),
						),
						pw.SizedBox(height: 12),
						pw.Text(
							contenido,
							style: pw.TextStyle(
								fontSize: 9,
								lineSpacing: 2,
								font: pw.Font.courier(),
							),
						),
					],
				);
			},
		),
	);
	await archivo.writeAsBytes(await documento.save());
	return archivo;
}

/// Escribe ticket en archivo: PDF con logo si hay PNG, texto plano si no.
Future<void> escribirTicketArchivoConMarca(
	String contenido,
	Uint8List? logoPng,
	String directorio,
) async {
	if (logoPng != null && logoPng.isNotEmpty) {
		await guardarDocumentoMarcaPdf(
			contenido: contenido,
			logoPng: logoPng,
			directorio: directorio,
		);
		return;
	}
	final carpeta = Directory(directorio);
	if (!carpeta.existsSync()) {
		carpeta.createSync(recursive: true);
	}
	final marca = DateTime.now().toUtc().millisecondsSinceEpoch;
	final archivo = File('${carpeta.path}${Platform.pathSeparator}ticket_$marca.txt');
	await archivo.writeAsString(contenido);
}
