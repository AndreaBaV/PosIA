/// Compra de mercancia a proveedor.
library;

/// Linea de producto en una compra.
class LineaCompra {
	const LineaCompra({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidad,
		required this.costoUnitario,
		required this.subtotal,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidad;
	final double costoUnitario;
	final double subtotal;
}

/// Registro de compra con proveedor, fecha y detalle.
class Compra {
	const Compra({
		required this.id,
		required this.tiendaId,
		required this.proveedorId,
		required this.fechaCompra,
		required this.notas,
		required this.total,
		required this.creadaEn,
		required this.lineas,
		this.creadoPor,
	});

	final String id;
	final String tiendaId;
	final String proveedorId;
	final DateTime fechaCompra;
	final String notas;
	final double total;
	final DateTime creadaEn;
	final String? creadoPor;
	final List<LineaCompra> lineas;
}
