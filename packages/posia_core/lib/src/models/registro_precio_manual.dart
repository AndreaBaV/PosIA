/// Registro de una línea vendida con precio manual, para auditoría del admin.
library;

/// Una línea de venta cuyo precio fue fijado manualmente (sobreprecio o
/// descuento), con la referencia del precio base para medir la diferencia.
class RegistroPrecioManual {
	/// Crea un registro de precio manual auditable.
	const RegistroPrecioManual({
		required this.ventaId,
		required this.fecha,
		required this.vendedorNombre,
		required this.nombreProducto,
		required this.cantidad,
		required this.precioCobrado,
		this.vendedorId,
		this.precioReferencia,
	});

	/// Venta a la que pertenece la línea (para consultar/reimprimir el ticket).
	final String ventaId;

	/// Fecha y hora de la venta.
	final DateTime fecha;

	/// Vendedor que registró la venta (puede ser nulo en ventas antiguas).
	final String? vendedorId;

	/// Nombre del vendedor (o "Desconocido").
	final String vendedorNombre;

	/// Nombre del producto vendido.
	final String nombreProducto;

	/// Cantidad vendida.
	final double cantidad;

	/// Precio unitario efectivamente cobrado.
	final double precioCobrado;

	/// Precio base actual del producto (referencia; puede haber cambiado desde
	/// la venta, por eso es aproximada).
	final double? precioReferencia;

	/// Diferencia total contra la referencia (positivo = sobreprecio; negativo =
	/// descuento). Nula si no hay precio de referencia.
	double? get diferenciaTotal => precioReferencia == null
		? null
		: (precioCobrado - precioReferencia!) * cantidad;
}
