/// Linea temporal del carrito activo en caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import '../enums/regla_precio.dart';
import 'producto.dart';

/// Representa un articulo agregado al carrito antes del cobro.
class LineaCarrito {
	/// Crea una linea de carrito.
	///
	/// [producto] Producto agregado.
	/// [cantidad] Cantidad en carrito.
	/// [precioUnitario] Precio unitario resuelto.
	/// [reglaPrecio] Regla que produjo el precio.
	/// [loteId] Identificador de lote farmacia opcional.
	/// [etiquetaLote] Texto visible de lote para ticket.
	const LineaCarrito({
		required this.producto,
		required this.cantidad,
		required this.precioUnitario,
		required this.reglaPrecio,
		this.loteId,
		this.etiquetaLote,
		this.descuentoLinea = 0.0,
		this.factorABase = 1.0,
		this.productoStockId,
	});

	/// Producto en carrito.
	final Producto producto;

	/// Cantidad seleccionada.
	final double cantidad;

	/// Precio unitario aplicado.
	final double precioUnitario;

	/// Regla de precio utilizada.
	final ReglaPrecio reglaPrecio;

	/// Lote farmacia asociado opcionalmente.
	final String? loteId;

	/// Etiqueta de lote para impresion en ticket.
	final String? etiquetaLote;

	/// Descuento absoluto aplicado a la linea (MXN).
	final double descuentoLinea;

	/// Factor de conversion a unidad base de inventario (presentaciones).
	final double factorABase;

	/// Producto padre cuyo stock se descuenta; null usa resolucion automatica.
	final String? productoStockId;

	/// Calcula subtotal de la linea.
	///
	/// Retorna cantidad multiplicada por precio unitario menos descuento.
	double calcularSubtotal() {
		final bruto = cantidad * precioUnitario;
		final neto = bruto - descuentoLinea;
		return neto < 0.0 ? 0.0 : neto;
	}

	/// Genera copia con campos opcionales reemplazados.
	///
	/// Retorna nueva instancia de [LineaCarrito].
	LineaCarrito copiarCon({
		Producto? producto,
		double? cantidad,
		double? precioUnitario,
		ReglaPrecio? reglaPrecio,
		String? loteId,
		String? etiquetaLote,
		double? descuentoLinea,
		double? factorABase,
		String? productoStockId,
	}) {
		return LineaCarrito(
			producto: producto ?? this.producto,
			cantidad: cantidad ?? this.cantidad,
			precioUnitario: precioUnitario ?? this.precioUnitario,
			reglaPrecio: reglaPrecio ?? this.reglaPrecio,
			loteId: loteId ?? this.loteId,
			etiquetaLote: etiquetaLote ?? this.etiquetaLote,
			descuentoLinea: descuentoLinea ?? this.descuentoLinea,
			factorABase: factorABase ?? this.factorABase,
			productoStockId: productoStockId ?? this.productoStockId,
		);
	}
}
