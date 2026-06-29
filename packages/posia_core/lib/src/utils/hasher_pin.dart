/// Derivacion compacta de PIN de 4 digitos (sal + HMAC truncado).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashea y verifica PINs sin almacenar texto plano.
class HasherPin {
	const HasherPin._();

	static const int _salBytes = 3;
	static const int _hashBytes = 6;

	/// Genera credencial compacta para almacenar en BD o sync.
	static String codificar(String pin) {
		final pinLimpio = pin.trim();
		if (pinLimpio.isEmpty) {
			throw ArgumentError('PIN vacio');
		}
		final sal = _bytesSeguros(_salBytes);
		final hash = _hmacTruncado(pinLimpio, sal);
		return base64UrlEncode(Uint8List.fromList([...sal, ...hash]));
	}

	/// Verifica PIN contra credencial compacta.
	static bool verificar(String pin, String credencial) {
		final pinLimpio = pin.trim();
		if (pinLimpio.isEmpty || credencial.isEmpty || credencial.contains(':')) {
			return false;
		}
		try {
			final bytes = base64Url.decode(credencial);
			if (bytes.length < _salBytes + _hashBytes) {
				return false;
			}
			final sal = bytes.sublist(0, _salBytes);
			final esperado = bytes.sublist(_salBytes, _salBytes + _hashBytes);
			final calculado = _hmacTruncado(pinLimpio, sal);
			if (esperado.length != calculado.length) {
				return false;
			}
			var diff = 0;
			for (var i = 0; i < esperado.length; i++) {
				diff |= esperado[i] ^ calculado[i];
			}
			return diff == 0;
		} on Object {
			return false;
		}
	}

	static List<int> _hmacTruncado(String pin, List<int> sal) {
		final mac = Hmac(sha256, sal).convert(utf8.encode(pin)).bytes;
		return mac.take(_hashBytes).toList();
	}

	static List<int> _bytesSeguros(int cantidad) {
		final random = Random.secure();
		return List.generate(cantidad, (_) => random.nextInt(256));
	}
}
