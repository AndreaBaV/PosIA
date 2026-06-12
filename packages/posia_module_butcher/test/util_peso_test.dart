/// Pruebas de utilidades de peso carniceria.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_module_butcher/posia_module_butcher.dart';
import 'package:test/test.dart';

void main() {
	group('util_peso', () {
		test('convierte gramos a kilogramos', () {
			expect(convertirGramosAKilogramos(1500.0), 1.5);
		});

		test('valida peso minimo comercial', () {
			expect(validarPesoMinimoKg(0.5), true);
			expect(validarPesoMinimoKg(0.05), false);
		});
	});
}
