/// Linea de detalle de una cotizacion guardada.
library;

import '../enums/regla_precio.dart';
import '../utils/moneda_util.dart';

/// Producto y precio cotizados.
class LineaCotizacion {
	const LineaCotizacion({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidad,
		required this.precioUnitario,
		this.reglaPrecio = ReglaPrecio.precioBase,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidad;
	final double precioUnitario;
	final ReglaPrecio reglaPrecio;

	double get subtotal => redondearMonto(cantidad * precioUnitario);
}
