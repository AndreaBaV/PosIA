/// Linea de detalle de un pedido.
library;

import '../utils/moneda_util.dart';

/// Producto y cantidad solicitados en un pedido.
class LineaPedido {
	const LineaPedido({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidad,
		required this.precioUnitario,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidad;
	final double precioUnitario;

	double get subtotal => redondearMonto(cantidad * precioUnitario);
}
