/// Cliente HTTP para sincronizacion con hub central.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:posia_core/posia_core.dart';

import 'auth_hub.dart';

class ResultadoPullHub {
	const ResultadoPullHub({
		required this.eventos,
		required this.ultimoSeq,
		required this.exitoso,
	});

	final List<SyncEvent> eventos;
	final int ultimoSeq;
	final bool exitoso;
}

class HubSyncClient {
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

	Future<bool> enviarEventos({
		required String dispositivoId,
		required String tiendaId,
		required List<SyncEvent> eventos,
	}) async {
		final uri = Uri.parse('$_urlBase/v1/events');
		final cuerpo = jsonEncode({
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

	Future<ResultadoPullHub> obtenerEventos({
		required int desdeSeq,
		String? excluirDispositivoId,
	}) async {
		final uri = Uri.parse('$_urlBase/v1/events').replace(
			queryParameters: {
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

	/// Indica si el hub tiene Postgres y puede autenticar usuarios.
	Future<bool> tieneAuthHub() async {
		final uri = Uri.parse('$_urlBase/v1/auth/preview').replace(
			queryParameters: {'codigo': '__posia_probe__'},
		);
		try {
			final respuesta = await _clienteHttp
				.get(uri, headers: _construirCabeceras())
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
			return respuesta.statusCode != 503;
		} on Object {
			return false;
		}
	}

	Future<PerfilUsuarioHub?> obtenerPerfilUsuario(String codigo) async {
		final limpio = codigo.trim();
		if (limpio.isEmpty) {
			return null;
		}
		final uri = Uri.parse('$_urlBase/v1/auth/preview').replace(
			queryParameters: {'codigo': limpio},
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

	Future<RespuestaLoginHub?> iniciarSesion({
		required String codigo,
		required String pin,
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
					body: jsonEncode({'codigo': limpio, 'pin': pin}),
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
			final pinCredencial = json['pinCredencial'] as String? ?? '';
			if (pinCredencial.isEmpty) {
				return null;
			}
			return RespuestaLoginHub(
				perfil: perfil,
				pinCredencial: pinCredencial,
				creadoEn: json['creadoEn'] as String? ?? '',
				actualizadoEn: json['actualizadoEn'] as String? ?? '',
				tiendas: _mapearTiendas(json['tiendas']),
			);
		} on Object {
			return null;
		}
	}

	PerfilUsuarioHub? _mapearPerfil(Map<String, Object?> json) {
		final id = json['id'] as String? ?? '';
		if (id.isEmpty) {
			return null;
		}
		return PerfilUsuarioHub(
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

	Future<List<TiendaHub>> obtenerTiendas() async {
		final uri = Uri.parse('$_urlBase/v1/stores');
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

	Map<String, String> _construirCabeceras() {
		final clave = _claveApi;
		return {
			'Content-Type': 'application/json',
			if (clave != null && clave.isNotEmpty) 'x-api-key': clave,
		};
	}

	Map<String, Object?> _serializarEvento(SyncEvent evento) {
		return {
			'id': evento.id,
			'type': evento.tipo.name,
			'payload': evento.payload,
			'createdAt': evento.creadoEn.toIso8601String(),
		};
	}

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
