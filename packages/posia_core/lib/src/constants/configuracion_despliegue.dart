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

	static bool get usaHubEnNube =>
		hubUrl.isNotEmpty && hubApiKey.isNotEmpty;
}
