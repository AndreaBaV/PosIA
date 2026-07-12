/// Asignacion de mercancia solicitada al registrar una compra.
library;

import 'package:posia_core/posia_core.dart';

/// Destino y cantidad de un producto comprado.
class AsignacionCompraSolicitud {
	const AsignacionCompraSolicitud({
		required this.productoId,
		required this.destinoTipo,
		required this.destinoId,
		required this.cantidad,
	});

	final String productoId;
	final TipoDestinoCompra destinoTipo;
	final String destinoId;
	final double cantidad;
}
