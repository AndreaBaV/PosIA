/// Pruebas del cliente de subida de fotos de producto.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:test/test.dart';

void main() {
	test('sube la foto y retorna la URL publica', () async {
		final cliente = MockClient((request) async {
			expect(request.method, 'POST');
			expect(request.url.path, '/v1/admin/imagenes');
			expect(request.url.queryParameters['productoId'], 'prod-1');
			expect(request.headers['x-api-key'], 'clave-test');
			expect(request.headers['content-type'], 'image/jpeg');
			expect(request.bodyBytes, [1, 2, 3]);
			return http.Response(
				jsonEncode({'url': 'https://pub-test.r2.dev/productos/prod-1-123.jpg'}),
				200,
				headers: {'Content-Type': 'application/json'},
			);
		});
		final servicio = ServicioImagenesProducto(
			urlBase: 'https://tienda.test',
			claveApi: 'clave-test',
			clienteHttp: cliente,
		);

		final url = await servicio.subirFoto(
			productoId: 'prod-1',
			bytes: [1, 2, 3],
			tipo: TipoImagenProducto.jpeg,
		);

		expect(url, 'https://pub-test.r2.dev/productos/prod-1-123.jpg');
	});

	test('retorna null si el servidor rechaza la subida', () async {
		final cliente = MockClient((request) async {
			return http.Response('{"error":"Clave invalida"}', 401);
		});
		final servicio = ServicioImagenesProducto(
			urlBase: 'https://tienda.test',
			claveApi: 'clave-mala',
			clienteHttp: cliente,
		);

		final url = await servicio.subirFoto(
			productoId: 'prod-1',
			bytes: [1, 2, 3],
			tipo: TipoImagenProducto.png,
		);

		expect(url, isNull);
	});

	test('retorna null ante un error de red, sin lanzar', () async {
		final cliente = MockClient((request) async {
			throw http.ClientException('sin conexion');
		});
		final servicio = ServicioImagenesProducto(
			urlBase: 'https://tienda.test',
			claveApi: 'clave-test',
			clienteHttp: cliente,
		);

		final url = await servicio.subirFoto(
			productoId: 'prod-1',
			bytes: [1, 2, 3],
			tipo: TipoImagenProducto.webp,
		);

		expect(url, isNull);
	});

	test('no llama a la red si los bytes vienen vacios', () async {
		var llamadas = 0;
		final cliente = MockClient((request) async {
			llamadas++;
			return http.Response('{}', 200);
		});
		final servicio = ServicioImagenesProducto(
			urlBase: 'https://tienda.test',
			claveApi: 'clave-test',
			clienteHttp: cliente,
		);

		final url = await servicio.subirFoto(
			productoId: 'prod-1',
			bytes: const [],
			tipo: TipoImagenProducto.jpeg,
		);

		expect(url, isNull);
		expect(llamadas, 0);
	});
}
