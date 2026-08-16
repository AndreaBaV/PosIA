/// Manifiesto de una version publicable de la app POSIA.
library;

/// Paquete descargable para una plataforma (windows, android, ios).
class PaqueteActualizacionApp {
	const PaqueteActualizacionApp({
		required this.url,
		this.archivo = '',
		this.sha256 = '',
		this.tamanoBytes = 0,
	});

	/// URL absoluta de descarga, o nombre de archivo servido por el hub.
	final String url;

	/// Nombre sugerido al guardar en disco.
	final String archivo;

	/// Huella SHA-256 en hex; vacia si no se verifica.
	final String sha256;

	final int tamanoBytes;

	bool get tieneHuella => sha256.trim().isNotEmpty;

	String get nombreArchivo {
		final limpio = archivo.trim();
		if (limpio.isNotEmpty) {
			return limpio;
		}
		final uri = Uri.tryParse(url);
		final segmento = uri?.pathSegments.isNotEmpty == true
			? uri!.pathSegments.last
			: url;
		return segmento.isEmpty ? 'posia-update' : segmento;
	}

	Map<String, Object?> aJson() => {
		'url': url,
		if (archivo.trim().isNotEmpty) 'archivo': archivo.trim(),
		if (sha256.trim().isNotEmpty) 'sha256': sha256.trim().toLowerCase(),
		if (tamanoBytes > 0) 'tamanoBytes': tamanoBytes,
	};

	factory PaqueteActualizacionApp.desdeJson(Map<String, Object?> json) {
		return PaqueteActualizacionApp(
			url: json['url'] as String? ?? '',
			archivo: json['archivo'] as String? ?? '',
			sha256: (json['sha256'] as String? ?? '').trim().toLowerCase(),
			tamanoBytes: (json['tamanoBytes'] as num?)?.toInt() ?? 0,
		);
	}
}

/// Version publicada en el hub, con paquete opcional para esta plataforma.
class ManifestoActualizacionApp {
	const ManifestoActualizacionApp({
		required this.version,
		this.build = 0,
		this.notas = '',
		this.publicadoEn,
		this.obligatoria = false,
		this.plataforma = '',
		this.paquete,
	});

	/// Nombre semver (ej. 2.0.1).
	final String version;

	/// Numero de build (+N del pubspec). 0 = no informado.
	final int build;

	final String notas;
	final DateTime? publicadoEn;
	final bool obligatoria;
	final String plataforma;
	final PaqueteActualizacionApp? paquete;

	bool get hayPaquete =>
		paquete != null && paquete!.url.trim().isNotEmpty;

	Map<String, Object?> aJson() => {
		'version': version,
		'build': build,
		'notas': notas,
		if (publicadoEn != null) 'publicadoEn': publicadoEn!.toUtc().toIso8601String(),
		'obligatoria': obligatoria,
		if (plataforma.isNotEmpty) 'plataforma': plataforma,
		if (paquete != null) 'paquete': paquete!.aJson(),
	};

	factory ManifestoActualizacionApp.desdeJson(Map<String, Object?> json) {
		final paqueteCrudo = json['paquete'];
		DateTime? publicado;
		final publicadoCrudo = json['publicadoEn'] as String?;
		if (publicadoCrudo != null && publicadoCrudo.trim().isNotEmpty) {
			publicado = DateTime.tryParse(publicadoCrudo)?.toUtc();
		}
		return ManifestoActualizacionApp(
			version: json['version'] as String? ?? '',
			build: (json['build'] as num?)?.toInt() ?? 0,
			notas: json['notas'] as String? ?? '',
			publicadoEn: publicado,
			obligatoria: json['obligatoria'] == true,
			plataforma: json['plataforma'] as String? ?? '',
			paquete: paqueteCrudo is Map<String, Object?>
				? PaqueteActualizacionApp.desdeJson(paqueteCrudo)
				: paqueteCrudo is Map
					? PaqueteActualizacionApp.desdeJson(
						Map<String, Object?>.from(paqueteCrudo),
					)
					: null,
		);
	}
}
