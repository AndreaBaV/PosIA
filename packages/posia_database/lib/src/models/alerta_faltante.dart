/// Alerta de producto bajo inventario minimo.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Producto con existencia bajo umbral configurado.
class AlertaFaltante {
	const AlertaFaltante({
		required this.productoId,
		required this.nombreProducto,
		required this.cantidadActual,
		required this.stockMinimo,
		required this.tiendaId,
	});

	final String productoId;
	final String nombreProducto;
	final double cantidadActual;
	final double stockMinimo;
	final String tiendaId;
}
