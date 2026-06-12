/// Filtros para consulta de historial de ventas.
library;

import '../enums/estado_venta.dart';

/// Parametros de busqueda en historial de ventas.
class FiltroVentas {
	const FiltroVentas({
		required this.tiendaId,
		required this.desde,
		required this.hasta,
		this.vendedorId,
		this.clienteId,
		this.estado,
	});

	final String tiendaId;
	final DateTime desde;
	final DateTime hasta;
	final String? vendedorId;
	final String? clienteId;
	final EstadoVenta? estado;
}
