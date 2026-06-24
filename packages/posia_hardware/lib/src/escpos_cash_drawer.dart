/// Cajon de dinero conectado via impresora ESC/POS por red.
library;

import 'dart:io';

import 'cash_drawer.dart';

/// Envia pulso de apertura al cajon conectado a impresora termica.
class EscPosCashDrawer implements CashDrawer {
	EscPosCashDrawer({
		required this.host,
		this.port = 9100,
		this.timeout = const Duration(seconds: 5),
	});

	final String host;
	final int port;
	final Duration timeout;

	@override
	Future<void> abrir() async {
		if (host.trim().isEmpty) {
			return;
		}
		final socket = await Socket.connect(host.trim(), port, timeout: timeout);
		try {
			// ESC p m t1 t2 — pulso pin 2
			socket.add([0x1B, 0x70, 0x00, 0x19, 0xFA]);
			await socket.flush();
		} finally {
			await socket.close();
		}
	}
}
