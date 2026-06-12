/// Linea de producto extraida de un comando de voz.
library;

import 'package:posia_core/posia_core.dart';

/// Producto hablado antes de resolver contra catalogo.
class LineaComandoVoz {
	const LineaComandoVoz({
		required this.nombreProducto,
		required this.cantidadHablada,
		required this.unidadHablada,
	});

	/// Texto del producto despues de cantidad y unidad.
	final String nombreProducto;

	/// Cantidad numerica interpretada (ej. 0.5, 1, 12).
	final double cantidadHablada;

	/// Unidad mencionada en el comando.
	final UnidadMedida? unidadHablada;
}
