/// Linea solicitada en un traspaso multi-producto.
library;

/// Producto y cantidad a transferir entre tiendas.
class LineaTraspasoSolicitud {
	const LineaTraspasoSolicitud({
		required this.productoId,
		required this.cantidad,
	});

	final String productoId;
	final double cantidad;
}
