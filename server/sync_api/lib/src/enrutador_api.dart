/// Rutas HTTP del hub de sincronizacion POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'almacen_eventos.dart';
import 'almacen_eventos_postgres.dart';
import 'almacen_usuarios_postgres.dart';
import 'catalogo_actualizaciones_app.dart';
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
		CatalogoActualizacionesApp? actualizaciones,
	}) : _almacen = almacen,
	     _usuarios = usuarios,
	     _claveApi = claveApi,
	     _actualizaciones = actualizaciones ?? CatalogoActualizacionesApp();

	final AlmacenEventos _almacen;
	final AlmacenUsuariosPostgres? _usuarios;
	final String? _claveApi;
	final CatalogoActualizacionesApp _actualizaciones;

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
			..get('/v1/custom-roles', _manejarListarRolesPersonalizados)
			..post('/v1/events', _manejarEnvioEventos)
			..get('/v1/events/head', _manejarCabezaEventos)
			..get('/v1/events', _manejarConsultaEventos)
			..get('/v1/catalog/audit', _manejarAuditoriaCatalogo)
			..get('/v1/catalog/events', _manejarCatalogoCompacto)
			..get('/v1/attendance/challenge', _manejarDesafioAsistenciaActivo)
			..get('/v1/app/update', _manejarActualizacionApp)
			..get('/v1/app/files/<nombre>', _manejarArchivoActualizacion)
			..get('/v1/db/usage', _manejarUsoBase)
			..get('/v1/db/export', _manejarExportarHistorial)
			..post('/v1/db/purge', _manejarPurgarHistorial)
			..post('/v1/db/compact', _manejarCompactarCatalogo);
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

	Future<Response> _manejarListarRolesPersonalizados(Request solicitud) async {
		final almacen = _usuarios;
		if (almacen == null) {
			return _respuestaJson({'error': 'Auth no disponible sin Postgres'}, codigo: 503);
		}
		final roles = await almacen.listarRolesPersonalizados();
		return _respuestaJson({'roles': roles});
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

	/// Entrega conteo y huella del catalogo activo en Neon.
	///
	/// [solicitud] Solicitud HTTP entrante (sin parametros).
	/// Retorna 503 si el almacen no es Postgres (no hay tabla `products` que
	/// auditar; el modo archivo es solo para desarrollo sin Neon).
	Future<Response> _manejarAuditoriaCatalogo(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Auditoria no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final huella = await almacen.auditarCatalogo();
		return _respuestaJson(huella.aJson());
	}

	/// Entrega solo los eventos que definen el catalogo (productos,
	/// categorias, presentaciones, tiendas, proveedores, almacenes, variantes,
	/// clientes, roles), deduplicados al mas reciente por entidad.
	///
	/// [solicitud] Solicitud HTTP entrante (sin parametros).
	/// Retorna el mismo formato que `/v1/events` (`events`/`lastSeq`) para que
	/// el cliente reutilice su decodificador habitual. 503 si el almacen no es
	/// Postgres.
	Future<Response> _manejarCatalogoCompacto(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Catalogo compacto no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final eventos = await almacen.obtenerCatalogoCompacto();
		final ultimoSeq = eventos.isEmpty
			? 0
			: eventos.map((e) => e.seq).reduce((a, b) => a > b ? a : b);
		return _respuestaJson({
			'events': eventos.map((evento) => evento.aJson()).toList(),
			'lastSeq': ultimoSeq,
		});
	}

	/// Informa el ultimo seq del log sin transferir eventos.
	///
	/// Un dispositivo compara este valor con su cursor para saber si esta al
	/// dia. Sin esta ruta, "faltan productos" solo se podia diagnosticar
	/// descargando paginas completas del historial.
	Future<Response> _manejarCabezaEventos(Request solicitud) async {
		return _respuestaJson({'lastSeq': await _almacen.obtenerUltimoSeq()});
	}

	/// Entrega el desafio PIN activo de una tienda (sin recorrer el log).
	Future<Response> _manejarDesafioAsistenciaActivo(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Asistencia no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final tiendaId = solicitud.url.queryParameters['storeId'] ?? '';
		if (tiendaId.trim().isEmpty) {
			return _respuestaJson({'error': 'storeId es obligatorio'}, codigo: 400);
		}
		final desafio = await almacen.obtenerDesafioAsistenciaActivo(tiendaId);
		if (desafio == null) {
			return _respuestaJson({'challenge': null});
		}
		return _respuestaJson({'challenge': desafio});
	}

	Future<Response> _manejarActualizacionApp(Request solicitud) async {
		final plataforma =
			(solicitud.url.queryParameters['plataforma'] ?? '').trim().toLowerCase();
		if (plataforma.isEmpty) {
			return _respuestaJson(
				{'error': 'plataforma es obligatorio (windows, android, ios)'},
				codigo: 400,
			);
		}
		if (!_actualizaciones.estaConfigurado) {
			return _respuestaJson({'error': 'Sin actualizaciones publicadas'}, codigo: 404);
		}
		final origen =
			'${solicitud.requestedUri.scheme}://${solicitud.requestedUri.authority}';
		final manifiesto = _actualizaciones.paraPlataforma(
			plataforma: plataforma,
			origenPublico: origen,
		);
		if (manifiesto == null) {
			return _respuestaJson({'error': 'Sin actualizaciones publicadas'}, codigo: 404);
		}
		return _respuestaJson(manifiesto.aJson());
	}

	Future<Response> _manejarArchivoActualizacion(
		Request solicitud,
		String nombre,
	) async {
		final decodificado = Uri.decodeComponent(nombre);
		final archivo = _actualizaciones.archivoLocal(decodificado);
		if (archivo == null) {
			return _respuestaJson({'error': 'Archivo no encontrado'}, codigo: 404);
		}
		final mime = _mimeArchivo(decodificado);
		return Response.ok(
			archivo.openRead(),
			headers: {
				'Content-Type': mime,
				'Content-Length': '${await archivo.length()}',
				'Content-Disposition': 'attachment; filename="$decodificado"',
			},
		);
	}

	String _mimeArchivo(String nombre) {
		final bajo = nombre.toLowerCase();
		if (bajo.endsWith('.apk')) {
			return 'application/vnd.android.package-archive';
		}
		if (bajo.endsWith('.zip')) {
			return 'application/zip';
		}
		if (bajo.endsWith('.exe') || bajo.endsWith('.msi')) {
			return 'application/octet-stream';
		}
		return 'application/octet-stream';
	}

	Future<Response> _manejarUsoBase(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Gestion de base no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final uso = await almacen.auditarUsoBase();
		return _respuestaJson(uso.aJson());
	}

	Future<Response> _manejarExportarHistorial(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Gestion de base no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final parametros = solicitud.url.queryParameters;
		final antesDe = DateTime.tryParse(parametros['antesDe'] ?? '');
		if (antesDe == null) {
			return _respuestaJson(
				{'error': 'antesDe es obligatorio (ISO-8601)'},
				codigo: 400,
			);
		}
		final grupos = (parametros['grupos'] ?? '')
			.split(',')
			.map((g) => g.trim())
			.where((g) => g.isNotEmpty)
			.toList();
		if (grupos.isEmpty) {
			return _respuestaJson(
				{'error': 'grupos es obligatorio'},
				codigo: 400,
			);
		}
		final resultado = await almacen.exportarHistorial(
			antesDe: antesDe.toUtc(),
			grupos: grupos,
		);
		return _respuestaJson(resultado.aJson());
	}

	Future<Response> _manejarPurgarHistorial(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Gestion de base no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final Map<String, Object?> cuerpo;
		try {
			final crudo = jsonDecode(await solicitud.readAsString());
			if (crudo is! Map) {
				return _respuestaJson({'error': 'JSON invalido'}, codigo: 400);
			}
			cuerpo = Map<String, Object?>.from(crudo);
		} on FormatException {
			return _respuestaJson({'error': 'JSON invalido'}, codigo: 400);
		}
		if (cuerpo['confirmar'] != true) {
			return _respuestaJson(
				{'error': 'confirmar debe ser true'},
				codigo: 400,
			);
		}
		final antesDe = DateTime.tryParse(cuerpo['antesDe'] as String? ?? '');
		if (antesDe == null) {
			return _respuestaJson(
				{'error': 'antesDe es obligatorio (ISO-8601)'},
				codigo: 400,
			);
		}
		final gruposCrudos = cuerpo['grupos'];
		final grupos = gruposCrudos is List
			? gruposCrudos.map((g) => '$g').where((g) => g.isNotEmpty).toList()
			: <String>[];
		if (grupos.isEmpty) {
			return _respuestaJson({'error': 'grupos es obligatorio'}, codigo: 400);
		}
		final resultado = await almacen.purgarHistorial(
			antesDe: antesDe.toUtc(),
			grupos: grupos,
		);
		return _respuestaJson(resultado.aJson());
	}

	Future<Response> _manejarCompactarCatalogo(Request solicitud) async {
		final almacen = _almacen;
		if (almacen is! AlmacenEventosPostgres) {
			return _respuestaJson(
				{'error': 'Gestion de base no disponible sin Postgres'},
				codigo: 503,
			);
		}
		final compactados = await almacen.compactarCatalogo();
		return _respuestaJson({'eventosCompactados': compactados});
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
