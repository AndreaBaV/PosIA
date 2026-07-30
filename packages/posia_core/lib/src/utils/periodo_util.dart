/// Ventanas de periodo para historial, reportes y auditorias.
library;

/// Rango de consulta cerrado en UTC, listo para comparar contra ISO-8601.
class RangoPeriodo {
	const RangoPeriodo({required this.desde, required this.hasta});

	final DateTime desde;
	final DateTime hasta;
}

/// Ventana de [dias] dias calendario locales que termina en este instante.
///
/// `dias == 1` significa "hoy": desde la medianoche local hasta ahora. La
/// version anterior restaba 24 h al reloj, asi que "Hoy" era una ventana
/// rodante: las ventas de la manana se caian del listado al avanzar la tarde y
/// el corte quedaba a media jornada en vez de al inicio del dia.
///
/// [desde] y [hasta] salen en UTC porque las fechas se guardan como texto
/// ISO-8601 en UTC y la comparacion en SQLite es lexicografica.
RangoPeriodo rangoPeriodoDiasLocal(int dias) {
	final ahora = DateTime.now();
	final diasEfectivos = dias < 1 ? 1 : dias;
	final inicioDeHoy = DateTime(ahora.year, ahora.month, ahora.day);
	final desde = inicioDeHoy.subtract(Duration(days: diasEfectivos - 1));
	return RangoPeriodo(desde: desde.toUtc(), hasta: ahora.toUtc());
}
