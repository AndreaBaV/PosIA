/// Cliente HTTP para sincronizacion con hub central.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:30:00 (UTC-6)
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:posia_core/posia_core.dart';

/// Resultado de un pull incremental desde el hub.
class ResultadoPullHub {
	/// Crea resultado de pull.
	///
	/// [eventos] Eventos recibidos en orden de seq.
	/// [ultimoSeq] Cursor del ultimo evento del lote.
	/// [exitoso] Indica si el hub respondio correctamente.
	const ResultadoPullHub({
		required this.eventos,
		required this.ultimoSeq,
		required this.exitoso,
	});

	/// Eventos recibidos del hub.
	final List<SyncEvent> eventos;

	/// Ultimo seq del lote; conservar como nuevo cursor.
	final int ultimoSeq;

	/// Bandera de exito de la solicitud.
	final bool exitoso;
}

/// Envia y recibe eventos del servidor de sync multi-tenant.
class HubSyncClient {
	/// Crea cliente apuntando a URL base del hub.
	///
	/// [urlBase] URL raiz del API sin barra final.
	/// [claveApi] Clave compartida opcional para cabecera x-api-key.
	/// [clienteHttp] Cliente HTTP inyectable para pruebas.
	HubSyncClient({
		required String urlBase,
		String? claveApi,
		http.Client? clienteHttp,
	}) : _urlBase = urlBase,
	     _claveApi = claveApi,
	     _clienteHttp = clienteHttp ?? http.Client();

	final String _urlBase;
	final String? _claveApi;
	final http.Client _clienteHttp;

	/// Envia lote de eventos al hub.
	///
	/// [tenantId] Tenant propietario.
	/// [dispositivoId] Identificador del dispositivo emisor.
	/// [tiendaId] Tienda origen.
	/// [eventos] Eventos a transmitir.
	/// Retorna verdadero si el hub acepto el lote.
	Future<bool> enviarEventos({
		required String tenantId,
		required String dispositivoId,
		required String tiendaId,
		required List<SyncEvent> eventos,
	}) async {
		final uri = Uri.parse('$_urlBase/v1/events');
		final cuerpo = jsonEncode({
			'tenantId': tenantId,
			'deviceId': dispositivoId,
			'storeId': tiendaId,
			'events': eventos.map(_serializarEvento).toList(),
		});
		try {
			final respuesta = await _clienteHttp.post(
				uri,
				headers: _construirCabeceras(),
				body: cuerpo,
			);
			return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
		} on http.ClientException {
			return false;
		}
	}

	/// Obtiene eventos nuevos desde un cursor secuencial.
	///
	/// [tenantId] Tenant a sincronizar.
	/// [desdeSeq] Ultimo seq aplicado localmente; 0 para inicio.
	/// [excluirDispositivoId] Omite eventos emitidos por esta caja.
	/// Retorna resultado con eventos y nuevo cursor.
	Future<ResultadoPullHub> obtenerEventos({
		required String tenantId,
		required int desdeSeq,
		String? excluirDispositivoId,
	}) async {
		final uri = Uri.parse('$_urlBase/v1/events').replace(
			queryParameters: {
				'tenantId': tenantId,
				'since': desdeSeq.toString(),
				if (excluirDispositivoId != null) 'excludeDevice': excluirDispositivoId,
			},
		);
		final http.Response respuesta;
		try {
			respuesta = await _clienteHttp.get(uri, headers: _construirCabeceras());
		} on http.ClientException {
			return const ResultadoPullHub(eventos: [], ultimoSeq: 0, exitoso: false);
		}
		if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
			return const ResultadoPullHub(eventos: [], ultimoSeq: 0, exitoso: false);
		}
		final json = jsonDecode(respuesta.body) as Map<String, Object?>;
		final lista = json['events'] as List<Object?>? ?? [];
		final eventos = lista
			.whereType<Map<String, Object?>>()
			.map(_deserializarEvento)
			.toList();
		return ResultadoPullHub(
			eventos: eventos,
			ultimoSeq: json['lastSeq'] as int? ?? desdeSeq,
			exitoso: true,
		);
	}

	/// Verifica disponibilidad del hub.
	///
	/// Retorna verdadero si /v1/health responde ok.
	Future<bool> verificarSalud() async {
		final uri = Uri.parse('$_urlBase/v1/health');
		try {
			final respuesta = await _clienteHttp.get(uri, headers: _construirCabeceras());
			return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
		} on http.ClientException {
			return false;
		}
	}

	/// Construye cabeceras comunes con clave API opcional.
	///
	/// Retorna mapa de cabeceras HTTP.
	Map<String, String> _construirCabeceras() {
		final clave = _claveApi;
		return {
			'Content-Type': 'application/json',
			if (clave != null && clave.isNotEmpty) 'x-api-key': clave,
		};
	}

	/// Serializa evento a mapa JSON para transporte.
	///
	/// [evento] Evento de dominio.
	/// Retorna mapa listo para JSON.
	Map<String, Object?> _serializarEvento(SyncEvent evento) {
		return {
			'id': evento.id,
			'type': evento.tipo.name,
			'payload': evento.payload,
			'createdAt': evento.creadoEn.toIso8601String(),
		};
	}

	/// Deserializa evento recibido del hub.
	///
	/// [json] Mapa JSON del evento remoto.
	/// Retorna instancia de [SyncEvent].
	SyncEvent _deserializarEvento(Map<String, Object?> json) {
		final tipoNombre = json['type'] as String? ?? '';
		final tipo = TipoSyncEvento.values.firstWhere(
			(elemento) => elemento.name == tipoNombre,
			orElse: () => TipoSyncEvento.productUpserted,
		);
		return SyncEvent(
			id: json['id'] as String? ?? '',
			tenantId: json['tenantId'] as String? ?? '',
			tiendaId: json['storeId'] as String? ?? '',
			dispositivoId: json['deviceId'] as String? ?? '',
			tipo: tipo,
			payload: Map<String, Object?>.from(
				json['payload'] as Map<Object?, Object?>? ?? {},
			),
			creadoEn: DateTime.parse(json['createdAt'] as String? ?? ''),
			estado: EstadoSyncEvento.enviado,
		);
	}
}
