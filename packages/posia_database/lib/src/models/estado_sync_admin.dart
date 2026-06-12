/// Estado de sincronizacion visible en panel admin.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

/// Resume cola local de eventos pendientes de sync.
class EstadoSyncAdmin {
	/// Crea estado de sincronizacion para administrador.
	///
	/// [eventosPendientes] Cantidad de eventos en cola.
	/// [eventosConError] Cantidad de eventos con error de envio.
	/// [hubConfigurado] Indica si hay URL de hub activa.
	const EstadoSyncAdmin({
		required this.eventosPendientes,
		required this.eventosConError,
		required this.hubConfigurado,
	});

	/// Eventos pendientes de transmision.
	final int eventosPendientes;

	/// Eventos con error de envio.
	final int eventosConError;

	/// Hub central configurado en dispositivo.
	final bool hubConfigurado;
}
