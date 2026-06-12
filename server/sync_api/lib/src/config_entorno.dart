/// Lectura de variables de entorno y archivo `.env` local.
library;

import 'dart:io';

/// Configuracion del hub de sincronizacion.
class ConfigEntorno {
	ConfigEntorno._(this._valores);

	final Map<String, String> _valores;

	/// Carga variables del proceso y opcionalmente archivo `.env`.
	static Future<ConfigEntorno> cargar({String? rutaEnv}) async {
		final valores = Map<String, String>.from(Platform.environment);
		final archivo = File(rutaEnv ?? '.env');
		if (await archivo.exists()) {
			for (final linea in await archivo.readAsLines()) {
				final entrada = _parsearLineaEnv(linea);
				if (entrada != null) {
					valores.putIfAbsent(entrada.$1, () => entrada.$2);
				}
			}
		}
		return ConfigEntorno._(valores);
	}

	static (String, String)? _parsearLineaEnv(String linea) {
		final texto = linea.trim();
		if (texto.isEmpty || texto.startsWith('#')) {
			return null;
		}
		final separador = texto.indexOf('=');
		if (separador <= 0) {
			return null;
		}
		final clave = texto.substring(0, separador).trim();
		var valor = texto.substring(separador + 1).trim();
		if (valor.startsWith('"') && valor.endsWith('"') && valor.length >= 2) {
			valor = valor.substring(1, valor.length - 1);
		}
		return (clave, valor);
	}

	/// Obtiene variable o null si no existe.
	String? obtener(String clave) {
		final valor = _valores[clave];
		if (valor == null || valor.isEmpty) {
			return null;
		}
		return valor;
	}

	/// Puerto HTTP del hub; default 8080.
	int get puerto => int.tryParse(obtener('PORT') ?? '') ?? 8080;

	/// URL Postgres (Neon); null = modo archivo local.
	String? get urlBaseDatos => obtener('DATABASE_URL');

	/// Clave API compartida con las cajas.
	String? get claveApi => obtener('API_KEY');

	/// Ruta JSONL cuando no hay Postgres.
	String get rutaArchivoEventos => obtener('EVENTS_FILE') ?? 'posia_sync_events.jsonl';
}
