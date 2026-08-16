import 'package:flutter_test/flutter_test.dart';
import 'package:posia_pos/util/escritor_xlsx.dart';
import 'package:posia_pos/util/lector_xlsx.dart';

void main() {
	test('Excel de varias hojas se puede volver a leer', () {
		final bytes = EscritorXlsx.escribir({
			'Ventas': [
				['id', 'total'],
				['v1', '10.5'],
				['v2', 'Niño'],
			],
			'Compras': [
				['id'],
				['c1'],
			],
		});
		expect(LectorXlsx.listarNombresHojas(bytes), ['Ventas', 'Compras']);
		final ventas = LectorXlsx.leerFilas(bytes, nombreHoja: 'Ventas');
		expect(ventas.first, ['id', 'total']);
		expect(ventas[1], ['v1', '10.5']);
		expect(ventas[2], ['v2', 'Niño']);
	});
}
