/// Impresora que antepone el logo de La Fortuna en tickets y documentos.
library;

import 'dart:typed_data';

import 'package:posia_hardware/posia_hardware.dart';

import '../util/generador_documento_marca_pdf.dart';
import '../util/marca_la_fortuna.dart';

/// Delega en [ImpresoraConfigurable] e inyecta logo de marca en cada impresion.
class ImpresoraDocumentosMarca implements ReceiptPrinter {
	ImpresoraDocumentosMarca({required ImpresoraConfigurable delegado})
		: _delegado = delegado;

	final ImpresoraConfigurable _delegado;

	@override
	Future<void> imprimirTicket(
		String contenido, {
		Uint8List? logoPng,
		Uint8List? imagenTicketPng,
	}) async {
		if (imagenTicketPng != null && imagenTicketPng.isNotEmpty) {
			await _delegado.imprimirTicket(
				contenido,
				imagenTicketPng: imagenTicketPng,
			);
			return;
		}
		final logo = logoPng ?? await cargarLogoTicketMarca();
		await _delegado.imprimirTicket(contenido, logoPng: logo);
	}

	/// Construye la impresora configurable con respaldo PDF para modo archivo.
	static ImpresoraDocumentosMarca crear({
		required ModoImpresora modo,
		required String hostRed,
		int puertoRed = 9100,
		required String directorioArchivo,
		String nombreImpresoraUsb = '',
		int anchoRolloMm = 80,
	}) {
		final delegado = ImpresoraConfigurable(
			modo: modo,
			hostRed: hostRed,
			puertoRed: puertoRed,
			directorioArchivo: directorioArchivo,
			nombreImpresoraUsb: nombreImpresoraUsb,
			anchoRolloMm: anchoRolloMm,
			escribirTicketArchivo: escribirTicketArchivoConMarca,
		);
		return ImpresoraDocumentosMarca(delegado: delegado);
	}
}
