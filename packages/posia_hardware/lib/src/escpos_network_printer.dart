/// Impresora termica ESC/POS por red (puerto 9100).
library;

import 'dart:io';
import 'dart:typed_data';

import 'escpos_raster.dart';
import 'receipt_printer.dart';

/// Envia ticket por socket TCP a impresora termica.
class EscPosNetworkPrinter implements ReceiptPrinter {
	EscPosNetworkPrinter({
		required this.host,
		this.port = 9100,
		this.timeout = const Duration(seconds: 5),
		this.anchoRolloMm = 80,
	});

	final String host;
	final int port;
	final Duration timeout;
	final int anchoRolloMm;

	@override
	Future<void> imprimirTicket({
		required Uint8List imagenTicketPng,
	}) async {
		if (host.trim().isEmpty) {
			throw StateError('Host de impresora no configurado');
		}
		final bytes = construirBytesEscPosTicket(
			imagenTicketPng: imagenTicketPng,
			anchoRolloMm: anchoRolloMm,
		);
		final socket = await Socket.connect(host.trim(), port, timeout: timeout);
		try {
			socket.add(bytes);
			await socket.flush();
		} finally {
			await socket.close();
		}
	}
}
