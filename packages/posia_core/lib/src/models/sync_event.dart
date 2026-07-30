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
		this.seq = 0,
	});

	final String id;
	final String tiendaId;
	final String dispositivoId;
	final TipoSyncEvento tipo;
	final Map<String, Object?> payload;
	final DateTime creadoEn;
	final EstadoSyncEvento estado;

	/// Posicion del evento en el log del hub; 0 si es local (aun sin enviar).
	///
	/// El pull avanza el cursor con este valor evento por evento. Sin el, un
	/// solo evento defectuoso a mitad de pagina impedia confirmar los que ya
	/// se habian aplicado y el dispositivo se quedaba anclado en ese punto del
	/// historial indefinidamente.
	final int seq;

	SyncEvent copiarConEstado(EstadoSyncEvento nuevoEstado) {
		return SyncEvent(
			id: id,
			tiendaId: tiendaId,
			dispositivoId: dispositivoId,
			tipo: tipo,
			payload: payload,
			creadoEn: creadoEn,
			estado: nuevoEstado,
			seq: seq,
		);
	}
}
