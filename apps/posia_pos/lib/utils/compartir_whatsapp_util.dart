/// Utilidades para compartir texto por WhatsApp.
library;

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

/// Abre WhatsApp con texto prellenado.
Future<bool> compartirTextoWhatsApp({
	required String texto,
	String? telefono,
}) async {
	final telefonoLimpio = telefono != null ? normalizarTelefonoWhatsApp(telefono) : '';
	final uri = telefonoLimpio.isNotEmpty
		? Uri.parse(
			'https://wa.me/$telefonoLimpio?text=${Uri.encodeComponent(texto)}',
		)
		: Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');
	if (await canLaunchUrl(uri)) {
		return launchUrl(uri, mode: LaunchMode.externalApplication);
	}
	return false;
}

/// Comparte por WhatsApp y muestra SnackBar si no se pudo abrir la app.
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
			const SnackBar(content: Text('No se pudo abrir WhatsApp')),
		);
	}
}
