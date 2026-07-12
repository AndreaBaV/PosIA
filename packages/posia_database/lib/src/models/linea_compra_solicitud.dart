/// Linea solicitada al registrar una compra.
library;

import 'package:posia_core/posia_core.dart';

/// Producto, cantidad, costo unitario y distribucion de inventario.
class LineaCompraSolicitud {
	const LineaCompraSolicitud({
		required this.productoId,
		required this.cantidad,
		required this.costoUnitario,
		this.asignaciones = const [],
	});

	final String productoId;
	final double cantidad;
	final double costoUnitario;
	final List<AsignacionInventarioCompra> asignaciones;
}
