/// Derivacion segura de PIN con sal e iteraciones.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashea y verifica PINs de usuario sin almacenar texto plano.
class HasherPin {
	const HasherPin._();

	static const int _iteraciones = 120000;
	static const int _longitudSalBytes = 16;
	static const int _longitudHashBytes = 32;

	/// Genera sal aleatoria en base64url.
	static String generarSal() {
		final random = Random.secure();
		final bytes = Uint8List.fromList(
			List.generate(_longitudSalBytes, (_) => random.nextInt(256)),
		);
		return base64UrlEncode(bytes);
	}

	/// Deriva hash del PIN con PBKDF2 simplificado (HMAC-SHA256 iterado).
	static String hashPin(String pin, String salBase64) {
		final sal = base64Url.decode(salBase64);
		var derivado = Uint8List.fromList(utf8.encode(pin.trim()));
		for (var i = 0; i < _iteraciones; i++) {
			final hmac = Hmac(sha256, [...sal, ...derivado]);
			derivado = Uint8List.fromList(hmac.convert(derivado).bytes);
		}
		return base64UrlEncode(Uint8List.fromList(derivado.take(_longitudHashBytes).toList()));
	}

	/// Compara PIN ingresado con hash almacenado.
	static bool verificar(String pin, String salBase64, String hashEsperado) {
		if (pin.trim().isEmpty || salBase64.isEmpty || hashEsperado.isEmpty) {
			return false;
		}
		return hashPin(pin, salBase64) == hashEsperado;
	}
}
