/// Impresora con fallback: red ESC/POS y archivo local.
library;

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
	});

	final ModoImpresora modo;
	final String hostRed;
	final int puertoRed;
	final String directorioArchivo;

	@override
	Future<void> imprimirTicket(String contenido) async {
		if (modo == ModoImpresora.archivo) {
			await ArchivoReceiptPrinter(directorio: directorioArchivo).imprimirTicket(contenido);
			return;
		}
		if (modo == ModoImpresora.red || modo == ModoImpresora.ambos) {
			try {
				await EscPosNetworkPrinter(host: hostRed, port: puertoRed).imprimirTicket(contenido);
				if (modo == ModoImpresora.red) {
					return;
				}
			} catch (_) {
				if (modo == ModoImpresora.red) {
					rethrow;
				}
			}
		}
		await ArchivoReceiptPrinter(directorio: directorioArchivo).imprimirTicket(contenido);
	}
}
