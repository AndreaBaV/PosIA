/// Resumen de ventas por vendedor en un periodo.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Totales agrupados por vendedor.
class ResumenVendedor {
	const ResumenVendedor({
		required this.vendedorId,
		required this.nombreVendedor,
		required this.cantidadVentas,
		required this.totalVendido,
	});

	final String vendedorId;
	final String nombreVendedor;
	final int cantidadVentas;
	final double totalVendido;
}
