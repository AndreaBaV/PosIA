/// Resumen de ventas agrupado por hora del dia (hora local).
library;

/// Totales de ventas en una franja horaria.
class ResumenVentasHora {
	const ResumenVentasHora({
		required this.hora,
		required this.cantidadVentas,
		required this.totalVendido,
	});

	/// Hora del dia en zona local (0-23).
	final int hora;
	final int cantidadVentas;
	final double totalVendido;

	/// Etiqueta legible, p. ej. "08:00 - 08:59".
	String get etiquetaFranja {
		final inicio = hora.toString().padLeft(2, '0');
		final fin = hora.toString().padLeft(2, '0');
		return '$inicio:00 - $fin:59';
	}
}
