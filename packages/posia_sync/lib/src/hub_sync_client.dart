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

import 'auth_hub.dart';

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
			final respuesta = await _clienteHttp
				.post(uri, headers: _construirCabeceras(), body: cuerpo)
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
			if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
				return false;
			}
			final json = jsonDecode(respuesta.body) as Map<String, Object?>;
			final aceptados = json['accepted'] as int? ?? 0;
			final recibidos = json['received'] as int? ?? eventos.length;
			return aceptados > 0 || recibidos > 0;
		} on Object {
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
			respuesta = await _clienteHttp
				.get(uri, headers: _construirCabeceras())
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
		} on Object {
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
			.whereType<SyncEvent>()
			.toList();
		return ResultadoPullHub(
			eventos: eventos,
			ultimoSeq: json['lastSeq'] as int? ?? desdeSeq,
			exitoso: true,
		);
	}

	/// Busca perfil por codigo sin validar PIN (paso previo al login).
	Future<PerfilUsuarioHub?> obtenerPerfilUsuario(
		String codigo, {
		String? tenantId,
	}) async {
		final limpio = codigo.trim();
		if (limpio.isEmpty) {
			return null;
		}
		final uri = Uri.parse('$_urlBase/v1/auth/preview').replace(
			queryParameters: {
				'codigo': limpio,
				if (tenantId != null && tenantId.trim().isNotEmpty)
					'tenantId': tenantId.trim(),
			},
		);
		try {
			final respuesta = await _clienteHttp
				.get(uri, headers: _construirCabeceras())
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
			if (respuesta.statusCode != 200) {
				return null;
			}
			final json = jsonDecode(respuesta.body) as Map<String, Object?>;
			return _mapearPerfil(json);
		} on Object {
			return null;
		}
	}

	/// Autentica usuario y resuelve el tenant al que pertenece.
	Future<RespuestaLoginHub?> iniciarSesion({
		required String codigo,
		required String pin,
		String? tenantId,
	}) async {
		final limpio = codigo.trim();
		if (limpio.isEmpty || pin.isEmpty) {
			return null;
		}
		final uri = Uri.parse('$_urlBase/v1/auth/login');
		try {
			final respuesta = await _clienteHttp
				.post(
					uri,
					headers: _construirCabeceras(),
					body: jsonEncode({
						'codigo': limpio,
						'pin': pin,
						if (tenantId != null && tenantId.trim().isNotEmpty)
							'tenantId': tenantId.trim(),
					}),
				)
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
			if (respuesta.statusCode != 200) {
				return null;
			}
			final json = jsonDecode(respuesta.body) as Map<String, Object?>;
			final perfil = _mapearPerfil(json);
			if (perfil == null) {
				return null;
			}
			final pinHash = json['pinHash'] as String? ?? '';
			final pinSalt = json['pinSalt'] as String? ?? '';
			if (pinHash.isEmpty || pinSalt.isEmpty) {
				return null;
			}
			return RespuestaLoginHub(
				perfil: perfil,
				pinHash: pinHash,
				pinSalt: pinSalt,
				creadoEn: json['creadoEn'] as String? ?? '',
				actualizadoEn: json['actualizadoEn'] as String? ?? '',
				tiendas: _mapearTiendas(json['tiendas']),
			);
		} on Object {
			return null;
		}
	}

	PerfilUsuarioHub? _mapearPerfil(Map<String, Object?> json) {
		final tenantId = json['tenantId'] as String? ?? '';
		final id = json['id'] as String? ?? '';
		if (tenantId.isEmpty || id.isEmpty) {
			return null;
		}
		return PerfilUsuarioHub(
			tenantId: tenantId,
			id: id,
			nombre: json['nombre'] as String? ?? '',
			codigo: json['codigo'] as String? ?? '',
			rol: json['rol'] as String? ?? 'empleado',
			tiendaId: json['tiendaId'] as String?,
			activo: json['activo'] as bool? ?? true,
		);
	}

	List<TiendaHub> _mapearTiendas(Object? crudo) {
		if (crudo is! List<Object?>) {
			return const [];
		}
		final tiendas = <TiendaHub>[];
		for (final item in crudo) {
			if (item is! Map<String, Object?>) {
				continue;
			}
			final id = item['id'] as String? ?? '';
			if (id.isEmpty) {
				continue;
			}
			tiendas.add(
				TiendaHub(
					id: id,
					nombre: item['nombre'] as String? ?? '',
					direccion: item['direccion'] as String? ?? '',
					activa: item['activa'] as bool? ?? true,
				),
			);
		}
		return tiendas;
	}

	/// Verifica disponibilidad del hub.
	///
	/// Retorna verdadero si /v1/health responde ok.
	Future<bool> verificarSalud() async {
		final uri = Uri.parse('$_urlBase/v1/health');
		try {
			final respuesta = await _clienteHttp
				.get(uri, headers: _construirCabeceras())
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
			return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
		} on Object {
			return false;
		}
	}

	/// Lista tiendas activas del hub (una base por despliegue).
	Future<List<TiendaHub>> obtenerTiendasPorTenant([String tenantId = '']) async {
		final uri = Uri.parse('$_urlBase/v1/stores').replace(
			queryParameters: tenantId.trim().isEmpty
				? null
				: {'tenantId': tenantId.trim()},
		);
		try {
			final respuesta = await _clienteHttp
				.get(uri, headers: _construirCabeceras())
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
			if (respuesta.statusCode != 200) {
				return const [];
			}
			final json = jsonDecode(respuesta.body) as Map<String, Object?>;
			return _mapearTiendas(json['tiendas']);
		} on Object {
			return const [];
		}
	}

	/// Ping silencioso con timeout largo (despierta Render free en segundo plano).
	Future<bool> mantenerHubVivo() async {
		final uri = Uri.parse('$_urlBase/v1/health');
		try {
			final respuesta = await _clienteHttp
				.get(uri, headers: _construirCabeceras())
				.timeout(const Duration(seconds: TIMEOUT_HUB_DESPERTAR_SEGUNDOS));
			return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
		} on Object {
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
	/// Retorna instancia de [SyncEvent] o null si el tipo es desconocido.
	SyncEvent? _deserializarEvento(Map<String, Object?> json) {
		final tipoNombre = json['type'] as String? ?? '';
		final TipoSyncEvento tipo;
		try {
			tipo = TipoSyncEvento.values.byName(tipoNombre);
		} on ArgumentError {
			return null;
		}
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
