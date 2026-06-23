/// Utilidades para teclas de acceso rapido en caja.
library;

import 'package:flutter/services.dart';

/// Valor por defecto: F12 para cobrar.
const String teclaCobrarPredeterminada = 'F12';

/// Convierte cadena guardada (F12, F2, etc.) a [LogicalKeyboardKey].
LogicalKeyboardKey parsearTeclaConfigurada(String? valor) {
	final texto = (valor ?? teclaCobrarPredeterminada).trim().toUpperCase();
	if (texto.isEmpty) {
		return LogicalKeyboardKey.f12;
	}
	final funcion = RegExp(r'^F(\d{1,2})$').firstMatch(texto);
	if (funcion != null) {
		final numero = int.tryParse(funcion.group(1)!);
		if (numero != null && numero >= 1 && numero <= 12) {
			return switch (numero) {
				1 => LogicalKeyboardKey.f1,
				2 => LogicalKeyboardKey.f2,
				3 => LogicalKeyboardKey.f3,
				4 => LogicalKeyboardKey.f4,
				5 => LogicalKeyboardKey.f5,
				6 => LogicalKeyboardKey.f6,
				7 => LogicalKeyboardKey.f7,
				8 => LogicalKeyboardKey.f8,
				9 => LogicalKeyboardKey.f9,
				10 => LogicalKeyboardKey.f10,
				11 => LogicalKeyboardKey.f11,
				_ => LogicalKeyboardKey.f12,
			};
		}
	}
	return LogicalKeyboardKey.f12;
}

/// Etiqueta legible de la tecla configurada.
String etiquetaTeclaConfigurada(String? valor) {
	final texto = (valor ?? teclaCobrarPredeterminada).trim().toUpperCase();
	return texto.isEmpty ? teclaCobrarPredeterminada : texto;
}
