/// Precio preferencial fijo por cliente y producto.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Representa override de precio para un cliente especifico.
class PrecioClienteProducto {
	/// Crea precio preferencial cliente-producto.
	///
	/// [clienteId] Cliente beneficiado.
	/// [productoId] Producto con precio especial.
	/// [precioUnitario] Precio acordado en MXN.
	const PrecioClienteProducto({
		required this.clienteId,
		required this.productoId,
		required this.precioUnitario,
	});

	/// Identificador del cliente.
	final String clienteId;

	/// Identificador del producto.
	final String productoId;

	/// Precio unitario preferencial.
	final double precioUnitario;
}
