/// Linea solicitada al registrar una compra.
library;

/// Producto, cantidad y costo unitario de llegada.
class LineaCompraSolicitud {
	const LineaCompraSolicitud({
		required this.productoId,
		required this.cantidad,
		required this.costoUnitario,
	});

	final String productoId;
	final double cantidad;
	final double costoUnitario;
}
