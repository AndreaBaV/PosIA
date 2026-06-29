/// Derivacion compacta de PIN de 4 digitos (sal + HMAC truncado).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashea y verifica PINs sin almacenar texto plano.
///
/// Formato compacto (~12 chars base64url). Credenciales legacy `sal:hash`
/// siguen validas hasta que el usuario cambie su PIN.
class HasherPin {
	const HasherPin._();

	static const int _salBytes = 3;
	static const int _hashBytes = 6;
	static const int _iteracionesLegacy = 120000;
	static const int _salBytesLegacy = 16;
	static const int _hashBytesLegacy = 32;

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

	/// Verifica PIN contra credencial compacta o legacy `sal:hash`.
	static bool verificar(String pin, String credencial) {
		final pinLimpio = pin.trim();
		if (pinLimpio.isEmpty || credencial.isEmpty) {
			return false;
		}
		if (credencial.contains(':')) {
			final separador = credencial.indexOf(':');
			return _verificarLegacy(
				pinLimpio,
				credencial.substring(0, separador),
				credencial.substring(separador + 1),
			);
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

	/// Empaqueta sal y hash legacy en una sola credencial.
	static String empaquetarLegacy(String sal, String hash) => '$sal:$hash';

	static List<int> _hmacTruncado(String pin, List<int> sal) {
		final mac = Hmac(sha256, sal).convert(utf8.encode(pin)).bytes;
		return mac.take(_hashBytes).toList();
	}

	static List<int> _bytesSeguros(int cantidad) {
		final random = Random.secure();
		return List.generate(cantidad, (_) => random.nextInt(256));
	}

	static bool _verificarLegacy(String pin, String salBase64, String hashEsperado) {
		if (salBase64.isEmpty || hashEsperado.isEmpty) {
			return false;
		}
		return _hashPinLegacy(pin, salBase64) == hashEsperado;
	}

	static String _hashPinLegacy(String pin, String salBase64) {
		final sal = base64Url.decode(salBase64);
		var derivado = Uint8List.fromList(utf8.encode(pin.trim()));
		for (var i = 0; i < _iteracionesLegacy; i++) {
			final hmac = Hmac(sha256, [...sal, ...derivado]);
			derivado = Uint8List.fromList(hmac.convert(derivado).bytes);
		}
		return base64UrlEncode(
			Uint8List.fromList(derivado.take(_hashBytesLegacy).toList()),
		);
	}
}
