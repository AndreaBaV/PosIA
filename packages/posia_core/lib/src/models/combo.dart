/// Combo de precio fijo entre productos distintos.
library;

/// Miembro de un combo: producto y cantidad requerida para completarlo.
class ComboMiembro {
	const ComboMiembro({required this.productoId, this.cantidadRequerida = 1});

	/// Producto (o variante) miembro.
	final String productoId;

	/// Cantidad de este producto necesaria para completar 1 combo.
	final double cantidadRequerida;

	ComboMiembro copiarCon({String? productoId, double? cantidadRequerida}) {
		return ComboMiembro(
			productoId: productoId ?? this.productoId,
			cantidadRequerida: cantidadRequerida ?? this.cantidadRequerida,
		);
	}
}

/// Define un precio fijo total al llevar todos los productos miembro.
///
/// A diferencia de un lote de promoción (mismo precio unitario al sumar
/// cantidad de cualquier miembro), un combo exige al menos
/// [ComboMiembro.cantidadRequerida] de **cada** miembro; cada set completo
/// que quepa en el carrito cobra [precioCombo] en total.
class Combo {
	const Combo({
		required this.id,
		required this.precioCombo,
		this.nombre = '',
		this.activo = true,
		this.miembros = const [],
	});

	/// Identificador interno (UUID).
	final String id;

	/// Nombre descriptivo del combo.
	final String nombre;

	/// Precio fijo total de un set completo del combo.
	final double precioCombo;

	/// Indica si el combo esta activo.
	final bool activo;

	/// Productos miembro con su cantidad requerida.
	final List<ComboMiembro> miembros;

	/// Placeholder creado por integridad FK (sync fuera de orden).
	///
	/// No es un combo de negocio; no debe proyectarse a Neon. Un combo real sin
	/// miembros y con precio cero no tendria sentido comercial.
	bool get esStubFk =>
		nombre.trim() == 'Combo' && precioCombo == 0.0 && miembros.isEmpty;

	Combo copiarCon({
		String? id,
		String? nombre,
		double? precioCombo,
		bool? activo,
		List<ComboMiembro>? miembros,
	}) {
		return Combo(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			precioCombo: precioCombo ?? this.precioCombo,
			activo: activo ?? this.activo,
			miembros: miembros ?? this.miembros,
		);
	}
}
