/// Escala de precio mayoreo por cantidad minima.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Define umbral de cantidad y precio unitario resultante.
class EscalaMayoreo {
	/// Crea escala de mayoreo.
	///
	/// [productoId] Producto al que aplica la escala.
	/// [cantidadMinima] Cantidad minima inclusive para activar precio.
	/// [precioUnitario] Precio unitario en MXN para la escala.
	const EscalaMayoreo({
		required this.productoId,
		required this.cantidadMinima,
		required this.precioUnitario,
	});

	/// Identificador del producto.
	final String productoId;

	/// Cantidad minima para activar escala.
	final double cantidadMinima;

	/// Precio unitario de la escala.
	final double precioUnitario;
}
