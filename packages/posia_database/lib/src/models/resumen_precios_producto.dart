/// Resumen de precios configurados para un producto.
library;

import 'package:posia_pricing/posia_pricing.dart';

/// Precios genericos, por lista y por cliente de un articulo.
class ResumenPreciosProducto {
	const ResumenPreciosProducto({
		required this.productoId,
		required this.nombreProducto,
		required this.costoUnitario,
		required this.precioGenerico,
		required this.precioMinimo,
		required this.preciosPorLista,
		required this.preciosPorCliente,
		required this.nombresListas,
		required this.nombresClientes,
	});

	final String productoId;
	final String nombreProducto;
	final double costoUnitario;
	final double precioGenerico;
	final double precioMinimo;
	final Map<String, double> preciosPorLista;
	final List<PrecioClienteProducto> preciosPorCliente;
	final Map<String, String> nombresListas;
	final Map<String, String> nombresClientes;
}
