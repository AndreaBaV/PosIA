/// Lote farmaceutico con numero y fecha de caducidad.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

/// Representa existencia de medicamento o producto farmaceutico por lote.
class LoteFarmacia {
	/// Crea lote farmaceutico.
	///
	/// [id] Identificador unico del lote.
	/// [productoId] Producto asociado.
	/// [tiendaId] Tienda donde reside el lote.
	/// [numeroLote] Numero impreso en empaque.
	/// [caducaEn] Fecha de caducidad inclusive.
	/// [cantidad] Unidades disponibles del lote.
	/// [activo] Indica si el lote puede venderse.
	const LoteFarmacia({
		required this.id,
		required this.productoId,
		required this.tiendaId,
		required this.numeroLote,
		required this.caducaEn,
		required this.cantidad,
		required this.activo,
	});

	/// Identificador del lote.
	final String id;

	/// Producto del lote.
	final String productoId;

	/// Tienda del lote.
	final String tiendaId;

	/// Numero de lote del fabricante.
	final String numeroLote;

	/// Fecha de caducidad UTC.
	final DateTime caducaEn;

	/// Cantidad disponible.
	final double cantidad;

	/// Estado activo del lote.
	final bool activo;

	/// Genera etiqueta visible para ticket y UI.
	///
	/// Retorna numero de lote y fecha corta de caducidad.
	String generarEtiquetaVisible() {
		final dia = caducaEn.day.toString().padLeft(2, '0');
		final mes = caducaEn.month.toString().padLeft(2, '0');
		final anio = caducaEn.year.toString();
		return 'Lote $numeroLote · $dia/$mes/$anio';
	}
}
