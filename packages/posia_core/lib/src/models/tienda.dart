/// Modelo inmutable de tienda o sucursal.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Representa una sucursal fisica del negocio.
class Tienda {
	/// Crea una instancia de tienda.
	///
	/// [id] Identificador unico de la tienda.
	/// [nombre] Nombre comercial de la sucursal.
	/// [direccion] Direccion textual opcional.
	/// [activa] Indica si la tienda opera comercialmente.
	const Tienda({
		required this.id,
		required this.nombre,
		required this.direccion,
		required this.activa,
		this.latitud,
		this.longitud,
		this.radioMetrosAsistencia = 150,
	});

	/// Identificador unico de la tienda.
	final String id;

	/// Nombre visible de la sucursal.
	final String nombre;

	/// Direccion de la tienda.
	final String direccion;

	/// Estado operativo de la sucursal.
	final bool activa;

	/// Latitud para geocerca de asistencia.
	final double? latitud;

	/// Longitud para geocerca de asistencia.
	final double? longitud;

	/// Radio en metros para validar entrada de empleados.
	final double radioMetrosAsistencia;
}
