/// Estado de una venta cerrada en caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Ciclo de vida de una transaccion de venta.
enum EstadoVenta {
	/// Venta cobrada y vigente.
	completada,

	/// Venta anulada; stock revertido.
	cancelada,

	/// Devolucion total o parcial aplicada.
	devuelta,
}
