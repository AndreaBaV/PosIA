/// Lote farmaceutico con numero y fecha de caducidad.
library;

/// Representa existencia de medicamento o producto farmaceutico por lote.
class LoteFarmacia {
	const LoteFarmacia({
		required this.id,
		required this.productoId,
		required this.tiendaId,
		required this.numeroLote,
		required this.caducaEn,
		required this.cantidad,
		required this.activo,
	});

	final String id;
	final String productoId;
	final String tiendaId;
	final String numeroLote;
	final DateTime caducaEn;
	final double cantidad;
	final bool activo;

	/// Etiqueta visible para ticket y UI.
	String generarEtiquetaVisible() {
		final dia = caducaEn.day.toString().padLeft(2, '0');
		final mes = caducaEn.month.toString().padLeft(2, '0');
		final anio = caducaEn.year.toString();
		return 'Lote $numeroLote · $dia/$mes/$anio';
	}
}
