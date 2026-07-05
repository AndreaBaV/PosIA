/// Contrato de impresora de tickets.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-07-05 09:55:00 (UTC-6)
library;

import 'dart:typed_data';

/// Imprime ticket de venta como PNG rasterizado (ESC/POS o archivo).
abstract class ReceiptPrinter {
	/// Imprime el ticket completo como imagen PNG.
	///
	/// [imagenTicketPng] es obligatorio; ya no se admite texto plano ESC/POS.
	Future<void> imprimirTicket({
		required Uint8List imagenTicketPng,
	});
}
