/// Evento de sincronizacion almacenado en el hub.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

/// Representa un evento del log append-only del hub con cursor secuencial.
class EventoHub {
	/// Crea evento del hub.
	///
	/// [seq] Posicion secuencial asignada por el hub; 0 si aun no persiste.
	/// [id] Identificador unico generado por el dispositivo.
	/// [tenantId] Tenant propietario.
	/// [tiendaId] Tienda origen.
	/// [dispositivoId] Dispositivo emisor.
	/// [tipo] Tipo de evento de dominio.
	/// [payload] Contenido JSON del evento.
	/// [creadoEn] Marca de tiempo de creacion en el dispositivo.
	const EventoHub({
		required this.seq,
		required this.id,
		required this.tenantId,
		required this.tiendaId,
		required this.dispositivoId,
		required this.tipo,
		required this.payload,
		required this.creadoEn,
	});

	/// Posicion en el log global del hub.
	final int seq;

	/// Identificador unico del evento.
	final String id;

	/// Tenant propietario del dato.
	final String tenantId;

	/// Tienda origen del evento.
	final String tiendaId;

	/// Dispositivo que genero el evento.
	final String dispositivoId;

	/// Clasificacion del evento.
	final String tipo;

	/// Datos del evento en JSON.
	final Map<String, Object?> payload;

	/// Fecha de creacion en el dispositivo.
	final DateTime creadoEn;

	/// Construye evento desde JSON recibido en POST /v1/events.
	///
	/// [json] Mapa del evento individual.
	/// [tenantId] Tenant del lote.
	/// [tiendaId] Tienda del lote.
	/// [dispositivoId] Dispositivo del lote.
	/// Retorna instancia sin seq asignado.
	factory EventoHub.desdeJsonLote(
		Map<String, Object?> json, {
		required String tenantId,
		required String tiendaId,
		required String dispositivoId,
	}) {
		return EventoHub(
			seq: 0,
			id: json['id'] as String? ?? '',
			tenantId: tenantId,
			tiendaId: tiendaId,
			dispositivoId: dispositivoId,
			tipo: json['type'] as String? ?? '',
			payload: Map<String, Object?>.from(
				json['payload'] as Map<Object?, Object?>? ?? {},
			),
			creadoEn: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
				DateTime.now().toUtc(),
		);
	}

	/// Serializa evento para respuesta de GET /v1/events.
	///
	/// Retorna mapa JSON con seq incluido.
	Map<String, Object?> aJson() {
		return {
			'seq': seq,
			'id': id,
			'tenantId': tenantId,
			'storeId': tiendaId,
			'deviceId': dispositivoId,
			'type': tipo,
			'payload': payload,
			'createdAt': creadoEn.toIso8601String(),
		};
	}

	/// Genera copia con seq asignado por el almacen.
	///
	/// [nuevoSeq] Posicion secuencial persistida.
	/// Retorna nuevo [EventoHub].
	EventoHub copiarConSeq(int nuevoSeq) {
		return EventoHub(
			seq: nuevoSeq,
			id: id,
			tenantId: tenantId,
			tiendaId: tiendaId,
			dispositivoId: dispositivoId,
			tipo: tipo,
			payload: payload,
			creadoEn: creadoEn,
		);
	}
}
