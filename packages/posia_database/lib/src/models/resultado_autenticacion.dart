/// Resultado de autenticacion con tenant resuelto.
library;

import 'package:posia_core/posia_core.dart';

/// Usuario autenticado junto con su tenant.
class ResultadoAutenticacion {
	const ResultadoAutenticacion({
		required this.usuario,
		required this.tenantId,
		this.pinHash,
		this.pinSalt,
		this.creadoEn,
		this.actualizadoEn,
		this.tiendas = const [],
	});

	final Usuario usuario;
	final String tenantId;
	final String? pinHash;
	final String? pinSalt;
	final String? creadoEn;
	final String? actualizadoEn;
	final List<Tienda> tiendas;

	bool get desdeHub => pinHash != null && pinSalt != null;
}
