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
	///
	/// [id] Identificador unico del evento.
	/// [tenantId] Tenant propietario del dato.
	/// [tiendaId] Tienda origen del evento.
	/// [dispositivoId] Dispositivo que genero el evento.
	/// [tipo] Clasificacion del evento.
	/// [payload] Datos serializados en JSON.
	/// [creadoEn] Marca de tiempo de creacion.
	/// [estado] Estado en cola local.
	const SyncEvent({
		required this.id,
		required this.tenantId,
		required this.tiendaId,
		required this.dispositivoId,
		required this.tipo,
		required this.payload,
		required this.creadoEn,
		required this.estado,
	});

	/// Identificador del evento.
	final String id;

	/// Tenant al que pertenece.
	final String tenantId;

	/// Tienda origen.
	final String tiendaId;

	/// Dispositivo emisor.
	final String dispositivoId;

	/// Tipo de evento.
	final TipoSyncEvento tipo;

	/// Contenido JSON del evento.
	final Map<String, Object?> payload;

	/// Fecha de creacion UTC.
	final DateTime creadoEn;

	/// Estado en cola local.
	final EstadoSyncEvento estado;

	/// Genera copia con estado actualizado.
	///
	/// [nuevoEstado] Estado resultante en cola.
	/// Retorna nuevo [SyncEvent].
	SyncEvent copiarConEstado(EstadoSyncEvento nuevoEstado) {
		return SyncEvent(
			id: id,
			tenantId: tenantId,
			tiendaId: tiendaId,
			dispositivoId: dispositivoId,
			tipo: tipo,
			payload: payload,
			creadoEn: creadoEn,
			estado: nuevoEstado,
		);
	}
}
