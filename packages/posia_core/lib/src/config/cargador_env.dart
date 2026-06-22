/// Lectura de archivos `.env` (clave=valor).
library;

import 'dart:io';

/// Carga variables desde uno o mas archivos `.env`.
class CargadorEnv {
	const CargadorEnv._();

	static Future<Map<String, String>> cargarArchivos(
		Iterable<String> rutas,
	) async {
		final valores = <String, String>{};
		for (final ruta in rutas) {
			final archivo = File(ruta);
			if (!await archivo.exists()) {
				continue;
			}
			for (final linea in await archivo.readAsLines()) {
				final entrada = _parsearLinea(linea);
				if (entrada != null) {
					valores.putIfAbsent(entrada.$1, () => entrada.$2);
				}
			}
		}
		return valores;
	}

	static Future<Map<String, String>> cargar({
		Iterable<String>? rutasArchivo,
	}) async {
		final valores = Map<String, String>.from(Platform.environment);
		final rutas = rutasArchivo ?? const [];
		final desdeArchivo = await cargarArchivos(rutas);
		for (final entrada in desdeArchivo.entries) {
			valores.putIfAbsent(entrada.key, () => entrada.value);
		}
		return valores;
	}

	static (String, String)? _parsearLinea(String linea) {
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
}
