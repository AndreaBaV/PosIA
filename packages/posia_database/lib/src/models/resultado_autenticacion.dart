/// Resultado de autenticacion exitosa.
library;

import 'package:posia_core/posia_core.dart';

/// Usuario autenticado con datos opcionales del hub.
class ResultadoAutenticacion {
	const ResultadoAutenticacion({
		required this.usuario,
		this.pinCredencial,
		this.creadoEn,
		this.actualizadoEn,
		this.tiendas = const [],
	});

	final Usuario usuario;
	final String? pinCredencial;
	final String? creadoEn;
	final String? actualizadoEn;
	final List<Tienda> tiendas;

	bool get desdeHub => pinCredencial != null;
}
