/// Estados del ciclo de vida de un pedido.
library;

/// Flujo: recibido → asignado → entregado (o cancelado).
enum EstadoPedido {
	recibido,
	asignado,
	entregado,
	cancelado,
}
