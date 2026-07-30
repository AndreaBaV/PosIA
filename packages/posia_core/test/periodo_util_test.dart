/// Pruebas de las ventanas de periodo del historial.
library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('rangoPeriodoDiasLocal', () {
		test('"hoy" arranca en la medianoche local, no 24 h atras', () {
			final rango = rangoPeriodoDiasLocal(1);
			final desdeLocal = rango.desde.toLocal();
			final ahora = DateTime.now();

			expect(desdeLocal.hour, 0);
			expect(desdeLocal.minute, 0);
			expect(desdeLocal.second, 0);
			expect(desdeLocal.day, ahora.day);
			expect(desdeLocal.month, ahora.month);
			expect(desdeLocal.year, ahora.year);
		});

		test('una venta de esta manana cae dentro de "hoy"', () {
			final rango = rangoPeriodoDiasLocal(1);
			final ahora = DateTime.now();
			// Justo despues de la medianoche local: siempre cae en [desde, hasta],
			// aunque el test corra a las 07:00 (antes las 08:00 quedaban en el
			// futuro y fallaban en CI / madrugada).
			final estaManana = DateTime(
				ahora.year,
				ahora.month,
				ahora.day,
				0,
				1,
			).toUtc();

			// Con la ventana rodante anterior esta venta desaparecia del
			// historial en cuanto pasaban 24 h desde su registro.
			expect(estaManana.isBefore(rango.desde), isFalse);
			expect(estaManana.isAfter(rango.hasta), isFalse);
		});

		test('7 dias cubre 7 dias calendario contando hoy', () {
			final rango = rangoPeriodoDiasLocal(7);
			final desdeLocal = rango.desde.toLocal();
			final ahora = DateTime.now();
			final inicioDeHoy = DateTime(ahora.year, ahora.month, ahora.day);

			expect(desdeLocal.hour, 0);
			expect(inicioDeHoy.difference(desdeLocal).inDays, 6);
		});

		test('los limites salen en UTC para comparar contra ISO-8601', () {
			final rango = rangoPeriodoDiasLocal(30);

			expect(rango.desde.isUtc, isTrue);
			expect(rango.hasta.isUtc, isTrue);
			expect(
				rango.desde.toIso8601String().compareTo(
					rango.hasta.toIso8601String(),
				),
				lessThan(0),
			);
		});

		test('dias invalidos se tratan como hoy', () {
			final hoy = rangoPeriodoDiasLocal(1);
			final cero = rangoPeriodoDiasLocal(0);
			final negativo = rangoPeriodoDiasLocal(-5);

			expect(cero.desde, hoy.desde);
			expect(negativo.desde, hoy.desde);
		});
	});
}
