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
		this.escribirTicketArchivo,
	});

	final ModoImpresora modo;
	final String hostRed;
	final int puertoRed;
	final String directorioArchivo;

	/// Nombre exacto de la impresora USB instalada en Windows.
	final String nombreImpresoraUsb;

	/// Ancho del rollo termico en mm (58 o 80).
	final int anchoRolloMm;

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
		Uint8List? imagenTicketPng,
	}) async {
		if (modo == ModoImpresora.archivo) {
			await _escribirArchivo(
				contenido,
				logoPng,
				imagenTicketPng: imagenTicketPng,
			);
			return;
		}
		if (modo == ModoImpresora.usbWindows) {
			await EscPosWindowsPrinter(
				nombreImpresora: nombreImpresoraUsb,
				anchoRolloMm: anchoRolloMm,
			).imprimirTicket(
				contenido,
				logoPng: logoPng,
				imagenTicketPng: imagenTicketPng,
			);
			return;
		}
		if (modo == ModoImpresora.red || modo == ModoImpresora.ambos) {
			try {
				await EscPosNetworkPrinter(
					host: hostRed,
					port: puertoRed,
					anchoRolloMm: anchoRolloMm,
				).imprimirTicket(
					contenido,
					logoPng: logoPng,
					imagenTicketPng: imagenTicketPng,
				);
				if (modo == ModoImpresora.red) {
					return;
				}
			} catch (_) {
				if (modo == ModoImpresora.red) {
					rethrow;
				}
			}
		}
		await _escribirArchivo(
			contenido,
			logoPng,
			imagenTicketPng: imagenTicketPng,
		);
	}

	Future<void> _escribirArchivo(
		String contenido,
		Uint8List? logoPng, {
		Uint8List? imagenTicketPng,
	}) async {
		if (imagenTicketPng != null && imagenTicketPng.isNotEmpty) {
			await ArchivoReceiptPrinter(directorio: directorioArchivo)
				.imprimirTicket('', imagenTicketPng: imagenTicketPng);
			return;
		}
		if (escribirTicketArchivo != null) {
			await escribirTicketArchivo!(contenido, logoPng, directorioArchivo);
			return;
		}
		await ArchivoReceiptPrinter(directorio: directorioArchivo)
			.imprimirTicket(contenido, logoPng: logoPng);
	}
}
