/// Vendedor o cajero que registra ventas.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Personal de venta asignable a cada transaccion.
class Vendedor {
	/// Crea registro de vendedor.
	const Vendedor({
		required this.id,
		required this.nombre,
		required this.codigo,
		required this.activo,
	});

	/// Identificador unico.
	final String id;

	/// Nombre completo del vendedor.
	final String nombre;

	/// Codigo corto para seleccion rapida.
	final String codigo;

	/// Indica si puede vender.
	final bool activo;

	/// Genera copia con campos opcionales reemplazados.
	Vendedor copiarCon({
		String? id,
		String? nombre,
		String? codigo,
		bool? activo,
	}) {
		return Vendedor(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			codigo: codigo ?? this.codigo,
			activo: activo ?? this.activo,
		);
	}
}
