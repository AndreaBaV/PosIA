/// Modelos de autenticacion contra el hub central.
library;

/// Sucursal devuelta por el hub al iniciar sesion.
class TiendaHub {
	const TiendaHub({
		required this.id,
		required this.nombre,
		required this.direccion,
		required this.activa,
		this.latitud,
		this.longitud,
		this.radioMetrosAsistencia = 150,
	});

	final String id;
	final String nombre;
	final String direccion;
	final bool activa;
	final double? latitud;
	final double? longitud;
	final double radioMetrosAsistencia;
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

/// Estado global de la capa de autenticacion del hub.
enum EstadoAuthHub {
	/// Hub responde y tiene Postgres con usuarios listos.
	disponible,
	/// Hub responde pero no tiene Postgres configurado (503).
	sinPostgres,
	/// Hub responde pero rechaza la clave API (401).
	apiKeyInvalida,
	/// Hub inalcanzable, timeout o error inesperado.
	inalcanzable,
}

/// Resultado tipado de consultar un perfil en el hub.
///
/// Distingue "usuario no existe" (404) de "no pudimos preguntar" (401, 5xx,
/// timeout, red). Evita que un error transitorio se interprete como "usuario
/// no encontrado" en pantalla de inicio de sesion.
class ConsultaPerfilHub {
	const ConsultaPerfilHub._({
		this.perfil,
		this.definitivoNoEncontrado = false,
		this.estado,
		this.codigoHttp,
		this.detalle,
	});

	/// Hub confirma que el usuario existe.
	const ConsultaPerfilHub.encontrado(PerfilUsuarioHub perfil)
		: this._(perfil: perfil, estado: EstadoAuthHub.disponible);

	/// Hub responde 404: usuario definitivamente no existe.
	const ConsultaPerfilHub.noEncontrado()
		: this._(
			definitivoNoEncontrado: true,
			estado: EstadoAuthHub.disponible,
		);

	/// Hub responde pero no pudimos obtener la respuesta (error transitorio o config).
	const ConsultaPerfilHub.errorHub({
		required EstadoAuthHub estado,
		int? codigoHttp,
		String? detalle,
	}) : this._(estado: estado, codigoHttp: codigoHttp, detalle: detalle);

	final PerfilUsuarioHub? perfil;
	final bool definitivoNoEncontrado;
	final EstadoAuthHub? estado;
	final int? codigoHttp;
	final String? detalle;

	bool get exitoso => perfil != null;
	bool get esRespuestaDefinitiva => perfil != null || definitivoNoEncontrado;
}

/// Resultado tipado de intentar iniciar sesion en el hub.
class IntentoLoginHub {
	const IntentoLoginHub._({
		this.login,
		this.credencialesInvalidas = false,
		this.estado,
		this.codigoHttp,
		this.detalle,
	});

	const IntentoLoginHub.exito(RespuestaLoginHub login)
		: this._(login: login, estado: EstadoAuthHub.disponible);

	const IntentoLoginHub.credencialesInvalidas()
		: this._(
			credencialesInvalidas: true,
			estado: EstadoAuthHub.disponible,
		);

	const IntentoLoginHub.errorHub({
		required EstadoAuthHub estado,
		int? codigoHttp,
		String? detalle,
	}) : this._(estado: estado, codigoHttp: codigoHttp, detalle: detalle);

	final RespuestaLoginHub? login;
	final bool credencialesInvalidas;
	final EstadoAuthHub? estado;
	final int? codigoHttp;
	final String? detalle;

	bool get exitoso => login != null;
	bool get esRespuestaDefinitiva => login != null || credencialesInvalidas;
}

/// Usuario completo del hub (incluye hash PIN para replica local).
class UsuarioHub {
	const UsuarioHub({
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
