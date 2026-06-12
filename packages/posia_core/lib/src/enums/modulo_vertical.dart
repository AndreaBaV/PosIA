/// Vertical comercial de un producto en catalogo POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

/// Clasifica productos segun modulo vertical activo.
enum ModuloVertical {
	/// Producto estandar de abarrotes o mostrador general.
	general,

	/// Producto vendido por peso en carniceria.
	carniceria,

	/// Producto con control de lote y caducidad en farmacia.
	farmacia,
}
