/// Parametros del hub SaaS: `.env` local o `--dart-define` en release.
///
/// El tenant **no** va en el build: se resuelve al iniciar sesion.
library;

import '../config/configuracion_entorno.dart';

/// URL y clave del hub compartido por todos los tenants.
abstract final class ConfiguracionDespliegue {
	static const String _hubUrlBuild = String.fromEnvironment(
		'POSIA_HUB_URL',
		defaultValue: '',
	);

	static const String _hubApiKeyBuild = String.fromEnvironment(
		'POSIA_HUB_API_KEY',
		defaultValue: '',
	);

	/// URL efectiva: `.env` tiene prioridad sobre el valor del build.
	static String get hubUrl {
		final desdeEnv = ConfiguracionEntorno.hubUrl.trim();
		if (desdeEnv.isNotEmpty) {
			return desdeEnv;
		}
		return _hubUrlBuild.trim();
	}

	/// Clave API efectiva: `.env` tiene prioridad sobre el build.
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
