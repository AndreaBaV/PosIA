/// Rol de cuenta operativa en POSIA.
library;

/// Nivel de acceso administrativo.
enum RolUsuario {
	/// Acceso completo a todas las tiendas y cuentas.
	administrador,

	/// Administra solo su tienda asignada y su personal.
	supervisor,

	/// Solo puede gestionar su propia cuenta.
	empleado,
}
