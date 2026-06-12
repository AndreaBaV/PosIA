/// Variante o presentacion de un producto padre.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Presentacion comercial (ej. Coca 600ml vs 2L).
class VarianteProducto {
	/// Crea variante de producto.
	const VarianteProducto({
		required this.id,
		required this.productoPadreId,
		required this.nombre,
		required this.sku,
		required this.codigoBarras,
		required this.precioBase,
		required this.activo,
	});

	/// Identificador unico de la variante.
	final String id;

	/// Producto padre en catalogo.
	final String productoPadreId;

	/// Nombre de la presentacion.
	final String nombre;

	/// SKU interno.
	final String sku;

	/// Codigo de barras de la variante.
	final String codigoBarras;

	/// Precio de la presentacion.
	final double precioBase;

	/// Indica si esta disponible para venta.
	final bool activo;

	/// Genera copia con campos opcionales reemplazados.
	VarianteProducto copiarCon({
		String? id,
		String? productoPadreId,
		String? nombre,
		String? sku,
		String? codigoBarras,
		double? precioBase,
		bool? activo,
	}) {
		return VarianteProducto(
			id: id ?? this.id,
			productoPadreId: productoPadreId ?? this.productoPadreId,
			nombre: nombre ?? this.nombre,
			sku: sku ?? this.sku,
			codigoBarras: codigoBarras ?? this.codigoBarras,
			precioBase: precioBase ?? this.precioBase,
			activo: activo ?? this.activo,
		);
	}
}
