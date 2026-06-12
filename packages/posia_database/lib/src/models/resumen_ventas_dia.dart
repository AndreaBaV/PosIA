/// Resumen consolidado de ventas del dia por tienda.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

/// Agrupa metricas de ventas diarias para panel admin.
class ResumenVentasDia {
	/// Crea resumen de ventas del dia.
	///
	/// [tiendaId] Tienda evaluada.
	/// [nombreTienda] Nombre visible de la sucursal.
	/// [totalVendido] Suma de ventas del dia en MXN.
	/// [cantidadVentas] Numero de transacciones cerradas.
	const ResumenVentasDia({
		required this.tiendaId,
		required this.nombreTienda,
		required this.totalVendido,
		required this.cantidadVentas,
	});

	/// Identificador de tienda.
	final String tiendaId;

	/// Nombre comercial de la tienda.
	final String nombreTienda;

	/// Total vendido en el dia.
	final double totalVendido;

	/// Cantidad de ventas registradas.
	final int cantidadVentas;
}
