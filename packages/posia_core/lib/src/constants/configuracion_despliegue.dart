/// Parametros del hub SaaS: `.env` local o `--dart-define` en release.
library;

import '../config/configuracion_entorno.dart';

/// URL y clave del hub embebidos en release (un despliegue por repo/tienda).
///
/// Usuarios y PIN viven en Neon; créalos con SQL manual, no en el build.
abstract final class ConfiguracionDespliegue {
	static const String _hubUrlBuild = String.fromEnvironment(
		'POSIA_HUB_URL',
		defaultValue: '',
	);

	static const String _hubApiKeyBuild = String.fromEnvironment(
		'POSIA_HUB_API_KEY',
		defaultValue: '',
	);

	/// Base de la tienda en linea (Cloudflare Pages), para /v1/admin/imagenes.
	/// Reusa la misma clave que el hub (POSIA_HUB_API_KEY) para autenticarse
	/// ahi: no hace falta que el build cargue un secreto mas.
	static const String _tiendaUrlBuild = String.fromEnvironment(
		'POSIA_TIENDA_URL',
		defaultValue: '',
	);

	static const bool _limpiarCacheLocalBuild = bool.fromEnvironment(
		'POSIA_LIMPIAR_CACHE_LOCAL',
		defaultValue: false,
	);

	static const String _buildIdBuild = String.fromEnvironment(
		'POSIA_BUILD_ID',
		defaultValue: '',
	);

	static String get hubUrl {
		final desdeEnv = ConfiguracionEntorno.hubUrl.trim();
		if (desdeEnv.isNotEmpty) {
			return desdeEnv;
		}
		return _hubUrlBuild.trim();
	}

	static String get hubApiKey {
		final desdeEnv = ConfiguracionEntorno.hubApiKey.trim();
		if (desdeEnv.isNotEmpty) {
			return desdeEnv;
		}
		return _hubApiKeyBuild.trim();
	}

	static String get tiendaUrl {
		final desdeEnv = ConfiguracionEntorno.tiendaUrl.trim();
		if (desdeEnv.isNotEmpty) {
			return desdeEnv;
		}
		return _tiendaUrlBuild.trim();
	}

	static bool get usaHubEnNube =>
		hubUrl.isNotEmpty && hubApiKey.isNotEmpty;

	/// true si hay tienda en linea configurada para subir fotos de producto.
	static bool get tieneSubidaImagenes =>
		tiendaUrl.isNotEmpty && hubApiKey.isNotEmpty;

	/// Si es true, borra SQLite local al primer arranque de cada [buildId].
	static bool get limpiarCacheLocal {
		final desdeEnv = ConfiguracionEntorno.obtener(ClavesEnv.limpiarCacheLocal);
		if (desdeEnv != null) {
			return _esVerdadero(desdeEnv);
		}
		return _limpiarCacheLocalBuild;
	}

	/// Identificador del build (p. ej. `1.1.2+35`) para no repetir la limpieza.
	static String get buildId {
		final desdeEnv = ConfiguracionEntorno.obtener(ClavesEnv.buildId)?.trim();
		if (desdeEnv != null && desdeEnv.isNotEmpty) {
			return desdeEnv;
		}
		return _buildIdBuild.trim();
	}

	static bool _esVerdadero(String valor) {
		switch (valor.trim().toLowerCase()) {
			case '1':
			case 'true':
			case 'yes':
			case 'si':
				return true;
			default:
				return false;
		}
	}
}
