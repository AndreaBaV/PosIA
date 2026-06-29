/// Punto de entrada del hub de sincronizacion POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:10:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:10:00 (UTC-6)
library;

import 'dart:convert';
import 'dart:io';

import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Arranca servidor HTTP segun variables de entorno o archivo `.env`.
///
/// DATABASE_URL: Postgres (Neon); si falta usa archivo local EVENTS_FILE.
/// API_KEY: clave compartida opcional para proteger endpoints.
/// PORT: puerto HTTP; default 8080.
Future<void> main() async {
	final config = await ConfigEntorno.cargar();
	config.validarProduccion();
	final almacen = _crearAlmacen(config.urlBaseDatos, config.rutaArchivoEventos);

	Handler? handlerCompleto;
	final servidor = await shelf_io.serve(
		(Request solicitud) => _enrutarSolicitud(solicitud, handlerCompleto),
		InternetAddress.anyIPv4,
		config.puerto,
	);
	stdout.writeln(
		'POSIA Sync API escuchando en puerto ${servidor.port} (inicializando almacen...)',
	);

	await almacen.inicializar();
	AlmacenUsuariosPostgres? usuarios;
	if (almacen is AlmacenEventosPostgres) {
		usuarios = await almacen.obtenerAlmacenUsuarios();
	}

	final enrutador = EnrutadorApi(
		almacen: almacen,
		usuarios: usuarios,
		claveApi: config.claveApi,
	);
	handlerCompleto = enrutador.construirHandler();

	final modo = config.urlBaseDatos == null ? 'archivo local' : 'Postgres (Neon)';
	stdout.writeln('POSIA Sync API listo (almacen: $modo)');
}

/// Atiende health de inmediato; el resto espera a que Postgres este listo.
Future<Response> _enrutarSolicitud(
	Request solicitud,
	Handler? handlerCompleto,
) async {
	final ruta = solicitud.requestedUri.path;
	final esHealth = ruta == '/v1/health' || ruta.endsWith('/v1/health');
	if (esHealth) {
		final listo = handlerCompleto != null;
		return Response(
			200,
			body: jsonEncode({'status': listo ? 'ok' : 'starting'}),
			headers: {'Content-Type': 'application/json'},
		);
	}
	final handler = handlerCompleto;
	if (handler == null) {
		return Response(
			503,
			body: jsonEncode({'error': 'Servicio iniciando'}),
			headers: {'Content-Type': 'application/json'},
		);
	}
	return handler(solicitud);
}

/// Selecciona almacen segun configuracion disponible.
///
/// [urlBaseDatos] URL Postgres o null.
/// [rutaArchivo] Ruta de archivo JSONL opcional.
/// Retorna almacen listo para inicializar.
AlmacenEventos _crearAlmacen(String? urlBaseDatos, String? rutaArchivo) {
	if (urlBaseDatos != null && urlBaseDatos.isNotEmpty) {
		return AlmacenEventosPostgres(urlConexion: urlBaseDatos);
	}
	return AlmacenEventosArchivo(
		rutaArchivo: rutaArchivo ?? 'posia_sync_events.jsonl',
	);
}
