/// Evento de sincronizacion intercambiado entre dispositivos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import '../enums/estado_sync_evento.dart';
import '../enums/tipo_sync_evento.dart';

/// Representa un evento del log append-only de sync.
class SyncEvent {
	/// Crea un evento de sincronizacion.
	const SyncEvent({
		required this.id,
		required this.tiendaId,
		required this.dispositivoId,
		required this.tipo,
		required this.payload,
		required this.creadoEn,
		required this.estado,
	});

	final String id;
	final String tiendaId;
	final String dispositivoId;
	final TipoSyncEvento tipo;
	final Map<String, Object?> payload;
	final DateTime creadoEn;
	final EstadoSyncEvento estado;

	SyncEvent copiarConEstado(EstadoSyncEvento nuevoEstado) {
		return SyncEvent(
			id: id,
			tiendaId: tiendaId,
			dispositivoId: dispositivoId,
			tipo: tipo,
			payload: payload,
			creadoEn: creadoEn,
			estado: nuevoEstado,
		);
	}
}
