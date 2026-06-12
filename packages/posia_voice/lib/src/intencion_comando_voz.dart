/// Intencion detectada en un comando hablado.
library;

/// Accion de alto nivel solicitada por voz.
enum IntencionComandoVoz {
	/// Agregar productos al carrito o generar ticket.
	agregarProductos,

	/// Cobrar venta actual.
	cobrar,

	/// Vaciar carrito.
	vaciarCarrito,

	/// Texto no reconocido como comando util.
	desconocido,
}
