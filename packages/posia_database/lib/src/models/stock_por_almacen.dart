/// Vista de stock de un producto en un almacén específico.
library;

/// Combina datos de producto e inventario en almacén para consulta admin.
class StockPorAlmacen {
	const StockPorAlmacen({
		required this.productoId,
		required this.nombreProducto,
		required this.almacenId,
		required this.nombreAlmacen,
		required this.cantidad,
		required this.actualizadoEn,
		this.stockMinimo = 0.0,
	});

	final String productoId;
	final String nombreProducto;
	final String almacenId;
	final String nombreAlmacen;
	final double cantidad;
	final DateTime actualizadoEn;
	final double stockMinimo;

	bool estaBajoMinimo() => stockMinimo > 0.0 && cantidad <= stockMinimo;
}

/// Resumen de existencias en un almacén.
class ResumenStockAlmacen {
	const ResumenStockAlmacen({
		required this.almacenId,
		required this.nombreAlmacen,
		required this.productosConStock,
		required this.totalUnidades,
	});

	final String almacenId;
	final String nombreAlmacen;
	final int productosConStock;
	final double totalUnidades;
}
