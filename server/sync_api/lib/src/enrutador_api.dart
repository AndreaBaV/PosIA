/// Rutas HTTP del hub de sincronizacion POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'almacen_eventos.dart';
import 'evento_hub.dart';

/// Construye el enrutador REST sobre un [AlmacenEventos].
class EnrutadorApi {
	/// Crea enrutador con almacen y clave API opcional.
	///
	/// [almacen] Persistencia del log de eventos.
	/// [claveApi] Clave compartida; null desactiva autenticacion.
	EnrutadorApi({
		required AlmacenEventos almacen,
		String? claveApi,
	}) : _almacen = almacen,
	     _claveApi = claveApi;

	final AlmacenEventos _almacen;
	final String? _claveApi;

	/// Construye handler shelf con middleware y rutas v1.
	///
	/// Retorna handler listo para servir.
	Handler construirHandler() {
		final enrutador = Router()
			..get('/v1/health', _manejarHealth)
			..post('/v1/events', _manejarEnvioEventos)
			..get('/v1/events', _manejarConsultaEventos);
		return const Pipeline()
			.addMiddleware(logRequests())
			.addMiddleware(_validarClaveApi())
			.addHandler(enrutador.call);
	}

	/// Responde estado de salud del servicio.
	///
	/// [solicitud] Solicitud HTTP entrante.
	/// Retorna 200 con estado ok.
	Future<Response> _manejarHealth(Request solicitud) async {
		return _respuestaJson({'status': 'ok'});
	}

	/// Recibe lote de eventos de un dispositivo.
	///
	/// [solicitud] Solicitud con cuerpo JSON del lote.
	/// Retorna cantidad aceptada o error de validacion.
	Future<Response> _manejarEnvioEventos(Request solicitud) async {
		final Map<String, Object?> cuerpo;
		try {
			cuerpo = jsonDecode(await solicitud.readAsString()) as Map<String, Object?>;
		} on FormatException {
			return _respuestaJson({'error': 'JSON invalido'}, codigo: 400);
		}
		final tenantId = cuerpo['tenantId'] as String? ?? '';
		final dispositivoId = cuerpo['deviceId'] as String? ?? '';
		final tiendaId = cuerpo['storeId'] as String? ?? '';
		final eventosCrudos = cuerpo['events'] as List<Object?>? ?? [];
		if (tenantId.isEmpty || dispositivoId.isEmpty || tiendaId.isEmpty) {
			return _respuestaJson(
				{'error': 'tenantId, deviceId y storeId son obligatorios'},
				codigo: 400,
			);
		}
		final eventos = eventosCrudos
			.whereType<Map<String, Object?>>()
			.map(
				(json) => EventoHub.desdeJsonLote(
					json,
					tenantId: tenantId,
					tiendaId: tiendaId,
					dispositivoId: dispositivoId,
				),
			)
			.where((evento) => evento.id.isNotEmpty && evento.tipo.isNotEmpty)
			.toList();
		final aceptados = await _almacen.guardarLote(eventos);
		return _respuestaJson({
			'accepted': aceptados,
			'received': eventos.length,
		});
	}

	/// Entrega eventos posteriores a un cursor para un tenant.
	///
	/// [solicitud] Solicitud con tenantId, since y excludeDevice.
	/// Retorna eventos ordenados y ultimo seq del lote.
	Future<Response> _manejarConsultaEventos(Request solicitud) async {
		final parametros = solicitud.url.queryParameters;
		final tenantId = parametros['tenantId'] ?? '';
		if (tenantId.isEmpty) {
			return _respuestaJson({'error': 'tenantId es obligatorio'}, codigo: 400);
		}
		final desdeSeq = int.tryParse(parametros['since'] ?? '0') ?? 0;
		final excluirDispositivo = parametros['excludeDevice'];
		final eventos = await _almacen.obtenerDesde(
			tenantId: tenantId,
			desdeSeq: desdeSeq,
			excluirDispositivoId: excluirDispositivo,
		);
		final ultimoSeq = eventos.isEmpty ? desdeSeq : eventos.last.seq;
		return _respuestaJson({
			'events': eventos.map((evento) => evento.aJson()).toList(),
			'lastSeq': ultimoSeq,
		});
	}

	/// Middleware que exige cabecera x-api-key cuando hay clave.
	///
	/// Retorna middleware de autenticacion simple.
	Middleware _validarClaveApi() {
		return (Handler siguiente) {
			return (Request solicitud) {
				final clave = _claveApi;
				if (clave == null || clave.isEmpty) {
					return siguiente(solicitud);
				}
				final recibida = solicitud.headers['x-api-key'] ?? '';
				if (recibida != clave) {
					return _respuestaJson({'error': 'Clave API invalida'}, codigo: 401);
				}
				return siguiente(solicitud);
			};
		};
	}

	/// Construye respuesta JSON con codigo indicado.
	///
	/// [cuerpo] Mapa a serializar.
	/// [codigo] Codigo HTTP de la respuesta.
	/// Retorna respuesta shelf.
	Response _respuestaJson(Map<String, Object?> cuerpo, {int codigo = 200}) {
		return Response(
			codigo,
			body: jsonEncode(cuerpo),
			headers: {'Content-Type': 'application/json'},
		);
	}
}
