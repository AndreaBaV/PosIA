/// Impresion de tickets y comprobantes de traspaso.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';

Future<void> imprimirDocumentoTraspaso({
	required ReceiptPrinter impresora,
	required String contenido,
}) async {
	await impresora.imprimirTicket(contenido);
}

String construirTicketTraspaso({
	required Traspaso traspaso,
	required String nombreTiendaOrigen,
	required String nombreTiendaDestino,
	String? nombreOperador,
}) {
	return generarTextoTicketTraspaso(
		traspaso: traspaso,
		nombreTiendaOrigen: nombreTiendaOrigen,
		nombreTiendaDestino: nombreTiendaDestino,
		nombreOperador: nombreOperador,
		conLogoImpreso: true,
	);
}

String construirComprobanteTraspaso({
	required Traspaso traspaso,
	required String nombreTiendaOrigen,
	required String nombreTiendaDestino,
	String? nombreOperadorEnvio,
}) {
	return generarTextoComprobanteTraspaso(
		traspaso: traspaso,
		nombreTiendaOrigen: nombreTiendaOrigen,
		nombreTiendaDestino: nombreTiendaDestino,
		nombreOperadorEnvio: nombreOperadorEnvio,
	);
}
