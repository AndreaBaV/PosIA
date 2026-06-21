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
		this.tiendaId,
	});

	/// Identificador unico.
	final String id;

	/// Nombre completo del vendedor.
	final String nombre;

	/// Codigo corto para seleccion rapida.
	final String codigo;

	/// Indica si puede vender.
	final bool activo;

	/// Tienda asignada; null si aplica a todas las sucursales.
	final String? tiendaId;

	/// Genera copia con campos opcionales reemplazados.
	Vendedor copiarCon({
		String? id,
		String? nombre,
		String? codigo,
		bool? activo,
		String? tiendaId,
		bool limpiarTiendaId = false,
	}) {
		return Vendedor(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			codigo: codigo ?? this.codigo,
			activo: activo ?? this.activo,
			tiendaId: limpiarTiendaId ? null : (tiendaId ?? this.tiendaId),
		);
	}
}
