/// Modelos de autenticacion contra el hub central.
library;

/// Sucursal devuelta por el hub al iniciar sesion.
class TiendaHub {
	const TiendaHub({
		required this.id,
		required this.nombre,
		required this.direccion,
		required this.activa,
	});

	final String id;
	final String nombre;
	final String direccion;
	final bool activa;
}

/// Perfil publico de usuario (sin credenciales).
class PerfilUsuarioHub {
	const PerfilUsuarioHub({
		required this.id,
		required this.nombre,
		required this.codigo,
		required this.rol,
		this.tiendaId,
		required this.activo,
	});

	final String id;
	final String nombre;
	final String codigo;
	final String rol;
	final String? tiendaId;
	final bool activo;
}

/// Resultado de login exitoso con credencial PIN para replica local.
class RespuestaLoginHub {
	const RespuestaLoginHub({
		required this.perfil,
		required this.pinCredencial,
		required this.creadoEn,
		required this.actualizadoEn,
		this.tiendas = const [],
	});

	final PerfilUsuarioHub perfil;
	final String pinCredencial;
	final String creadoEn;
	final String actualizadoEn;
	final List<TiendaHub> tiendas;
}

/// Usuario completo del hub para replicar en SQLite local.
class UsuarioReplicaHub {
	const UsuarioReplicaHub({
		required this.id,
		required this.nombre,
		required this.codigo,
		required this.rol,
		this.tiendaId,
		required this.activo,
		required this.pinCredencial,
		required this.creadoEn,
		required this.actualizadoEn,
	});

	final String id;
	final String nombre;
	final String codigo;
	final String rol;
	final String? tiendaId;
	final bool activo;
	final String pinCredencial;
	final String creadoEn;
	final String actualizadoEn;
}
