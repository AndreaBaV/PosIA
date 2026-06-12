/// Resultado de aplicar un comando de voz al catalogo.
library;

import 'package:posia_core/posia_core.dart';

import 'intencion_comando_voz.dart';

/// Linea lista para agregar al carrito.
class LineaVozResuelta {
	const LineaVozResuelta({
		required this.producto,
		required this.cantidad,
		required this.descripcion,
		required this.usarPeso,
	});

	final Producto producto;
	final double cantidad;
	final String descripcion;
	final bool usarPeso;
}

/// Resultado completo del motor de voz.
class ResultadoComandoVoz {
	const ResultadoComandoVoz({
		required this.intencion,
		required this.lineas,
		required this.noEncontrados,
		required this.textoOriginal,
	});

	final IntencionComandoVoz intencion;
	final List<LineaVozResuelta> lineas;
	final List<String> noEncontrados;
	final String textoOriginal;

	bool get tieneLineas => lineas.isNotEmpty;
}
