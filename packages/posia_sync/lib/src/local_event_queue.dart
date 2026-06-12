/// Contrato de cola local de eventos de sincronizacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Persistencia de eventos pendientes en dispositivo.
abstract class LocalEventQueue {
	/// Encola un evento para envio posterior.
	///
	/// [evento] Evento capturado en caja.
	Future<void> encolar(SyncEvent evento);

	/// Obtiene eventos pendientes de transmision.
	///
	/// Retorna lista de eventos con estado pendiente o error.
	Future<List<SyncEvent>> obtenerPendientes();

	/// Marca evento como enviado exitosamente.
	///
	/// [eventoId] Identificador del evento confirmado.
	Future<void> marcarEnviado(String eventoId);

	/// Marca evento con error de envio para reintento.
	///
	/// [eventoId] Identificador del evento fallido.
	Future<void> marcarError(String eventoId);
}
