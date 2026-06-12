/// Resumen comercial de un cliente.
library;

/// Metricas agregadas de compras del cliente.
class ResumenCliente {
	const ResumenCliente({
		required this.clienteId,
		required this.cantidadVentas,
		required this.totalComprado,
		this.ultimaCompraEn,
	});

	final String clienteId;
	final int cantidadVentas;
	final double totalComprado;
	final DateTime? ultimaCompraEn;
}
