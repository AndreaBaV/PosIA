/// Estados de un evento en la cola de sincronizacion local.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Indica el ciclo de vida del evento en cola local.
enum EstadoSyncEvento {
	/// Evento capturado y pendiente de envio al hub o LAN.
	pendiente,

	/// Evento enviado exitosamente.
	enviado,

	/// Evento con error de envio; se reintentara.
	error,
}
