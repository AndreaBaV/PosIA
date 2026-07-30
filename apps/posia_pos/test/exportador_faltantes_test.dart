/// Pruebas del armado de lista de faltantes para exportar / WhatsApp.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_database/posia_database.dart';

import 'package:posia_pos/util/exportador_faltantes.dart';

void main() {
	const alertas = [
		AlertaFaltante(
			productoId: 'p1',
			nombreProducto: 'Harina 1kg',
			cantidadActual: 2,
			stockMinimo: 10,
			tiendaId: 't1',
		),
		AlertaFaltante(
			productoId: 'p2',
			nombreProducto: 'Aceite "extra"',
			cantidadActual: 0,
			stockMinimo: 5,
			tiendaId: 't1',
		),
	];

	test('cantidadAPedir es minimo menos actual', () {
		expect(ExportadorFaltantes.cantidadAPedir(alertas.first), 8);
		expect(ExportadorFaltantes.cantidadAPedir(alertas.last), 5);
	});

	test('texto WhatsApp lista hay / minimo / pedir', () {
		final texto = ExportadorFaltantes.textoWhatsApp(
			nombreTienda: 'Centro',
			alertas: alertas,
		);
		expect(texto, contains('*FALTANTES — Centro*'));
		expect(texto, contains('Harina 1kg'));
		expect(texto, contains('Hay: 2 · Mínimo: 10 · Pedir: 8'));
		expect(texto, contains('Pedir: 5'));
		expect(texto, contains('— 2 productos —'));
	});

	test('CSV escapa comillas en el nombre', () {
		final csv = ExportadorFaltantes.generarCsv(
			nombreTienda: 'Centro',
			alertas: alertas,
		);
		expect(csv, contains('"Aceite ""extra""",0,5,5'));
		expect(csv, contains('"Harina 1kg",2,10,8'));
	});
}
