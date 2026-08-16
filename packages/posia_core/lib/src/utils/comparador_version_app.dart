/// Comparacion de versiones de la app (semver + numero de build).
library;

import '../models/actualizacion_app.dart';

/// Version instalada o publicada.
class VersionApp {
	const VersionApp({required this.nombre, this.build = 0});

	/// `2.0.0` (parte izquierda de `version:` en pubspec).
	final String nombre;

	/// `150` (parte `+N` de pubspec). 0 = desconocido.
	final int build;

	factory VersionApp.desdeEtiqueta(String version, {String? buildNumber}) {
		final limpia = version.trim();
		var nombre = limpia;
		var build = int.tryParse(buildNumber?.trim() ?? '') ?? 0;
		final plus = limpia.indexOf('+');
		if (plus >= 0) {
			nombre = limpia.substring(0, plus);
			build = int.tryParse(limpia.substring(plus + 1)) ?? build;
		}
		return VersionApp(nombre: nombre, build: build);
	}

	factory VersionApp.desdeManifiesto(ManifestoActualizacionApp manifiesto) {
		return VersionApp(nombre: manifiesto.version, build: manifiesto.build);
	}

	String get etiqueta {
		if (build > 0) {
			return '$nombre+$build';
		}
		return nombre;
	}
}

/// 1 si [candidata] es mas nueva que [instalada], 0 igual, -1 mas vieja.
int compararVersionApp(VersionApp candidata, VersionApp instalada) {
	if (candidata.build > 0 && instalada.build > 0) {
		if (candidata.build != instalada.build) {
			return candidata.build.compareTo(instalada.build);
		}
	}
	return _compararSemver(candidata.nombre, instalada.nombre);
}

bool hayActualizacionDisponible({
	required VersionApp instalada,
	required ManifestoActualizacionApp remota,
}) {
	if (remota.version.trim().isEmpty && remota.build <= 0) {
		return false;
	}
	return compararVersionApp(
			VersionApp.desdeManifiesto(remota),
			instalada,
		) >
		0;
}

int _compararSemver(String a, String b) {
	final partesA = _partes(a);
	final partesB = _partes(b);
	final n = partesA.length > partesB.length ? partesA.length : partesB.length;
	for (var i = 0; i < n; i++) {
		final va = i < partesA.length ? partesA[i] : 0;
		final vb = i < partesB.length ? partesB[i] : 0;
		if (va != vb) {
			return va.compareTo(vb);
		}
	}
	return 0;
}

List<int> _partes(String version) {
	return version
		.split(RegExp(r'[^0-9]+'))
		.where((p) => p.isNotEmpty)
		.map(int.parse)
		.toList();
}
