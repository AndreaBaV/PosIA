import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:test/test.dart';

void main() {
	test('paraPlataforma reescribe archivo relativo a URL del hub', () {
		final catalogo = CatalogoActualizacionesApp(
			manifiesto: {
				'version': '2.0.1',
				'build': 151,
				'plataformas': {
					'windows': {'archivo': 'POSIA-windows.zip'},
				},
			},
		);
		final manifiesto = catalogo.paraPlataforma(
			plataforma: 'windows',
			origenPublico: 'https://hub.posia.mx',
		);
		expect(manifiesto, isNotNull);
		expect(manifiesto!.version, '2.0.1');
		expect(
			manifiesto.paquete!.url,
			'https://hub.posia.mx/v1/app/files/POSIA-windows.zip',
		);
	});

	test('archivoLocal rechaza recorridos de ruta', () {
		final catalogo = CatalogoActualizacionesApp(
			manifiesto: {
				'version': '2.0.1',
				'plataformas': {
					'windows': {'archivo': 'POSIA-windows.zip'},
				},
			},
		);
		expect(catalogo.archivoLocal('../secret.exe'), isNull);
		expect(catalogo.archivoLocal('foo/POSIA-windows.zip'), isNull);
	});
}
