/// Linea persistida de una venta cerrada.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import '../enums/regla_precio.dart';

/// Detalle de producto vendido en una transaccion.
class LineaVenta {
	/// Crea una linea de venta persistida.
	///
	/// [productoId] Identificador del producto vendido.
	/// [nombreProducto] Nombre capturado al momento de venta.
	/// [cantidad] Cantidad vendida.
	/// [precioUnitario] Precio unitario aplicado.
	/// [reglaPrecio] Regla comercial utilizada.
	/// [loteId] Lote farmacia vendido opcionalmente.
	/// [etiquetaLote] Etiqueta de lote en ticket.
	const LineaVenta({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidad,
		required this.precioUnitario,
		required this.reglaPrecio,
		this.loteId,
		this.etiquetaLote,
		this.descuentoLinea = 0.0,
	});

	/// Identificador del producto.
	final String productoId;

	/// Nombre del producto al momento de venta.
	final String nombreProducto;

	/// Cantidad vendida.
	final double cantidad;

	/// Precio unitario en MXN.
	final double precioUnitario;

	/// Regla de precio aplicada.
	final ReglaPrecio reglaPrecio;

	/// Identificador de lote farmacia.
	final String? loteId;

	/// Etiqueta legible del lote.
	final String? etiquetaLote;

	/// Descuento absoluto en la linea (MXN).
	final double descuentoLinea;

	/// Calcula subtotal de la linea vendida.
	double calcularSubtotal() {
		final bruto = cantidad * precioUnitario;
		final neto = bruto - descuentoLinea;
		return neto < 0.0 ? 0.0 : neto;
	}
}
