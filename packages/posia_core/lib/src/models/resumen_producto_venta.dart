/// Resumen de ventas agrupado por producto.
library;

/// Totales vendidos de un producto en un periodo.
class ResumenProductoVenta {
	const ResumenProductoVenta({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidadVendida,
		required this.totalVendido,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidadVendida;
	final double totalVendido;
}
