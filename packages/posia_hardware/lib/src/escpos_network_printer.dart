/// Impresora termica ESC/POS por red (puerto 9100).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'escpos_raster.dart';
import 'receipt_printer.dart';

/// Envia ticket por socket TCP a impresora termica.
///
/// Las termicas WiFi fallan de forma intermitente: la impresora esta ocupada
/// con el ticket anterior, el AP suelta el paquete, o la conexion tarda en
/// abrir. Por eso el envio reintenta la fase de conexion/escritura y espera un
/// breve drenado antes de cerrar (cerrar justo tras `flush` trunca el ticket en
/// varios modelos). Una vez que `flush` completa se asume impreso y ya no se
/// reintenta, para no duplicar tickets.
class EscPosNetworkPrinter implements ReceiptPrinter {
	EscPosNetworkPrinter({
		required this.host,
		this.port = 9100,
		this.timeout = const Duration(seconds: 5),
		this.anchoRolloMm = 80,
		this.maxIntentos = 3,
		this.pausaReintento = const Duration(milliseconds: 500),
		this.pausaDrenado = const Duration(milliseconds: 300),
	});

	final String host;
	final int port;
	final Duration timeout;
	final int anchoRolloMm;

	/// Intentos totales de conexion+escritura antes de fallar.
	final int maxIntentos;

	/// Espera entre reintentos (da tiempo a que la impresora libere el socket).
	final Duration pausaReintento;

	/// Espera tras `flush` antes de cerrar, para que la impresora drene el buffer.
	final Duration pausaDrenado;

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
		final destino = host.trim();
		Object? ultimoError;
		for (var intento = 1; intento <= maxIntentos; intento++) {
			Socket? socket;
			try {
				socket = await Socket.connect(destino, port, timeout: timeout);
				socket.add(bytes);
				await socket.flush();
			} on Object catch (error) {
				// Fallo antes de drenar: nada llego a imprimirse, es seguro
				// reintentar sin arriesgar un ticket duplicado.
				ultimoError = error;
				socket?.destroy();
				if (intento < maxIntentos) {
					await Future<void>.delayed(pausaReintento);
				}
				continue;
			}
			// `flush` completo: el ticket ya salio. Cerrar de forma tolerante sin
			// reintentar, para no imprimir dos veces si el cierre falla.
			await Future<void>.delayed(pausaDrenado);
			try {
				await socket.close();
			} on Object {
				socket.destroy();
			}
			return;
		}
		throw StateError(
			'No se pudo imprimir en $destino:$port tras $maxIntentos intentos: '
			'$ultimoError',
		);
	}
}
