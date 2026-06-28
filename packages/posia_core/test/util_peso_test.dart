library;

import 'package:posia_core/posia_core.dart';
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
