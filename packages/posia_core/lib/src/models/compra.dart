/// Compra de mercancia a proveedor.
library;

/// Destino fisico de mercancia comprada (almacen o tienda).
enum TipoDestinoCompra {
	almacen,
	tienda,
}

/// Asignacion de cantidad de un producto a una ubicacion.
class AsignacionCompra {
	const AsignacionCompra({
		required this.id,
		required this.productoId,
		required this.destinoTipo,
		required this.destinoId,
		required this.cantidad,
	});

	final String id;
	final String productoId;
	final TipoDestinoCompra destinoTipo;
	final String destinoId;
	final double cantidad;
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

/// Registro de compra a nivel empresa (razon social), con ubicaciones.
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
	/// Tienda legacy opcional; las compras nuevas no la requieren.
	final String? tiendaId;
	final String proveedorId;
	final DateTime fechaCompra;
	final String notas;
	final double total;
	final DateTime creadaEn;
	final String? creadoPor;
	final List<LineaCompra> lineas;
	final List<AsignacionCompra> asignaciones;
}
