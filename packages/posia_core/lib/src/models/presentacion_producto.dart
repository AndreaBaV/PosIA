/// Tipos y presentaciones comerciales de producto.
library;

/// Catalogo global de tipos de presentacion (caja, bulto 25kg, etc.).
class TipoPresentacion {
	const TipoPresentacion({
		required this.id,
		required this.nombre,
		required this.unidad,
		required this.activo,
	});

	final String id;
	final String nombre;
	final String unidad;
	final bool activo;

	TipoPresentacion copiarWith({
		String? id,
		String? nombre,
		String? unidad,
		bool? activo,
	}) {
		return TipoPresentacion(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			unidad: unidad ?? this.unidad,
			activo: activo ?? this.activo,
		);
	}
}

/// Presentacion concreta de un producto con factor de conversion.
class PresentacionProducto {
	const PresentacionProducto({
		required this.id,
		required this.productoId,
		this.tipoPresentacionId,
		required this.nombre,
		required this.factorABase,
		required this.esPresentacionBase,
		this.codigoBarras = '',
		this.precio,
		required this.activo,
	});

	final String id;
	final String productoId;
	final String? tipoPresentacionId;
	final String nombre;
	final double factorABase;
	final bool esPresentacionBase;
	final String codigoBarras;
	final double? precio;
	final bool activo;

	PresentacionProducto copiarWith({
		String? id,
		String? productoId,
		String? tipoPresentacionId,
		String? nombre,
		double? factorABase,
		bool? esPresentacionBase,
		String? codigoBarras,
		double? precio,
		bool? activo,
	}) {
		return PresentacionProducto(
			id: id ?? this.id,
			productoId: productoId ?? this.productoId,
			tipoPresentacionId: tipoPresentacionId ?? this.tipoPresentacionId,
			nombre: nombre ?? this.nombre,
			factorABase: factorABase ?? this.factorABase,
			esPresentacionBase: esPresentacionBase ?? this.esPresentacionBase,
			codigoBarras: codigoBarras ?? this.codigoBarras,
			precio: precio ?? this.precio,
			activo: activo ?? this.activo,
		);
	}
}
