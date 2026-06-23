/// Ticket de venta apartado temporalmente en caja.
library;

import 'linea_ticket_espera.dart';

/// Carrito guardado para retomarlo despues.
class TicketEnEspera {
	const TicketEnEspera({
		required this.id,
		required this.tiendaId,
		required this.cajaId,
		required this.total,
		required this.descuentoTicket,
		required this.creadoEn,
		required this.lineas,
		this.clienteId,
		this.nombreCliente,
		this.vendedorId,
		this.notas = '',
	});

	final String id;
	final String tiendaId;
	final String cajaId;
	final String? clienteId;
	final String? nombreCliente;
	final String? vendedorId;
	final String notas;
	final double descuentoTicket;
	final double total;
	final DateTime creadoEn;
	final List<LineaTicketEspera> lineas;

	int get cantidadLineas => lineas.length;

	/// Texto principal en listados de tickets apartados.
	String get etiquetaLista {
		if (notas.trim().isNotEmpty) {
			return notas.trim();
		}
		if (nombreCliente != null && nombreCliente!.trim().isNotEmpty) {
			return nombreCliente!.trim();
		}
		return 'Mostrador';
	}
}
