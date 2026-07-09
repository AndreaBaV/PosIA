/// Tests de geocerca y stock negativo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('geolocalizacion_util', () {
		test('mismo punto tiene distancia cero', () {
			expect(
				distanciaMetros(lat1: 19.43, lon1: -99.13, lat2: 19.43, lon2: -99.13),
				0,
			);
		});

		test('dentroDeGeocerca acepta punto en centro', () {
			expect(
				dentroDeGeocerca(
					latitud: 19.43,
					longitud: -99.13,
					latCentro: 19.43,
					lonCentro: -99.13,
					radioMetros: 150,
				),
				isTrue,
			);
		});
	});

	group('Producto.permiteStockNegativo', () {
		test('default es true', () {
			const p = Producto(
				id: '1',
				nombre: 'Test',
				codigoBarras: '',
				precioBase: 10,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 't1',
			);
			expect(p.permiteStockNegativo, isTrue);
		});
	});

	group('PresentacionProducto', () {
		test('factorABase convierte cajas a unidades', () {
			const caja = PresentacionProducto(
				id: 'p1',
				productoId: 'prod1',
				nombre: 'Caja 12',
				factorABase: 12,
				esPresentacionBase: false,
				activo: true,
			);
			expect(3 * caja.factorABase, 36);
		});
	});
}
