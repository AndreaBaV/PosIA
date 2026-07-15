/// Categoria personalizable de productos en caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Agrupacion visual de productos en grilla de caja.
class Categoria {
	/// Crea categoria de catalogo.
	const Categoria({
		required this.id,
		required this.nombre,
		required this.icono,
		required this.colorHex,
		required this.orden,
		required this.activa,
	});

	/// Identificador unico.
	final String id;

	/// Nombre visible en chips de caja.
	final String nombre;

	/// Nombre de icono Material (ej. local_drink).
	final String icono;

	/// Color en formato hex (#RRGGBB).
	final String colorHex;

	/// Orden de aparicion en barra de categorias.
	final int orden;

	/// Indica si se muestra en caja.
	final bool activa;

	/// Placeholder creado por integridad FK (sync fuera de orden).
	///
	/// No es una categoría de negocio; no debe proyectarse a Neon.
	bool get esStubFk {
		return nombre.trim() == 'Categoría' &&
				icono == 'shopping_basket' &&
				colorHex == '#4CAF50' &&
				orden == 0;
	}

	/// Genera copia con campos opcionales reemplazados.
	Categoria copiarCon({
		String? id,
		String? nombre,
		String? icono,
		String? colorHex,
		int? orden,
		bool? activa,
	}) {
		return Categoria(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			icono: icono ?? this.icono,
			colorHex: colorHex ?? this.colorHex,
			orden: orden ?? this.orden,
			activa: activa ?? this.activa,
		);
	}
}
