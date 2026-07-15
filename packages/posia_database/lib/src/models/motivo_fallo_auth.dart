/// Motivos de fallo en autenticacion multi-tenant.
library;

import 'package:posia_core/posia_core.dart';

import 'resultado_autenticacion.dart';

/// Resultado de buscar perfil por codigo (sin PIN).
class BusquedaPerfilAuth {
	const BusquedaPerfilAuth.usuario(this.usuario)
		: motivoFallo = null,
			detalleTecnico = null;

	const BusquedaPerfilAuth.fallo(
		this.motivoFallo, {
		this.detalleTecnico,
	}) : usuario = null;

	final Usuario? usuario;
	final MotivoFalloAuth? motivoFallo;

	/// Detalle de red/HTTP para el tecnico (no sustituye [motivoFallo]).
	final String? detalleTecnico;

	bool get exitoso => usuario != null;

	/// Mensaje para UI: motivo legible + pista tecnica si existe.
	String get mensajeUsuario {
		final base = motivoFallo?.mensajeUsuario ?? 'Usuario no encontrado';
		final detalle = detalleTecnico?.trim();
		if (detalle == null || detalle.isEmpty) {
			return base;
		}
		return '$base\n$detalle';
	}
}

/// Resultado de intento de login con PIN.
class IntentoAutenticacionAuth {
	const IntentoAutenticacionAuth.exito(this.resultado)
		: motivoFallo = null,
			detalleTecnico = null;

	const IntentoAutenticacionAuth.fallo(
		this.motivoFallo, {
		this.detalleTecnico,
	}) : resultado = null;

	final ResultadoAutenticacion? resultado;
	final MotivoFalloAuth? motivoFallo;
	final String? detalleTecnico;

	bool get exitoso => resultado != null;

	String get mensajeUsuario {
		final base = motivoFallo?.mensajeUsuario ?? 'Contraseña incorrecta';
		final detalle = detalleTecnico?.trim();
		if (detalle == null || detalle.isEmpty) {
			return base;
		}
		return '$base\n$detalle';
	}
}

/// Causa legible para mostrar en UI.
enum MotivoFalloAuth {
	hubNoConfigurado,
	hubNoDisponible,
	hubSinPostgres,
	hubApiKeyInvalida,
	usuarioNoEncontrado,
	credencialesInvalidas,
	usuarioInactivo,
	sinSesionPreviaOffline,
}

extension MensajeMotivoFalloAuth on MotivoFalloAuth {
	String get mensajeUsuario {
		switch (this) {
			case MotivoFalloAuth.hubNoConfigurado:
				return 'Sin conexión al servidor. Configure el hub en Configuración técnica.';
			case MotivoFalloAuth.hubNoDisponible:
				return 'No se pudo contactar el servidor. Reintenta en unos segundos; '
					'si persiste, verifica la URL del hub y tu conexión a internet '
					'en Configuración técnica (botón Probar conexión). '
					'Nota: otra máquina puede seguir entrando con datos locales '
					'sin llegar al servidor.';
			case MotivoFalloAuth.hubSinPostgres:
				return 'El servidor hub no tiene base de datos configurada. '
					'Defina DATABASE_URL (Neon) en el despliegue del backend.';
			case MotivoFalloAuth.hubApiKeyInvalida:
				return 'El servidor rechazó la clave API de este dispositivo. '
					'Actualiza la API Key en Configuración técnica y vuelve a intentar.';
			case MotivoFalloAuth.usuarioNoEncontrado:
				return 'Usuario no encontrado';
			case MotivoFalloAuth.credencialesInvalidas:
				return 'Contraseña incorrecta';
			case MotivoFalloAuth.usuarioInactivo:
				return 'Usuario desactivado. Contacte al administrador.';
			case MotivoFalloAuth.sinSesionPreviaOffline:
				return 'Sin conexión y sin datos locales. Inicie sesión en línea al menos una vez.';
		}
	}
}
