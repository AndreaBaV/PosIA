/// Estado de un turno de corte de caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Apertura y cierre de turno en caja registradora.
enum EstadoTurnoCaja {
	/// Turno abierto; acepta ventas.
	abierto,

	/// Turno cerrado con arqueo.
	cerrado,
}
