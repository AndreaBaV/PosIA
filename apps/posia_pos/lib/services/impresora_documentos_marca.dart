/// Impresora que delega impresion PNG de documentos de marca.
library;

import 'dart:typed_data';

import 'package:posia_hardware/posia_hardware.dart';

/// Delega en [ImpresoraConfigurable] la impresion raster del ticket.
class ImpresoraDocumentosMarca implements ReceiptPrinter {
	ImpresoraDocumentosMarca({required ImpresoraConfigurable delegado})
		: _delegado = delegado;

	final ImpresoraConfigurable _delegado;

	@override
	Future<void> imprimirTicket({
		required Uint8List imagenTicketPng,
	}) async {
		await _delegado.imprimirTicket(imagenTicketPng: imagenTicketPng);
	}

	/// Construye la impresora configurable para el dispositivo.
	static ImpresoraDocumentosMarca crear({
		required ModoImpresora modo,
		required String hostRed,
		int puertoRed = 9100,
		required String directorioArchivo,
		String nombreImpresoraUsb = '',
		int anchoRolloMm = 80,
		bool permitirRespaldoArchivo = true,
	}) {
		final delegado = ImpresoraConfigurable(
			modo: modo,
			hostRed: hostRed,
			puertoRed: puertoRed,
			directorioArchivo: directorioArchivo,
			nombreImpresoraUsb: nombreImpresoraUsb,
			anchoRolloMm: anchoRolloMm,
			permitirRespaldoArchivo: permitirRespaldoArchivo,
		);
		return ImpresoraDocumentosMarca(delegado: delegado);
	}
}
