/// Utilidades para compartir texto por WhatsApp.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normaliza telefono mexicano a formato wa.me (solo digitos, prefijo 52).
String normalizarTelefonoWhatsApp(String telefono) {
	final soloDigitos = telefono.replaceAll(RegExp(r'\D'), '');
	if (soloDigitos.isEmpty) {
		return '';
	}
	if (soloDigitos.length == 10) {
		return '52$soloDigitos';
	}
	return soloDigitos;
}

Uri _uriWhatsAppNativo(String telefonoLimpio, String textoCodificado) {
	if (telefonoLimpio.isNotEmpty) {
		return Uri.parse(
			'whatsapp://send?phone=$telefonoLimpio&text=$textoCodificado',
		);
	}
	return Uri.parse('whatsapp://send?text=$textoCodificado');
}

Uri _uriWaMe(String telefonoLimpio, String textoCodificado) {
	if (telefonoLimpio.isNotEmpty) {
		return Uri.parse('https://wa.me/$telefonoLimpio?text=$textoCodificado');
	}
	return Uri.parse('https://wa.me/?text=$textoCodificado');
}

Uri _uriWhatsAppWeb(String telefonoLimpio, String textoCodificado) {
	if (telefonoLimpio.isNotEmpty) {
		return Uri.parse(
			'https://web.whatsapp.com/send?phone=$telefonoLimpio&text=$textoCodificado',
		);
	}
	return Uri.parse('https://web.whatsapp.com/send?text=$textoCodificado');
}

bool _esMovilNativo() {
	if (kIsWeb) {
		return false;
	}
	return Platform.isAndroid || Platform.isIOS;
}

Future<bool> _intentarLanzar(Uri uri, LaunchMode mode) async {
	try {
		if (await canLaunchUrl(uri)) {
			return await launchUrl(uri, mode: mode);
		}
		return await launchUrl(uri, mode: mode);
	} on Object {
		return false;
	}
}

/// Abre WhatsApp (app) o WhatsApp Web si la app no esta instalada.
Future<bool> compartirTextoWhatsApp({
	required String texto,
	String? telefono,
}) async {
	final telefonoLimpio =
		telefono != null ? normalizarTelefonoWhatsApp(telefono) : '';
	final textoCodificado = Uri.encodeComponent(texto);

	if (_esMovilNativo()) {
		if (await _intentarLanzar(
			_uriWhatsAppNativo(telefonoLimpio, textoCodificado),
			LaunchMode.externalApplication,
		)) {
			return true;
		}
		if (await _intentarLanzar(
			_uriWaMe(telefonoLimpio, textoCodificado),
			LaunchMode.externalApplication,
		)) {
			return true;
		}
	} else {
		if (await _intentarLanzar(
			_uriWaMe(telefonoLimpio, textoCodificado),
			LaunchMode.externalApplication,
		)) {
			return true;
		}
	}

	return _intentarLanzar(
		_uriWhatsAppWeb(telefonoLimpio, textoCodificado),
		LaunchMode.externalApplication,
	);
}

/// Comparte por WhatsApp y muestra SnackBar si no se pudo abrir.
Future<void> compartirTextoWhatsAppConAviso(
	BuildContext context, {
	required String texto,
	String? telefono,
}) async {
	final ok = await compartirTextoWhatsApp(texto: texto, telefono: telefono);
	if (!context.mounted) {
		return;
	}
	if (!ok) {
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(
				content: Text('No se pudo abrir WhatsApp ni WhatsApp Web'),
			),
		);
	}
}
