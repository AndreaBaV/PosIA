/// Scanner simulado para desarrollo y pruebas.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'dart:async';

import '../barcode_scanner.dart';

/// Emite codigos manualmente en entorno de desarrollo.
class MockBarcodeScanner implements BarcodeScanner {
	final StreamController<String> _controlador = StreamController<String>.broadcast();

	@override
	Stream<String> get codigos => _controlador.stream;

	@override
	Future<void> iniciar() async {}

	@override
	Future<void> detener() async {}

	/// Simula escaneo emitiendo codigo al stream.
	///
	/// [codigo] Codigo de barras simulado.
	void simularEscaneo(String codigo) {
		_controlador.add(codigo);
	}
}
