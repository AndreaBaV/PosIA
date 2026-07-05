/// Impresora con fallback: red ESC/POS, USB Windows y archivo local.
library;

import 'dart:typed_data';

import 'archivo_receipt_printer.dart';
import 'escpos_network_printer.dart';
import 'escpos_windows_printer.dart';
import 'receipt_printer.dart';

/// Modo de impresion configurado en el dispositivo.
enum ModoImpresora {
	archivo,
	red,
	ambos,
	usbWindows,
}

/// Intenta el canal principal segun modo y respalda en archivo si aplica.
class ImpresoraConfigurable implements ReceiptPrinter {
	ImpresoraConfigurable({
		required this.modo,
		required this.hostRed,
		this.puertoRed = 9100,
		required this.directorioArchivo,
		this.nombreImpresoraUsb = '',
		this.anchoRolloMm = 80,
		this.permitirRespaldoArchivo = true,
	});

	final ModoImpresora modo;
	final String hostRed;
	final int puertoRed;
	final String directorioArchivo;

	/// Nombre exacto de la impresora USB instalada en Windows.
	final String nombreImpresoraUsb;

	/// Ancho del rollo termico en mm (58 o 80).
	final int anchoRolloMm;

	/// Si es false, un fallo de red no guarda copia local (util en movil con IP).
	final bool permitirRespaldoArchivo;

	@override
	Future<void> imprimirTicket({
		required Uint8List imagenTicketPng,
	}) async {
		if (modo == ModoImpresora.archivo) {
			await ArchivoReceiptPrinter(directorio: directorioArchivo)
				.imprimirTicket(imagenTicketPng: imagenTicketPng);
			return;
		}
		if (modo == ModoImpresora.usbWindows) {
			await EscPosWindowsPrinter(
				nombreImpresora: nombreImpresoraUsb,
				anchoRolloMm: anchoRolloMm,
			).imprimirTicket(imagenTicketPng: imagenTicketPng);
			return;
		}
		if (modo == ModoImpresora.red || modo == ModoImpresora.ambos) {
			try {
				await EscPosNetworkPrinter(
					host: hostRed,
					port: puertoRed,
					anchoRolloMm: anchoRolloMm,
				).imprimirTicket(imagenTicketPng: imagenTicketPng);
				if (modo == ModoImpresora.red) {
					return;
				}
			} catch (_) {
				if (modo == ModoImpresora.red || !permitirRespaldoArchivo) {
					rethrow;
				}
			}
		}
		if (!permitirRespaldoArchivo) {
			throw StateError('No se pudo imprimir en la impresora de red');
		}
		await ArchivoReceiptPrinter(directorio: directorioArchivo)
			.imprimirTicket(imagenTicketPng: imagenTicketPng);
	}
}
