/// Impresora simulada que acumula tickets en memoria.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-07-05 09:55:00 (UTC-6)
library;

import 'dart:typed_data';

import '../receipt_printer.dart';

/// Guarda tickets impresos para verificacion en pruebas.
class MockReceiptPrinter implements ReceiptPrinter {
	final List<Uint8List> _ticketsImpresos = [];

	/// Lista de PNG capturados en memoria.
	List<Uint8List> obtenerTicketsImpresos() {
		return List<Uint8List>.unmodifiable(_ticketsImpresos);
	}

	@override
	Future<void> imprimirTicket({
		required Uint8List imagenTicketPng,
	}) async {
		_ticketsImpresos.add(Uint8List.fromList(imagenTicketPng));
	}
}
