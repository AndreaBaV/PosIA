/// Tipo de beneficio comercial asignado a un cliente.
library;

/// Forma en que se aplica el descuento del cliente.
enum TipoDescuentoCliente {
	/// Porcentaje sobre el total del ticket.
	porcentajeGeneral,

	/// Monto fijo en pesos sobre el total del ticket.
	montoFijoGeneral,

	/// Porcentaje sobre un producto especifico.
	porcentajeProducto,

	/// Monto fijo en pesos sobre una linea de producto.
	montoFijoProducto,
}

/// Utilidades de clasificacion del tipo de descuento.
extension TipoDescuentoClienteUtil on TipoDescuentoCliente {
	bool get esGeneral =>
		this == TipoDescuentoCliente.porcentajeGeneral ||
		this == TipoDescuentoCliente.montoFijoGeneral;

	bool get esPorProducto =>
		this == TipoDescuentoCliente.porcentajeProducto ||
		this == TipoDescuentoCliente.montoFijoProducto;
}
