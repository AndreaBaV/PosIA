/// Linea al registrar un pedido nuevo.
library;

/// Producto y cantidad para alta de pedido.
class LineaPedidoSolicitud {
	const LineaPedidoSolicitud({
		required this.productoId,
		required this.cantidad,
		required this.precioUnitario,
	});

	final String productoId;
	final double cantidad;
	final double precioUnitario;
}
