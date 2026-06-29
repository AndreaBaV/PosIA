/// Modelo de licencia perpetua POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Representa derechos comerciales otorgados al cliente.
class Licencia {
	const Licencia({
		required this.modulos,
		required this.maxTiendas,
		required this.maxCajas,
		required this.maxUsuarios,
		required this.soporteExpiraEn,
	});

	final List<ModuloLicencia> modulos;
	final int maxTiendas;
	final int maxCajas;
	final int maxUsuarios;
	final DateTime soporteExpiraEn;

	bool tieneModulo(ModuloLicencia modulo) {
		return modulos.contains(modulo);
	}

	bool soporteVigente() {
		final ahora = DateTime.now().toUtc();
		return ahora.isBefore(soporteExpiraEn);
	}
}
