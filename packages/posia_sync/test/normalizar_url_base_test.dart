/// Regresion: la URL del hub capturada con `/v1` no debe duplicar el prefijo.
///
/// Todas las rutas de HubSyncClient concatenan `/v1/...`. Con la base guardada
/// como `https://hub/v1` quedaba `/v1/v1/auth/preview`, el hub devolvia 404 en
/// todas las llamadas y la app lo reportaba como "usuario no encontrado".
library;

import 'package:posia_sync/posia_sync.dart';
import 'package:test/test.dart';

void main() {
	test('normalizarUrlBase quita el /v1 y las barras sobrantes', () {
		const esperado = 'https://hub.posia.mx';
		for (final entrada in [
			'https://hub.posia.mx',
			'https://hub.posia.mx/',
			'https://hub.posia.mx/v1',
			'https://hub.posia.mx/v1/',
			'https://hub.posia.mx/V1',
			'  https://hub.posia.mx/v1//  ',
		]) {
			expect(
				HubSyncClient.normalizarUrlBase(entrada),
				esperado,
				reason: 'entrada: "$entrada"',
			);
		}
	});

	test('no recorta un host que termina en v1 sin ser prefijo de ruta', () {
		expect(
			HubSyncClient.normalizarUrlBase('https://api-v1.posia.mx'),
			'https://api-v1.posia.mx',
		);
	});

	test('la url efectiva del cliente ya viene normalizada', () {
		final cliente = HubSyncClient(urlBase: 'https://hub.posia.mx/v1/');
		expect(cliente.urlBase, 'https://hub.posia.mx');
	});
}
