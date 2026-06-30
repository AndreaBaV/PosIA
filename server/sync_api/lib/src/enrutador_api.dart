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
import 'almacen_usuarios_postgres.dart';
import 'evento_hub.dart';

/// Construye el enrutador REST sobre un [AlmacenEventos].
class EnrutadorApi {
	/// Crea enrutador con almacen y clave API opcional.
	///
	/// [almacen] Persistencia del log de eventos.
	/// [claveApi] Clave compartida; null desactiva autenticacion.
	EnrutadorApi({
		required AlmacenEventos almacen,
		AlmacenUsuariosPostgres? usuarios,
		String? claveApi,
	}) : _almacen = almacen,
	     _usuarios = usuarios,
	     _claveApi = claveApi;

	final AlmacenEventos _almacen;
	final AlmacenUsuariosPostgres? _usuarios;
	final String? _claveApi;

	/// Construye handler shelf con middleware y rutas v1.
	///
	/// Retorna handler listo para servir.
	Handler construirHandler() {
		final enrutador = Router()
			..get('/v1/health', _manejarHealth)
			..get('/v1/auth/preview', _manejarVistaPreviaAuth)
			..post('/v1/auth/login', _manejarLoginAuth)
			..get('/v1/stores', _manejarListarTiendas)
			..get('/v1/users', _manejarListarUsuarios)
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

	Future<Response> _manejarVistaPreviaAuth(Request solicitud) async {
		final almacen = _usuarios;
		if (almacen == null) {
			return _respuestaJson({'error': 'Auth no disponible sin Postgres'}, codigo: 503);
		}
		final codigo = solicitud.url.queryParameters['codigo'] ?? '';
		if (codigo.trim().isEmpty) {
			return _respuestaJson({'error': 'codigo es obligatorio'}, codigo: 400);
		}
		final perfil = await almacen.obtenerPerfilPorCodigo(codigo);
		if (perfil == null) {
			return _respuestaJson({'error': 'Usuario no encontrado'}, codigo: 404);
		}
		return _respuestaJson(perfil);
	}

	Future<Response> _manejarLoginAuth(Request solicitud) async {
		final almacen = _usuarios;
		if (almacen == null) {
			return _respuestaJson({'error': 'Auth no disponible sin Postgres'}, codigo: 503);
		}
		final Map<String, Object?> cuerpo;
		try {
			cuerpo = jsonDecode(await solicitud.readAsString()) as Map<String, Object?>;
		} on FormatException {
			return _respuestaJson({'error': 'JSON invalido'}, codigo: 400);
		}
		final codigo = cuerpo['codigo'] as String? ?? '';
		final pin = cuerpo['pin'] as String? ?? '';
		if (codigo.trim().isEmpty || pin.isEmpty) {
			return _respuestaJson({'error': 'codigo y pin son obligatorios'}, codigo: 400);
		}
		final resultado = await almacen.autenticar(
			codigo: codigo,
			pin: pin,
		);
		if (resultado == null) {
			return _respuestaJson({'error': 'Credenciales invalidas'}, codigo: 401);
		}
		final tiendas = await almacen.listarTiendasActivas();
		return _respuestaJson({...resultado, 'tiendas': tiendas});
	}

	Future<Response> _manejarListarTiendas(Request solicitud) async {
		final almacen = _usuarios;
		if (almacen == null) {
			return _respuestaJson({'error': 'Auth no disponible sin Postgres'}, codigo: 503);
		}
		final tiendas = await almacen.listarTiendasActivas();
		return _respuestaJson({'tiendas': tiendas});
	}

	Future<Response> _manejarListarUsuarios(Request solicitud) async {
		final almacen = _usuarios;
		if (almacen == null) {
			return _respuestaJson({'error': 'Auth no disponible sin Postgres'}, codigo: 503);
		}
		final usuarios = await almacen.listarUsuarios();
		return _respuestaJson({'usuarios': usuarios});
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
		final dispositivoId = cuerpo['deviceId'] as String? ?? '';
		final tiendaId = cuerpo['storeId'] as String? ?? '';
		final eventosCrudos = cuerpo['events'] as List<Object?>? ?? [];
		if (dispositivoId.isEmpty || tiendaId.isEmpty) {
			return _respuestaJson(
				{'error': 'deviceId y storeId son obligatorios'},
				codigo: 400,
			);
		}
		final eventos = eventosCrudos
			.whereType<Map<String, Object?>>()
			.map(
				(json) => EventoHub.desdeJsonLote(
					json,
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

	/// Entrega eventos posteriores a un cursor.
	///
	/// [solicitud] Solicitud con since y excludeDevice.
	/// Retorna eventos ordenados y ultimo seq del lote.
	Future<Response> _manejarConsultaEventos(Request solicitud) async {
		final parametros = solicitud.url.queryParameters;
		final desdeSeq = int.tryParse(parametros['since'] ?? '0') ?? 0;
		final excluirDispositivo = parametros['excludeDevice'];
		final eventos = await _almacen.obtenerDesde(
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
				final ruta = solicitud.requestedUri.path;
				if (ruta == '/v1/health' || ruta.endsWith('/v1/health')) {
					return siguiente(solicitud);
				}
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
