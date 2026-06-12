/// Nivel de inventario por tienda y producto.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Representa existencia de un producto en una tienda.
class StockNivel {
	/// Crea registro de stock.
	///
	/// [productoId] Producto inventariado.
	/// [tiendaId] Tienda donde reside el stock.
	/// [cantidad] Cantidad disponible.
	/// [actualizadoEn] Ultima actualizacion conocida.
	/// [stockMinimo] Umbral para alerta de faltante.
	const StockNivel({
		required this.productoId,
		required this.tiendaId,
		required this.cantidad,
		required this.actualizadoEn,
		this.stockMinimo = 0.0,
	});

	/// Identificador del producto.
	final String productoId;

	/// Identificador de tienda.
	final String tiendaId;

	/// Cantidad disponible.
	final double cantidad;

	/// Marca de tiempo de ultima actualizacion.
	final DateTime actualizadoEn;

	/// Cantidad minima antes de alerta de faltante.
	final double stockMinimo;

	/// Indica si el stock esta bajo el minimo configurado.
	bool estaBajoMinimo() {
		return stockMinimo > 0.0 && cantidad <= stockMinimo;
	}

	/// Genera copia con cantidad ajustada.
	///
	/// [nuevaCantidad] Cantidad resultante.
	/// [actualizadoEn] Marca de tiempo del ajuste.
	/// Retorna nuevo [StockNivel].
	StockNivel copiarConCantidad(double nuevaCantidad, DateTime actualizadoEn) {
		return StockNivel(
			productoId: productoId,
			tiendaId: tiendaId,
			cantidad: nuevaCantidad,
			actualizadoEn: actualizadoEn,
			stockMinimo: stockMinimo,
		);
	}
}
