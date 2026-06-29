/// Motivos de fallo en autenticacion multi-tenant.
library;

import 'package:posia_core/posia_core.dart';

import 'resultado_autenticacion.dart';

/// Resultado de buscar perfil por codigo (sin PIN).
class BusquedaPerfilAuth {
	const BusquedaPerfilAuth.usuario(this.usuario)
		: motivoFallo = null;

	const BusquedaPerfilAuth.fallo(this.motivoFallo) : usuario = null;

	final Usuario? usuario;
	final MotivoFalloAuth? motivoFallo;

	bool get exitoso => usuario != null;
}

/// Resultado de intento de login con PIN.
class IntentoAutenticacionAuth {
	const IntentoAutenticacionAuth.exito(this.resultado)
		: motivoFallo = null;

	const IntentoAutenticacionAuth.fallo(this.motivoFallo) : resultado = null;

	final ResultadoAutenticacion? resultado;
	final MotivoFalloAuth? motivoFallo;

	bool get exitoso => resultado != null;
}

/// Causa legible para mostrar en UI.
enum MotivoFalloAuth {
	hubNoConfigurado,
	hubNoDisponible,
	hubSinPostgres,
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
				return 'No se pudo contactar el servidor. Verifique la URL del hub y la API key '
					'en Configuración técnica, o espere ~1 min si el servidor gratuito estaba dormido.';
			case MotivoFalloAuth.hubSinPostgres:
				return 'El servidor hub no tiene base de datos configurada. '
					'Defina DATABASE_URL (Neon) en el despliegue del backend.';
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
