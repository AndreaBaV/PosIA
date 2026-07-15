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

/// Resultado de un ping diagnostico a `/v1/health`.
///
/// Sirve para distinguir "la peticion nunca salio del dispositivo" (sin logs
/// en Northflank/Render) de "el hub respondio con un codigo HTTP".
class DiagnosticoConexionHub {
	const DiagnosticoConexionHub({
		required this.url,
		required this.exitoso,
		this.codigoHttp,
		this.detalle,
	});

	factory DiagnosticoConexionHub.ok({
		required String url,
		required int codigoHttp,
	}) {
		return DiagnosticoConexionHub(
			url: url,
			exitoso: true,
			codigoHttp: codigoHttp,
		);
	}

	factory DiagnosticoConexionHub.fallo({
		required String url,
		int? codigoHttp,
		String? detalle,
	}) {
		return DiagnosticoConexionHub(
			url: url,
			exitoso: false,
			codigoHttp: codigoHttp,
			detalle: detalle,
		);
	}

	final String url;
	final bool exitoso;
	final int? codigoHttp;
	final String? detalle;

	/// Host de la URL configurada (para mostrar en UI sin la clave API).
	String get host {
		final host = Uri.tryParse(url)?.host;
		if (host != null && host.isNotEmpty) {
			return host;
		}
		return url;
	}

	/// Texto accionable para tecnico / pantalla de login.
	String get mensajeUsuario {
		if (exitoso) {
			return 'Conexión OK con $host (HTTP $codigoHttp).';
		}
		return resumirErrorConexionHub(detalle, urlBase: url);
	}
}

/// Traduce excepciones de red a un mensaje corto y accionable.
///
/// Si no hay detalle (p. ej. solo un codigo HTTP), reporta al menos el host
/// de destino para verificar que el dispositivo apunta al hub correcto.
String resumirErrorConexionHub(String? detalle, {String? urlBase}) {
	final host = Uri.tryParse(urlBase ?? '')?.host;
	final destino = (host != null && host.isNotEmpty) ? host : (urlBase ?? '');
	final prefijo = destino.isEmpty ? '' : 'Destino: $destino. ';
	if (detalle == null || detalle.trim().isEmpty) {
		return '${prefijo}No hubo respuesta del hub. '
			'Si en Northflank/Render no aparecen logs, la petición no llegó al servidor '
			'(URL, DNS, firewall o red del local).';
	}
	final d = detalle.toLowerCase();
	if (d.contains('timeout') || d.contains('timed out')) {
		return '${prefijo}Tiempo de espera agotado. '
			'El hub puede estar suspendido por inactividad, o la red del dispositivo '
			'bloquea la salida HTTPS. Espera ~1 min y usa "Probar conexión".';
	}
	if (d.contains('failed host lookup') ||
		d.contains('name resolution') ||
		d.contains('nodename nor servname') ||
		d.contains('getaddrinfo')) {
		return '${prefijo}No se pudo resolver el dominio. '
			'Revisa la URL en Configuración técnica y el DNS de la red.';
	}
	if (d.contains('handshake') ||
		d.contains('certificate') ||
		d.contains('ssl') ||
		d.contains('tls') ||
		d.contains('certificate_verify_failed')) {
		return '${prefijo}Error SSL/TLS. Un antivirus o proxy del cliente puede '
			'interceptar HTTPS; prueba otra red o desactiva la inspección HTTPS.';
	}
	if (d.contains('connection refused') ||
		d.contains('connection reset') ||
		d.contains('network is unreachable') ||
		d.contains('software caused connection abort')) {
		return '${prefijo}La conexión fue rechazada o interrumpida. '
			'Revisa firewall del local y que el servicio esté desplegado.';
	}
	final corto = detalle.length > 140 ? '${detalle.substring(0, 140)}…' : detalle;
	return '$prefijo$corto';
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
		this.rolPersonalizadoId,
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
	final String? rolPersonalizadoId;
	final bool activo;
	final String pinCredencial;
	final String creadoEn;
	final String actualizadoEn;
}

/// Rol personalizado replicado desde el hub Postgres.
class RolPersonalizadoHub {
	const RolPersonalizadoHub({
		required this.id,
		required this.nombre,
		this.descripcion = '',
		required this.permisosAdmin,
		this.categoriasPermitidas = const [],
		required this.activo,
		this.tiendaId,
	});

	final String id;
	final String nombre;
	final String descripcion;
	final List<String> permisosAdmin;
	final List<String> categoriasPermitidas;
	final bool activo;
	final String? tiendaId;
}
