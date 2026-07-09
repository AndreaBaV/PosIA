/// Cuenta de usuario con rol y alcance por tienda.
library;

import '../enums/rol_usuario.dart';

/// Usuario del sistema con PIN y permisos.
class Usuario {
	const Usuario({
		required this.id,
		required this.nombre,
		required this.codigo,
		this.pin,
		required this.rol,
		required this.activo,
		this.tiendaId,
		this.rolPersonalizadoId,
	});

	final String id;
	final String nombre;
	final String codigo;

	/// PIN en texto plano solo al crear o cambiar credencial; null al leer de BD.
	final String? pin;
	final RolUsuario rol;
	final bool activo;

	/// Tienda asignada; null solo para administrador global.
	final String? tiendaId;

	/// Rol personalizado opcional con permisos granulares de admin.
	final String? rolPersonalizadoId;

	Usuario copiarCon({
		String? id,
		String? nombre,
		String? codigo,
		String? pin,
		RolUsuario? rol,
		bool? activo,
		String? tiendaId,
		String? rolPersonalizadoId,
		bool limpiarTiendaId = false,
		bool limpiarRolPersonalizado = false,
	}) {
		return Usuario(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			codigo: codigo ?? this.codigo,
			pin: pin ?? this.pin,
			rol: rol ?? this.rol,
			activo: activo ?? this.activo,
			tiendaId: limpiarTiendaId ? null : (tiendaId ?? this.tiendaId),
			rolPersonalizadoId: limpiarRolPersonalizado
				? null
				: (rolPersonalizadoId ?? this.rolPersonalizadoId),
		);
	}
}
