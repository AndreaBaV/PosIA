/// Modelos de autenticacion contra el hub central.
library;

/// Perfil publico de usuario (sin credenciales).
class PerfilUsuarioHub {
	const PerfilUsuarioHub({
		required this.tenantId,
		required this.id,
		required this.nombre,
		required this.codigo,
		required this.rol,
		this.tiendaId,
		required this.activo,
	});

	final String tenantId;
	final String id;
	final String nombre;
	final String codigo;
	final String rol;
	final String? tiendaId;
	final bool activo;
}

/// Resultado de login exitoso con hash de PIN para replica local.
class RespuestaLoginHub {
	const RespuestaLoginHub({
		required this.perfil,
		required this.pinHash,
		required this.pinSalt,
		required this.creadoEn,
		required this.actualizadoEn,
	});

	final PerfilUsuarioHub perfil;
	final String pinHash;
	final String pinSalt;
	final String creadoEn;
	final String actualizadoEn;
}
