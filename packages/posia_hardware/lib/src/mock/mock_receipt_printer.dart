/// Impresora simulada que acumula tickets en memoria.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'dart:typed_data';

import '../receipt_printer.dart';

/// Guarda tickets impresos para verificacion en pruebas.
class MockReceiptPrinter implements ReceiptPrinter {
	final List<String> _ticketsImpresos = [];

	/// Lista de tickets capturados en memoria.
	///
	/// Retorna copia inmutable de tickets registrados.
	List<String> obtenerTicketsImpresos() {
		return List<String>.unmodifiable(_ticketsImpresos);
	}

	@override
	Future<void> imprimirTicket(
		String contenido, {
		Uint8List? logoPng,
		Uint8List? imagenTicketPng,
	}) async {
		_ticketsImpresos.add(contenido);
	}
}
