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
	/// [cursorLocal] Ultimo evento del hub confirmado por este dispositivo.
	/// [eventosEnCuarentena] Eventos recibidos que no se pudieron aplicar.
	/// [ultimoError] Mensaje del ultimo ciclo de sync que fallo.
	/// [ultimoErrorEn] Momento de [ultimoError].
	const EstadoSyncAdmin({
		required this.eventosPendientes,
		required this.eventosConError,
		required this.hubConfigurado,
		this.cursorLocal = 0,
		this.eventosEnCuarentena = 0,
		this.ultimoError,
		this.ultimoErrorEn,
	});

	/// Eventos pendientes de transmision.
	final int eventosPendientes;

	/// Eventos con error de envio.
	final int eventosConError;

	/// Hub central configurado en dispositivo.
	final bool hubConfigurado;

	/// Posicion del dispositivo en el log del hub (`last_synced_event_seq`).
	///
	/// Es el dato que delata un equipo anclado en el pasado: si no se mueve
	/// entre sincronizaciones, este dispositivo dejo de recibir cambios.
	final int cursorLocal;

	/// Eventos recibidos que fallaron al aplicarse y se reintentan cada ciclo.
	final int eventosEnCuarentena;

	/// Ultimo error de ciclo, si el ultimo intento no termino bien.
	final String? ultimoError;

	/// Momento en que se registro [ultimoError].
	final DateTime? ultimoErrorEn;
}
