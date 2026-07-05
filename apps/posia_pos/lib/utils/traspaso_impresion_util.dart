/// Impresion y comparticion de tickets de traspaso.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';

import 'imprimir_ticket_digital_util.dart';

/// Imprime ticket o comprobante de traspaso como PNG completo.
Future<void> imprimirDocumentoTraspaso({
	required ReceiptPrinter impresora,
	required TicketDigitalContenido contenido,
	int anchoRolloMm = 80,
}) async {
	await imprimirTicketDigital(
		impresora: impresora,
		contenido: contenido,
		anchoRolloMm: anchoRolloMm,
	);
}

TicketDigitalContenido construirTicketDigitalTraspasoImpresion({
	required Traspaso traspaso,
	required String nombreTiendaOrigen,
	required String nombreTiendaDestino,
	String? nombreOperador,
	String? direccionTienda,
}) {
	return construirTicketDigitalTraspaso(
		traspaso: traspaso,
		nombreTiendaOrigen: nombreTiendaOrigen,
		nombreTiendaDestino: nombreTiendaDestino,
		nombreOperador: nombreOperador,
		direccionTienda: direccionTienda,
	);
}

TicketDigitalContenido construirTicketDigitalComprobanteTraspasoImpresion({
	required Traspaso traspaso,
	required String nombreTiendaOrigen,
	required String nombreTiendaDestino,
	String? nombreOperadorEnvio,
	String? direccionTienda,
}) {
	return construirTicketDigitalComprobanteTraspaso(
		traspaso: traspaso,
		nombreTiendaOrigen: nombreTiendaOrigen,
		nombreTiendaDestino: nombreTiendaDestino,
		nombreOperadorEnvio: nombreOperadorEnvio,
		direccionTienda: direccionTienda,
	);
}
