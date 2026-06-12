/// Scanner de codigo de barras tipo teclado (USB wedge).
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'barcode_scanner.dart';

/// Captura lecturas rapidas de teclado terminadas en Enter.
class TecladoBarcodeScanner implements BarcodeScanner {
	final StreamController<String> _controlador =
		StreamController<String>.broadcast();
	final StringBuffer _buffer = StringBuffer();
	DateTime? _ultimoCaracter;

	@override
	Stream<String> get codigos => _controlador.stream;

	@override
	Future<void> iniciar() async {
		HardwareKeyboard.instance.addHandler(_manejarTecla);
	}

	@override
	Future<void> detener() async {
		HardwareKeyboard.instance.removeHandler(_manejarTecla);
		_buffer.clear();
	}

	bool _manejarTecla(KeyEvent event) {
		if (event is! KeyDownEvent) {
			return false;
		}
		final ahora = DateTime.now();
		if (_ultimoCaracter != null &&
			ahora.difference(_ultimoCaracter!).inMilliseconds > 400) {
			_buffer.clear();
		}
		_ultimoCaracter = ahora;

		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			final codigo = _buffer.toString().trim();
			_buffer.clear();
			if (codigo.isNotEmpty) {
				_controlador.add(codigo);
			}
			return false;
		}

		final caracter = event.character;
		if (caracter != null && caracter.isNotEmpty) {
			_buffer.write(caracter);
		}
		return false;
	}
}
