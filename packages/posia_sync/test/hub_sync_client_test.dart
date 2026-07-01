/// Pruebas del cliente HTTP del hub.
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:test/test.dart';

void main() {
	test('obtenerTiendas decodifica lista JSON del hub', () async {
		final cliente = MockClient((request) async {
			expect(request.headers['x-api-key'], 'clave-test');
			return http.Response(
				'''
{
  "tiendas": [
    {"id": "tienda-centro", "nombre": "Tienda Centro", "direccion": "Av. 1", "activa": true},
    {"id": "tienda-norte", "nombre": "Tienda Norte", "direccion": "Av. 2", "activa": 1}
  ]
}
''',
				200,
				headers: {'Content-Type': 'application/json'},
			);
		});
		final hub = HubSyncClient(
			urlBase: 'https://hub.test',
			claveApi: 'clave-test',
			clienteHttp: cliente,
		);
		final tiendas = await hub.obtenerTiendas();
		expect(tiendas.length, 2);
		expect(tiendas.first.id, 'tienda-centro');
		expect(tiendas.last.activa, isTrue);
	});

	test('iniciarSesion incluye tiendas en la respuesta', () async {
		final cliente = MockClient((request) async {
			return http.Response(
				'''
{
  "id": "usr-1",
  "nombre": "Admin",
  "codigo": "ADMIN",
  "rol": "administrador",
  "activo": true,
  "pinCredencial": "abc123",
  "creadoEn": "2026-01-01T00:00:00Z",
  "actualizadoEn": "2026-01-01T00:00:00Z",
  "tiendas": [
    {"id": "tienda-sur", "nombre": "Sur", "direccion": "Av. 3", "activa": true}
  ]
}
''',
				200,
				headers: {'Content-Type': 'application/json'},
			);
		});
		final hub = HubSyncClient(
			urlBase: 'https://hub.test',
			claveApi: 'clave-test',
			clienteHttp: cliente,
		);
		final login = await hub.iniciarSesion(codigo: 'ADMIN', pin: '1234');
		expect(login, isNotNull);
		expect(login!.tiendas.length, 1);
		expect(login.tiendas.first.id, 'tienda-sur');
	});

	group('consultarPerfil', () {
		test('devuelve encontrado con 200', () async {
			final cliente = MockClient((request) async {
				return http.Response(
					'''
{"id":"usr-1","nombre":"Ana","codigo":"1001","rol":"administrador","activo":true}
''',
					200,
					headers: {'Content-Type': 'application/json'},
				);
			});
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final resultado = await hub.consultarPerfil('1001');
			expect(resultado.exitoso, isTrue);
			expect(resultado.perfil?.id, 'usr-1');
			expect(resultado.estado, EstadoAuthHub.disponible);
		});

		test('404 se traduce a noEncontrado definitivo', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Usuario no encontrado"}', 404),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final resultado = await hub.consultarPerfil('9999');
			expect(resultado.definitivoNoEncontrado, isTrue);
			expect(resultado.esRespuestaDefinitiva, isTrue);
			expect(resultado.perfil, isNull);
		});

		test('401 se traduce a apiKeyInvalida (no a usuario no encontrado)', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Clave API invalida"}', 401),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final resultado = await hub.consultarPerfil('1001');
			expect(resultado.exitoso, isFalse);
			expect(resultado.definitivoNoEncontrado, isFalse);
			expect(resultado.estado, EstadoAuthHub.apiKeyInvalida);
		});

		test('503 se traduce a hub sin Postgres', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"sin postgres"}', 503),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final resultado = await hub.consultarPerfil('1001');
			expect(resultado.estado, EstadoAuthHub.sinPostgres);
			expect(resultado.definitivoNoEncontrado, isFalse);
		});

		test('timeout o error de red se traduce a inalcanzable, NO a noEncontrado', () async {
			final cliente = MockClient((request) async {
				throw TimeoutException('simulado');
			});
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final resultado = await hub.consultarPerfil('1001');
			expect(resultado.exitoso, isFalse);
			expect(resultado.definitivoNoEncontrado, isFalse);
			expect(resultado.estado, EstadoAuthHub.inalcanzable);
		});

		test('500 se traduce a inalcanzable, no a noEncontrado', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"interno"}', 500),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final resultado = await hub.consultarPerfil('1001');
			expect(resultado.definitivoNoEncontrado, isFalse);
			expect(resultado.estado, EstadoAuthHub.inalcanzable);
		});
	});

	group('intentarLogin', () {
		test('200 con pinCredencial se traduce a exito', () async {
			final cliente = MockClient((request) async {
				return http.Response(
					'''
{"id":"u1","nombre":"Ana","codigo":"1001","rol":"administrador","activo":true,"pinCredencial":"hash","creadoEn":"2026-01-01","actualizadoEn":"2026-01-01"}
''',
					200,
					headers: {'Content-Type': 'application/json'},
				);
			});
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final intento = await hub.intentarLogin(codigo: '1001', pin: '1234');
			expect(intento.exitoso, isTrue);
			expect(intento.login?.pinCredencial, 'hash');
		});

		test('401 con cuerpo "Credenciales" se traduce a credencialesInvalidas', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Credenciales invalidas"}', 401),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final intento = await hub.intentarLogin(codigo: '1001', pin: '1234');
			expect(intento.credencialesInvalidas, isTrue);
			expect(intento.esRespuestaDefinitiva, isTrue);
			expect(intento.estado, EstadoAuthHub.disponible);
		});

		test('401 con cuerpo "Clave API" se traduce a apiKeyInvalida', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Clave API invalida"}', 401),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final intento = await hub.intentarLogin(codigo: '1001', pin: '1234');
			expect(intento.credencialesInvalidas, isFalse);
			expect(intento.estado, EstadoAuthHub.apiKeyInvalida);
		});

		test('timeout NO se traduce a credencialesInvalidas', () async {
			final cliente = MockClient((request) async {
				throw TimeoutException('simulado');
			});
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			final intento = await hub.intentarLogin(codigo: '1001', pin: '1234');
			expect(intento.credencialesInvalidas, isFalse);
			expect(intento.estado, EstadoAuthHub.inalcanzable);
		});
	});

	group('verificarEstadoAuth', () {
		test('404 (probe no existe) se traduce a disponible', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Usuario no encontrado"}', 404),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			expect(await hub.verificarEstadoAuth(), EstadoAuthHub.disponible);
		});

		test('401 se traduce a apiKeyInvalida', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Clave API invalida"}', 401),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			expect(await hub.verificarEstadoAuth(), EstadoAuthHub.apiKeyInvalida);
		});

		test('503 se traduce a sinPostgres', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"sin postgres"}', 503),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			expect(await hub.verificarEstadoAuth(), EstadoAuthHub.sinPostgres);
		});

		test('tieneAuthHub sigue devolviendo true solo si estado disponible', () async {
			final cliente = MockClient(
				(request) async => http.Response('{"error":"Clave API invalida"}', 401),
			);
			final hub = HubSyncClient(urlBase: 'https://hub.test', clienteHttp: cliente);
			expect(await hub.tieneAuthHub(), isFalse);
		});
	});

	test('obtenerUsuarios decodifica lista JSON del hub', () async {
		final cliente = MockClient((request) async {
			expect(request.url.path, '/v1/users');
			return http.Response(
				'''
{
  "usuarios": [
    {
      "id": "usr-2",
      "nombre": "Maria",
      "codigo": "EMP001",
      "rol": "empleado",
      "tiendaId": "tienda-sur",
      "activo": true,
      "pinCredencial": "hash123",
      "creadoEn": "2026-01-01T00:00:00Z",
      "actualizadoEn": "2026-01-02T00:00:00Z"
    }
  ]
}
''',
				200,
				headers: {'Content-Type': 'application/json'},
			);
		});
		final hub = HubSyncClient(
			urlBase: 'https://hub.test',
			claveApi: 'clave-test',
			clienteHttp: cliente,
		);
		final usuarios = await hub.obtenerUsuarios();
		expect(usuarios.length, 1);
		expect(usuarios.first.codigo, 'EMP001');
		expect(usuarios.first.pinCredencial, 'hash123');
	});
}
