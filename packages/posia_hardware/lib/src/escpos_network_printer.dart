/// Impresora termica ESC/POS por red (puerto 9100).
library;

import 'dart:io';

import 'receipt_printer.dart';

/// Envia ticket por socket TCP a impresora termica.
class EscPosNetworkPrinter implements ReceiptPrinter {
	EscPosNetworkPrinter({
		required this.host,
		this.port = 9100,
		this.timeout = const Duration(seconds: 5),
	});

	final String host;
	final int port;
	final Duration timeout;

	@override
	Future<void> imprimirTicket(String contenido) async {
		if (host.trim().isEmpty) {
			throw StateError('Host de impresora no configurado');
		}
		final socket = await Socket.connect(host.trim(), port, timeout: timeout);
		try {
			final bytes = <int>[0x1B, 0x40];
			bytes.addAll(_codificarTexto(contenido));
			bytes.addAll([0x0A, 0x0A, 0x0A]);
			bytes.addAll([0x1D, 0x56, 0x00]);
			socket.add(bytes);
			await socket.flush();
		} finally {
			await socket.close();
		}
	}

	List<int> _codificarTexto(String texto) {
		return texto.codeUnits;
	}
}
