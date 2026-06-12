/// Contrato de persistencia del cursor de sincronizacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:30:00 (UTC-6)
library;

/// Guarda y lee el ultimo seq confirmado del hub.
abstract class AlmacenCursorSync {
	/// Lee ultimo seq aplicado localmente.
	///
	/// Retorna 0 si nunca se ha sincronizado.
	Future<int> leerCursorHub();

	/// Persiste ultimo seq aplicado.
	///
	/// [seq] Posicion confirmada del log del hub.
	Future<void> guardarCursorHub(int seq);
}
