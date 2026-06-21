/// Condicion para activar un descuento de cliente.
library;

/// Regla que debe cumplirse para aplicar el beneficio.
enum CondicionDescuentoCliente {
	/// Siempre que el cliente este seleccionado en caja.
	siempre,

	/// Cuando la linea del producto alcanza cierta cantidad.
	cantidadMinima,

	/// Cuando el subtotal del ticket alcanza un monto minimo.
	montoTicketMinimo,
}
