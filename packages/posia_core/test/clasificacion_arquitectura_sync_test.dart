import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('ClasificacionArquitecturaSync', () {
		test('todo TipoSyncEvento tiene contrato', () {
			expect(ClasificacionArquitecturaSync.eventosSinContrato(), isEmpty);
		});

		test('mapa derivado coincide con clasificacion A/B/C', () {
			expect(ClasificacionArquitecturaSync.inconsistenciasConMapa(), isEmpty);
		});

		test('productPresentationUpserted es legacy ignorado', () {
			final c = ClasificacionArquitecturaSync.contratoDe(
				TipoSyncEvento.productPresentationUpserted,
			);
			expect(c.politica, PoliticaEventoSync.legacyIgnorado);
			expect(c.requiereProyector, isFalse);
		});

		test('presentationTypeUpserted es activo', () {
			final c = ClasificacionArquitecturaSync.contratoDe(
				TipoSyncEvento.presentationTypeUpserted,
			);
			expect(c.politica, PoliticaEventoSync.activo);
		});

		test('pharmacy_lots y vendedores son solo local', () {
			final locales = ClasificacionArquitecturaSync.tablasDeClase(
				ClaseTablaSync.soloLocal,
			).map((t) => t.sqlite).toSet();
			expect(locales, containsAll(['pharmacy_lots', 'vendedores']));
		});

		test('sync_events es solo hub', () {
			final hubs = ClasificacionArquitecturaSync.tablasDeClase(
				ClaseTablaSync.soloHub,
			).map((t) => t.nombreNeon).toSet();
			expect(hubs, containsAll(['sync_events', 'schema_meta']));
		});
	});
}
