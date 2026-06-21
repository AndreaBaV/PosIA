/// Filtros para consulta de historial de ventas.
library;

import '../enums/estado_venta.dart';

/// Parametros de busqueda en historial de ventas.
class FiltroVentas {
	const FiltroVentas({
		this.tiendaId,
		required this.desde,
		required this.hasta,
		this.vendedorId,
		this.clienteId,
		this.estado,
	});

	/// Si es null, incluye todas las tiendas.
	final String? tiendaId;
	final DateTime desde;
	final DateTime hasta;
	final String? vendedorId;
	final String? clienteId;
	final EstadoVenta? estado;
}
