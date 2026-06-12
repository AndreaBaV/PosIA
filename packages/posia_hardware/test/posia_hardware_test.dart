import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_hardware/posia_hardware.dart';

void main() {
	test('ImpresoraConfigurable modo archivo guarda ticket', () async {
		final directorio = Directory.systemTemp.createTempSync('posia_ticket_test').path;
		final impresora = ImpresoraConfigurable(
			modo: ModoImpresora.archivo,
			hostRed: '',
			directorioArchivo: directorio,
		);
		await impresora.imprimirTicket('TICKET TEST');
		final archivos = Directory(directorio).listSync().whereType<File>();
		expect(archivos.isNotEmpty, isTrue);
	});
}
