/// Evento de sincronizacion almacenado en el hub.
library;

class EventoHub {
	const EventoHub({
		required this.seq,
		required this.id,
		required this.tiendaId,
		required this.dispositivoId,
		required this.tipo,
		required this.payload,
		required this.creadoEn,
	});

	final int seq;
	final String id;
	final String tiendaId;
	final String dispositivoId;
	final String tipo;
	final Map<String, Object?> payload;
	final DateTime creadoEn;

	factory EventoHub.desdeJsonLote(
		Map<String, Object?> json, {
		required String tiendaId,
		required String dispositivoId,
	}) {
		return EventoHub(
			seq: 0,
			id: json['id'] as String? ?? '',
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

	Map<String, Object?> aJson() {
		return {
			'seq': seq,
			'id': id,
			'storeId': tiendaId,
			'deviceId': dispositivoId,
			'type': tipo,
			'payload': payload,
			'createdAt': creadoEn.toIso8601String(),
		};
	}

	EventoHub copiarConSeq(int nuevoSeq) {
		return EventoHub(
			seq: nuevoSeq,
			id: id,
			tiendaId: tiendaId,
			dispositivoId: dispositivoId,
			tipo: tipo,
			payload: payload,
			creadoEn: creadoEn,
		);
	}
}
