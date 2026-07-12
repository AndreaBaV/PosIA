/// Compra de mercancia a proveedor.
library;

/// Destino de inventario tras una compra (tienda o almacen).
class AsignacionInventarioCompra {
	const AsignacionInventarioCompra({
		required this.productoId,
		required this.destinoTipo,
		required this.destinoId,
		required this.cantidad,
	});

	/// `tienda` o `almacen`.
	final String destinoTipo;
	final String productoId;
	final String destinoId;
	final double cantidad;

	static const destinoTienda = 'tienda';
	static const destinoAlmacen = 'almacen';

	bool get esTienda => destinoTipo == destinoTienda;

	bool get esAlmacen => destinoTipo == destinoAlmacen;
}

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
///
/// Las compras son a nivel empresa (misma razon social). El inventario se
/// distribuye mediante [asignaciones] hacia tiendas o almacenes.
class Compra {
	const Compra({
		required this.id,
		required this.proveedorId,
		required this.fechaCompra,
		required this.notas,
		required this.total,
		required this.creadaEn,
		required this.lineas,
		this.tiendaId,
		this.creadoPor,
		this.asignaciones = const [],
	});

	final String id;
	/// Legacy: compras antiguas por tienda. Nuevas compras usan [asignaciones].
	final String? tiendaId;
	final String proveedorId;
	final DateTime fechaCompra;
	final String notas;
	final double total;
	final DateTime creadaEn;
	final String? creadoPor;
	final List<LineaCompra> lineas;
	final List<AsignacionInventarioCompra> asignaciones;
}
