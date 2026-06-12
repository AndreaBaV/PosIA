/// Vista de stock de un producto en una tienda especifica.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

/// Combina datos de producto e inventario para consulta admin.
class StockPorTienda {
	/// Crea registro de stock visible en admin.
	///
	/// [productoId] Identificador del producto.
	/// [nombreProducto] Nombre del articulo.
	/// [tiendaId] Tienda del inventario.
	/// [nombreTienda] Nombre visible de sucursal.
	/// [cantidad] Existencia disponible.
	/// [actualizadoEn] Ultima actualizacion conocida.
	/// [stockMinimo] Umbral de alerta de faltante.
	const StockPorTienda({
		required this.productoId,
		required this.nombreProducto,
		required this.tiendaId,
		required this.nombreTienda,
		required this.cantidad,
		required this.actualizadoEn,
		this.stockMinimo = 0.0,
	});

	/// Identificador del producto.
	final String productoId;

	/// Nombre del producto.
	final String nombreProducto;

	/// Identificador de tienda.
	final String tiendaId;

	/// Nombre de la tienda.
	final String nombreTienda;

	/// Cantidad en existencia.
	final double cantidad;

	/// Marca de tiempo de ultima actualizacion.
	final DateTime actualizadoEn;

	/// Cantidad minima antes de alerta.
	final double stockMinimo;

	/// Indica si el stock esta bajo el minimo configurado.
	bool estaBajoMinimo() {
		return stockMinimo > 0.0 && cantidad <= stockMinimo;
	}
}
