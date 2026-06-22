/// Variables de entorno cargadas desde archivo `.env` local.
library;

import 'configuracion_entorno_io.dart'
	if (dart.library.html) 'configuracion_entorno_stub.dart' as env_io;

/// Claves soportadas en `.env` de la app y de plataforma.
abstract final class ClavesEnv {
	static const String hubUrl = 'POSIA_HUB_URL';
	static const String hubApiKey = 'POSIA_HUB_API_KEY';
	static const String databaseUrl = 'DATABASE_URL';
	static const String apiKey = 'API_KEY';
	static const String port = 'PORT';
}

/// Configuracion en memoria tras leer `.env` (desarrollo / CLI).
class ConfiguracionEntorno {
	ConfiguracionEntorno._();

	static final Map<String, String> _valores = {};
	static bool _cargado = false;

	static bool get estaCargado => _cargado;

	static List<String> rutasMonorepo({String? subcarpeta}) =>
		env_io.rutasEnvMonorepo(subcarpeta: subcarpeta);

	/// Carga `.env` una sola vez.
	static Future<void> cargar({Iterable<String>? rutas}) async {
		if (_cargado) {
			return;
		}
		final mapa = await env_io.leerEnvCompleto(rutas ?? rutasMonorepo());
		_valores.addAll(mapa);
		_cargado = true;
	}

	static void reiniciar() {
		_valores.clear();
		_cargado = false;
	}

	static String? obtener(String clave) {
		final valor = _valores[clave];
		if (valor == null || valor.isEmpty) {
			return null;
		}
		return valor;
	}

	static String get hubUrl => obtener(ClavesEnv.hubUrl) ?? '';
	static String get hubApiKey => obtener(ClavesEnv.hubApiKey) ?? '';
	static String? get databaseUrl => obtener(ClavesEnv.databaseUrl);
	static bool get tieneHub =>
		hubUrl.trim().isNotEmpty && hubApiKey.trim().isNotEmpty;
}
