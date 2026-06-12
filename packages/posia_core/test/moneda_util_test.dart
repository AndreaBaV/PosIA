/// Pruebas de utilidades de moneda POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('moneda_util', () {
		test('redondea half-up a dos decimales', () {
			expect(redondearMonto(1.005), 1.01);
			expect(redondearMonto(1.004), 1.00);
		});

		test('formatea moneda MXN con simbolo de pesos', () {
			expect(formatearMoneda(1234.5), '\$1234.50');
		});
	});
}
