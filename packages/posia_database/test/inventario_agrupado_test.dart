/// Pruebas unitarias de totales en inventario agrupado.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';

void main() {
	group('InventarioAgrupado', () {
		const registro = InventarioAgrupado(
			productoId: 'p1',
			nombreProducto: 'Cemento',
			existenciasPorTienda: {'Origen': 2.0, 'Destino': 3.0},
			existenciasPorTiendaId: {'t1': 2.0, 't2': 3.0},
			stockMinimoPorTiendaId: {'t1': 1.0, 't2': 1.0},
			existenciasPorAlmacen: {'Norte': 5.0, 'Sur': 3.0, 'Centro': 2.0},
			existenciasPorAlmacenId: {'a1': 5.0, 'a2': 3.0, 'a3': 2.0},
			stockMinimoPorAlmacenId: {},
			stockMinimoLocal: 1.0,
			cantidadLocal: 2.0,
		);

		test('totalGlobal suma solo tiendas', () {
			expect(registro.totalGlobal, 5.0);
		});

		test('totalAlmacenes suma ubicaciones de almacén', () {
			expect(registro.totalAlmacenes, 10.0);
		});

		test('totalEmpresa combina tiendas y almacenes', () {
			expect(registro.totalEmpresa, 15.0);
		});

		test('cantidadEnAlmacen devuelve cero si no existe', () {
			expect(registro.cantidadEnAlmacen('inexistente'), 0.0);
			expect(registro.cantidadEnAlmacen('a2'), 3.0);
		});
	});
}
