library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('util_peso', () {
		test('convierte gramos a kilogramos', () {
			expect(convertirGramosAKilogramos(1500.0), 1.5);
		});

		test('valida peso minimo comercial (desde 1 gramo)', () {
			expect(validarPesoMinimoKg(0.5), true); // 500 g
			expect(validarPesoMinimoKg(0.05), true); // 50 g: ahora válido
			expect(validarPesoMinimoKg(0.001), true); // 1 g: el mínimo
			expect(validarPesoMinimoKg(0.0005), false); // 0.5 g: por debajo
			expect(validarPesoMinimoKg(0.0), false);
		});
	});
}
