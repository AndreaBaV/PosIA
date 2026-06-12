/// Utilidades de deteccion de plataforma.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Verdadero en iPhone/iPad o Android nativo (no web ni escritorio).
bool esPlataformaMovilNativa() {
	if (kIsWeb) {
		return false;
	}
	return Platform.isIOS || Platform.isAndroid;
}
