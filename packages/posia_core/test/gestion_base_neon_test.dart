import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	const catalogo = {
		'products',
		'categories',
		'customers',
		'stores',
		'users',
		'custom_roles',
		'product_variants',
		'tipos_presentacion',
		'product_presentations',
		'almacenes',
		'warehouse_stock',
		'stock_levels',
		'wholesale_tiers',
		'lotes_promocion',
		'combos',
		'price_lists',
		'suppliers',
		'employee_profiles',
	};

	test('la purga manual no incluye tablas de catalogo ni existencias', () {
		final purgables = <String>{};
		for (final tablas in GruposHistorialNeon.tablasPorGrupo.values) {
			purgables.addAll(tablas);
		}
		expect(purgables.intersection(catalogo), isEmpty);
		expect(purgables, contains('sales'));
		expect(purgables, contains('sync_events'));
	});

	test('validar descarta grupos desconocidos', () {
		expect(
			GruposHistorialNeon.validar(['ventas', 'hack', 'products']),
			['ventas'],
		);
	});

	test('uso serializa y calcula fraccion', () {
		final uso = UsoBaseNeon(
			bytesUsados: LIMITE_BYTES_NEON_FREE ~/ 2,
			tablas: const [
				FilaUsoTablaNeon(tabla: 'sales', filas: 10, bytes: 100),
			],
		);
		final copia = UsoBaseNeon.desdeJson(uso.aJson());
		expect(copia.bytesUsados, uso.bytesUsados);
		expect(copia.tablas.single.tabla, 'sales');
		expect(copia.cercaDelLimite, isFalse);
	});

	test('uso y export sobreviven jsonEncode/jsonDecode del hub', () {
		final uso = UsoBaseNeon(
			bytesUsados: 100,
			tablas: const [
				FilaUsoTablaNeon(tabla: 'sales', filas: 3, bytes: 50),
			],
		);
		final usoDecoded = jsonDecode(jsonEncode(uso.aJson()));
		final usoCopia = UsoBaseNeon.desdeJson(
			Map<String, Object?>.from(usoDecoded as Map),
		);
		expect(usoCopia.tablas.single.tabla, 'sales');
		expect(usoCopia.tablas.single.filas, 3);

		final exportacion = ResultadoExportacionNeon(
			hojas: const [
				HojaExportacionNeon(
					nombre: 'sales',
					columnas: ['id', 'total'],
					filas: [
						['v1', '10'],
					],
				),
			],
			truncado: true,
			antesDe: DateTime.utc(2026, 1, 1),
		);
		final exportDecoded = jsonDecode(jsonEncode(exportacion.aJson()));
		final exportCopia = ResultadoExportacionNeon.desdeJson(
			Map<String, Object?>.from(exportDecoded as Map),
		);
		expect(exportCopia.truncado, isTrue);
		expect(exportCopia.hojas.single.filas.single, ['v1', '10']);
	});
}
