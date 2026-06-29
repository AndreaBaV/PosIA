/// Impresora con fallback: red ESC/POS y archivo local.
library;

import 'dart:typed_data';

import 'archivo_receipt_printer.dart';
import 'escpos_network_printer.dart';
import 'receipt_printer.dart';

/// Modo de impresion configurado en el dispositivo.
enum ModoImpresora {
	archivo,
	red,
	ambos,
}

/// Intenta red y respalda en archivo segun modo.
class ImpresoraConfigurable implements ReceiptPrinter {
	ImpresoraConfigurable({
		required this.modo,
		required this.hostRed,
		this.puertoRed = 9100,
		required this.directorioArchivo,
		this.escribirTicketArchivo,
	});

	final ModoImpresora modo;
	final String hostRed;
	final int puertoRed;
	final String directorioArchivo;

	/// Permite guardar PDF u otro formato en modo archivo (p. ej. con logo).
	final Future<void> Function(
		String contenido,
		Uint8List? logoPng,
		String directorio,
	)? escribirTicketArchivo;

	@override
	Future<void> imprimirTicket(
		String contenido, {
		Uint8List? logoPng,
	}) async {
		if (modo == ModoImpresora.archivo) {
			await _escribirArchivo(contenido, logoPng);
			return;
		}
		if (modo == ModoImpresora.red || modo == ModoImpresora.ambos) {
			try {
				await EscPosNetworkPrinter(host: hostRed, port: puertoRed)
					.imprimirTicket(contenido, logoPng: logoPng);
				if (modo == ModoImpresora.red) {
					return;
				}
			} catch (_) {
				if (modo == ModoImpresora.red) {
					rethrow;
				}
			}
		}
		await _escribirArchivo(contenido, logoPng);
	}

	Future<void> _escribirArchivo(String contenido, Uint8List? logoPng) async {
		if (escribirTicketArchivo != null) {
			await escribirTicketArchivo!(contenido, logoPng, directorioArchivo);
			return;
		}
		await ArchivoReceiptPrinter(directorio: directorioArchivo)
			.imprimirTicket(contenido, logoPng: logoPng);
	}
}
