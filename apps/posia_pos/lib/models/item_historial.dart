/// Registro unificado en historial de ventas y pedidos entregados.
library;

import 'package:posia_core/posia_core.dart';

/// Tipo de movimiento mostrado en historial.
enum TipoRegistroHistorial {
	venta,
	pedidoEntregado,
}

/// Venta de caja o pedido marcado como entregado.
class ItemHistorial {
	const ItemHistorial.venta(this.venta)
		: pedido = null,
		  tipo = TipoRegistroHistorial.venta;

	const ItemHistorial.pedido(this.pedido)
		: venta = null,
		  tipo = TipoRegistroHistorial.pedidoEntregado;

	final TipoRegistroHistorial tipo;
	final Venta? venta;
	final Pedido? pedido;

	DateTime get fecha => switch (tipo) {
		TipoRegistroHistorial.venta => venta!.creadaEn,
		TipoRegistroHistorial.pedidoEntregado => pedido!.creadoEn,
	};

	double get total => switch (tipo) {
		TipoRegistroHistorial.venta => venta!.total,
		TipoRegistroHistorial.pedidoEntregado => pedido!.total,
	};
}
