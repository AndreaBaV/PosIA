/// Producto con precio asignado en una lista comercial.
library;

import 'package:posia_core/posia_core.dart';

/// Articulo incluido en una lista de precios con su precio especial.
class ItemListaPrecios {
	const ItemListaPrecios({
		required this.producto,
		required this.precioLista,
	});

	final Producto producto;
	final double precioLista;
}
