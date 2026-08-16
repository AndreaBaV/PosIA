/// Catalogo de paquetes de actualizacion de la app, leido de JSON local.
library;

import 'dart:convert';
import 'dart:io';

import 'package:posia_core/posia_core.dart';

import 'config_entorno.dart';

/// Manifiesto y archivos opcionales servidos por el hub.
class CatalogoActualizacionesApp {
	CatalogoActualizacionesApp({
		Map<String, Object?>? manifiesto,
		this.directorioArchivos,
	}) : _manifiesto = manifiesto;

	final Map<String, Object?>? _manifiesto;
	final Directory? directorioArchivos;

	bool get estaConfigurado => _manifiesto != null;

	/// Carga JSON embebido, archivo o el `app_update.json` junto al proceso.
	static Future<CatalogoActualizacionesApp> desdeConfig(
		ConfigEntorno config,
	) async {
		Map<String, Object?>? manifiesto;
		final jsonInline = config.obtener('POSIA_APP_UPDATE_JSON');
		if (jsonInline != null && jsonInline.trim().isNotEmpty) {
			manifiesto = _parsearJson(jsonInline);
		} else {
			final ruta =
				config.obtener('POSIA_APP_UPDATE_MANIFEST') ?? 'app_update.json';
			final archivo = File(ruta);
			if (await archivo.exists()) {
				manifiesto = _parsearJson(await archivo.readAsString());
			}
		}
		Directory? dir;
		final rutaDir = config.obtener('POSIA_APP_UPDATE_DIR');
		if (rutaDir != null && rutaDir.trim().isNotEmpty) {
			dir = Directory(rutaDir.trim());
		}
		return CatalogoActualizacionesApp(
			manifiesto: manifiesto,
			directorioArchivos: dir,
		);
	}

	static Map<String, Object?>? _parsearJson(String texto) {
		final decodificado = jsonDecode(texto);
		if (decodificado is Map<String, Object?>) {
			return decodificado;
		}
		if (decodificado is Map) {
			return Map<String, Object?>.from(decodificado);
		}
		return null;
	}

	/// Resuelve el manifiesto para [plataforma] (`windows`, `android`, `ios`).
	ManifestoActualizacionApp? paraPlataforma({
		required String plataforma,
		required String origenPublico,
	}) {
		final crudo = _manifiesto;
		if (crudo == null) {
			return null;
		}
		final version = crudo['version'] as String? ?? '';
		if (version.trim().isEmpty) {
			return null;
		}
		final plataformas = crudo['plataformas'];
		Map<String, Object?>? paqueteCrudo;
		if (plataformas is Map) {
			final entrada = plataformas[plataforma] ?? plataformas[plataforma.toLowerCase()];
			if (entrada is Map) {
				paqueteCrudo = Map<String, Object?>.from(entrada);
			}
		}
		PaqueteActualizacionApp? paquete;
		if (paqueteCrudo != null) {
			paquete = _resolverPaquete(paqueteCrudo, origenPublico);
		}
		DateTime? publicado;
		final publicadoCrudo = crudo['publicadoEn'] as String?;
		if (publicadoCrudo != null && publicadoCrudo.trim().isNotEmpty) {
			publicado = DateTime.tryParse(publicadoCrudo)?.toUtc();
		}
		return ManifestoActualizacionApp(
			version: version.trim(),
			build: (crudo['build'] as num?)?.toInt() ?? 0,
			notas: crudo['notas'] as String? ?? '',
			publicadoEn: publicado,
			obligatoria: crudo['obligatoria'] == true,
			plataforma: plataforma,
			paquete: paquete,
		);
	}

	PaqueteActualizacionApp _resolverPaquete(
		Map<String, Object?> crudo,
		String origenPublico,
	) {
		final archivo = (crudo['archivo'] as String? ?? '').trim();
		var url = (crudo['url'] as String? ?? '').trim();
		if (url.isEmpty && archivo.isNotEmpty) {
			url = '$origenPublico/v1/app/files/${Uri.encodeComponent(archivo)}';
		}
		return PaqueteActualizacionApp(
			url: url,
			archivo: archivo,
			sha256: (crudo['sha256'] as String? ?? '').trim().toLowerCase(),
			tamanoBytes: (crudo['tamanoBytes'] as num?)?.toInt() ?? 0,
		);
	}

	/// Archivo local permitido por el manifiesto; null si no existe o es ajeno.
	File? archivoLocal(String nombre) {
		final dir = directorioArchivos;
		if (dir == null || nombre.trim().isEmpty) {
			return null;
		}
		if (nombre.contains('/') ||
			nombre.contains('\\') ||
			nombre.contains('..')) {
			return null;
		}
		if (!_nombrePermitido(nombre)) {
			return null;
		}
		final archivo = File('${dir.path}${Platform.pathSeparator}$nombre');
		if (!archivo.existsSync()) {
			return null;
		}
		return archivo;
	}

	bool _nombrePermitido(String nombre) {
		final plataformas = _manifiesto?['plataformas'];
		if (plataformas is! Map) {
			return false;
		}
		for (final entrada in plataformas.values) {
			if (entrada is! Map) {
				continue;
			}
			final archivo = (entrada['archivo'] as String? ?? '').trim();
			if (archivo == nombre) {
				return true;
			}
		}
		return false;
	}
}
