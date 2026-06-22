/// Servidor HTTP local para el panel de administracion de tenants.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:posia_core/posia_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../repositorio_tenants.dart';
import '../servicio_provision_hub.dart';

/// API REST + HTML para gestionar el catalogo maestro.
class ServidorAdminWeb {
	ServidorAdminWeb({
		required RepositorioTenants repositorio,
		required String token,
		required int puerto,
		String? databaseUrl,
	}) : _repo = repositorio,
	     _token = token,
	     _puerto = puerto,
	     _databaseUrl = databaseUrl;

	final RepositorioTenants _repo;
	final String _token;
	final int _puerto;
	final String? _databaseUrl;
	HttpServer? _servidor;

	Future<void> arrancar() async {
		final router = Router()
			..get('/', _servirHtml)
			..get('/api/tenants', _listarTenants)
			..get('/api/tenants/<id>', _detalleTenant)
			..post('/api/tenants', _crearTenant)
			..post('/api/tenants/<id>/tiendas', _agregarTienda)
			..post('/api/tenants/<id>/usuarios', _agregarUsuario)
			..post('/api/tenants/<id>/provision', _provisionar)
			..post('/api/usuarios/<id>/reset-pin', _resetearPin);

		final handler = Pipeline()
			.addMiddleware(_middlewareAuth)
			.addMiddleware(logRequests())
			.addHandler(router.call);

		_servidor = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _puerto);
	}

	Future<void> detener() async {
		await _servidor?.close(force: true);
		_servidor = null;
	}

	Middleware get _middlewareAuth {
		return (Handler inner) {
			return (Request request) {
				if (request.requestedUri.path == '/') {
					return inner(request);
				}
				final header = request.headers['x-admin-token'];
				final query = request.url.queryParameters['token'];
				if (header == _token || query == _token) {
					return inner(request);
				}
				return Response.forbidden(
					jsonEncode({'error': 'Token invalido'}),
					headers: {'content-type': 'application/json'},
				);
			};
		};
	}

	Future<Response> _servirHtml(Request request) async {
		final ruta = p.join(
			p.dirname(Platform.script.toFilePath()),
			'..',
			'web',
			'admin.html',
		);
		final html = await File(ruta).readAsString();
		return Response.ok(
			html,
			headers: {'content-type': 'text/html; charset=utf-8'},
		);
	}

	Future<Response> _listarTenants(Request request) async {
		final tenants = await _repo.listarTenants();
		return _json(tenants.map(_mapearTenant).toList());
	}

	Future<Response> _detalleTenant(Request request, String id) async {
		final tenant = await _repo.obtenerTenant(id);
		if (tenant == null) {
			return _json({'error': 'Tenant no encontrado'}, status: 404);
		}
		final tiendas = await _repo.listarTiendas(id);
		final usuarios = await _repo.listarUsuarios(id);
		return _json({
			'tenant': _mapearTenant(tenant),
			'tiendas': tiendas.map(_mapearTienda).toList(),
			'usuarios': usuarios.map(_mapearUsuario).toList(),
		});
	}

	Future<Response> _crearTenant(Request request) async {
		final cuerpo = await _leerJson(request);
		final nombre = (cuerpo['nombre'] as String? ?? '').trim();
		if (nombre.isEmpty) {
			return _json({'error': 'nombre es obligatorio'}, status: 400);
		}
		final tenant = await _repo.crearTenant(
			nombre: nombre,
			contacto: cuerpo['contacto'] as String? ?? '',
			email: cuerpo['email'] as String? ?? '',
			telefono: cuerpo['telefono'] as String? ?? '',
			notas: cuerpo['notas'] as String? ?? '',
			maxUsuarios: _entero(cuerpo['maxUsuarios'], 15),
			maxTiendas: _entero(cuerpo['maxTiendas'], 5),
		);
		return _json(_mapearTenant(tenant), status: 201);
	}

	Future<Response> _agregarTienda(Request request, String tenantId) async {
		final cuerpo = await _leerJson(request);
		final nombre = (cuerpo['nombre'] as String? ?? '').trim();
		if (nombre.isEmpty) {
			return _json({'error': 'nombre es obligatorio'}, status: 400);
		}
		final tienda = await _repo.agregarTienda(
			tenantId: tenantId,
			nombre: nombre,
			direccion: cuerpo['direccion'] as String? ?? '',
		);
		return _json(_mapearTienda(tienda), status: 201);
	}

	Future<Response> _agregarUsuario(Request request, String tenantId) async {
		final cuerpo = await _leerJson(request);
		final nombre = (cuerpo['nombre'] as String? ?? '').trim();
		final pin = (cuerpo['pin'] as String? ?? '').trim();
		final rol = cuerpo['rol'] as String? ?? 'administrador';
		if (nombre.isEmpty) {
			return _json({'error': 'nombre es obligatorio'}, status: 400);
		}
		if (pin.length != LONGITUD_PIN_ADMIN) {
			return _json(
				{'error': 'PIN debe tener $LONGITUD_PIN_ADMIN digitos'},
				status: 400,
			);
		}
		var codigo = (cuerpo['codigo'] as String? ?? '').trim();
		if (codigo.isEmpty) {
			codigo = await _repo.generarCodigoSiguiente(tenantId, rol);
		}
		try {
			final usuario = await _repo.agregarUsuario(
				tenantId: tenantId,
				nombre: nombre,
				codigo: codigo,
				pinPlano: pin,
				rol: rol,
				tiendaId: cuerpo['tiendaId'] as String?,
			);
			return _json(_mapearUsuario(usuario), status: 201);
		} on StateError catch (error) {
			return _json({'error': error.message}, status: 400);
		}
	}

	Future<Response> _provisionar(Request request, String tenantId) async {
		final url = _databaseUrl;
		if (url == null || url.isEmpty) {
			return _json({'error': 'DATABASE_URL no configurada'}, status: 503);
		}
		final servicio = ServicioProvisionHub(urlConexion: url, repositorio: _repo);
		try {
			final resultado = await servicio.provisionarTenant(tenantId);
			return _json({
				'tenantId': resultado.tenantId,
				'tiendas': resultado.tiendas,
				'usuarios': resultado.usuarios,
			});
		} on StateError catch (error) {
			return _json({'error': error.message}, status: 400);
		} finally {
			await servicio.cerrar();
		}
	}

	Future<Response> _resetearPin(Request request, String usuarioId) async {
		final cuerpo = await _leerJson(request);
		final pin = (cuerpo['pin'] as String? ?? '').trim();
		if (pin.length != LONGITUD_PIN_ADMIN) {
			return _json(
				{'error': 'PIN debe tener $LONGITUD_PIN_ADMIN digitos'},
				status: 400,
			);
		}
		final usuario = await _repo.obtenerUsuario(usuarioId);
		if (usuario == null) {
			return _json({'error': 'Usuario no encontrado'}, status: 404);
		}
		await _repo.actualizarPinUsuario(usuarioId, pin);
		if (usuario.provisionadoEnHub) {
			final url = _databaseUrl;
			if (url == null || url.isEmpty) {
				return _json(
					{
						'ok': true,
						'aviso': 'PIN local actualizado; Neon sin DATABASE_URL',
					},
				);
			}
			final servicio = ServicioProvisionHub(urlConexion: url);
			try {
				await servicio.actualizarPinUsuario(
					usuarioId: usuarioId,
					pinPlano: pin,
				);
			} finally {
				await servicio.cerrar();
			}
		}
		return _json({'ok': true, 'usuarioId': usuarioId});
	}

	Map<String, Object?> _mapearTenant(dynamic tenant) {
		return {
			'id': tenant.id,
			'nombre': tenant.nombre,
			'contacto': tenant.contacto,
			'email': tenant.email,
			'telefono': tenant.telefono,
			'activo': tenant.activo,
			'maxUsuarios': tenant.maxUsuarios,
			'maxTiendas': tenant.maxTiendas,
			'notas': tenant.notas,
			'creadoEn': tenant.creadoEn,
			'provisionadoEnHub': tenant.provisionadoEnHub,
			'provisionadoEn': tenant.provisionadoEn,
		};
	}

	Map<String, Object?> _mapearTienda(dynamic tienda) {
		return {
			'id': tienda.id,
			'tenantId': tienda.tenantId,
			'nombre': tienda.nombre,
			'direccion': tienda.direccion,
			'activa': tienda.activa,
		};
	}

	Map<String, Object?> _mapearUsuario(dynamic usuario) {
		return {
			'id': usuario.id,
			'tenantId': usuario.tenantId,
			'nombre': usuario.nombre,
			'codigo': usuario.codigo,
			'rol': usuario.rol,
			'tiendaId': usuario.tiendaId,
			'activo': usuario.activo,
			'provisionadoEnHub': usuario.provisionadoEnHub,
		};
	}

	Future<Map<String, Object?>> _leerJson(Request request) async {
		final cuerpo = await request.readAsString();
		if (cuerpo.isEmpty) {
			return {};
		}
		final decodificado = jsonDecode(cuerpo);
		if (decodificado is Map<String, dynamic>) {
			return decodificado;
		}
		if (decodificado is Map) {
			return decodificado.map((k, v) => MapEntry(k.toString(), v));
		}
		return {};
	}

	int _entero(Object? valor, int defecto) {
		if (valor is int) {
			return valor;
		}
		if (valor is String) {
			return int.tryParse(valor) ?? defecto;
		}
		return defecto;
	}

	Response _json(Object? cuerpo, {int status = 200}) {
		return Response(
			status,
			body: jsonEncode(cuerpo),
			headers: {'content-type': 'application/json; charset=utf-8'},
		);
	}
}
