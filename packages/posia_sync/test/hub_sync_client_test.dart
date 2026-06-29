/// Pruebas del cliente HTTP del hub.
library;

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
    {"id": "tienda-norte", "nombre": "Tienda Norte", "direccion": "Av. 2", "activa": true}
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
		expect(tiendas.first.nombre, 'Tienda Centro');
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
}
