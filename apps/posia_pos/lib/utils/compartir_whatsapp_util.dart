/// Utilidades para compartir texto y archivos por WhatsApp.
library;

import 'package:posia_ui/posia_ui.dart';

import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsapp_direct_send/whatsapp_direct_send.dart';

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

bool _esEscritorio() {
  if (kIsWeb) {
    return true;
  }
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
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
  final telefonoLimpio = telefono != null
      ? normalizarTelefonoWhatsApp(telefono)
      : '';
  final textoCodificado = Uri.encodeComponent(texto);

  if (_esMovilNativo()) {
    if (await _intentarLanzar(
      _uriWhatsAppNativo(telefonoLimpio, textoCodificado),
      LaunchMode.externalApplication,
    )) {
      return true;
    }
    return _intentarLanzar(
      _uriWaMe(telefonoLimpio, textoCodificado),
      LaunchMode.externalApplication,
    );
  }

  if (_esEscritorio()) {
    if (await _intentarLanzar(
      _uriWhatsAppNativo(telefonoLimpio, textoCodificado),
      LaunchMode.externalApplication,
    )) {
      return true;
    }
    return _intentarLanzar(
      _uriWhatsAppWeb(telefonoLimpio, textoCodificado),
      LaunchMode.externalApplication,
    );
  }

  if (await _intentarLanzar(
    _uriWaMe(telefonoLimpio, textoCodificado),
    LaunchMode.externalApplication,
  )) {
    return true;
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
    PosiaNotificaciones.mostrarSnackBar(
      context,
      const SnackBar(
        content: Text('No se pudo abrir WhatsApp ni WhatsApp Web'),
      ),
    );
  }
}

Future<bool> _compartirArchivoAndroidWhatsApp({
  required String rutaArchivo,
  required String leyenda,
  String? telefono,
}) async {
  if (!Platform.isAndroid) {
    return false;
  }
  final telefonoLimpio = telefono != null
      ? normalizarTelefonoWhatsApp(telefono)
      : '';
  if (telefonoLimpio.isEmpty) {
    return false;
  }
  try {
    await WhatsappDirectSend.shareToChat(
      phone: telefonoLimpio,
      text: leyenda,
      filePath: rutaArchivo,
    );
    return true;
  } on PlatformException catch (error) {
    if (error.code == 'WHATSAPP_NOT_FOUND') {
      return false;
    }
    rethrow;
  }
}

Future<bool> _compartirArchivoHojaSistema({
  required String rutaArchivo,
  required String mimeType,
  String? texto,
  Rect? sharePositionOrigin,
}) async {
  final resultado = await Share.shareXFiles(
    [XFile(rutaArchivo, mimeType: mimeType)],
    text: texto,
    sharePositionOrigin: sharePositionOrigin,
  );
	return resultado.status == ShareResultStatus.success;
}

/// Abre el Explorador de archivos con el archivo seleccionado.
Future<void> _abrirExploradorConArchivoSeleccionado(String ruta) async {
  if (!Platform.isWindows) {
    return;
  }
  try {
    await Process.run('explorer.exe', ['/select,', ruta]);
  } on Object {
    // Ignorar si no se puede abrir el explorador.
  }
}

Future<void> _mostrarDialogoAdjuntarTicketWindows(
	BuildContext context, {
	required String rutaArchivo,
	required bool esPdf,
}) async {
	if (!context.mounted) {
		return;
	}
	final nombre = rutaArchivo.split(Platform.pathSeparator).last;
	await showDialog<void>(
		context: context,
		builder: (ctx) => AlertDialog(
			icon: Icon(esPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
			title: const Text('Ticket listo para WhatsApp'),
			content: Text(
				'WhatsApp se abrió con el mensaje del folio.\n\n'
				'Adjunte el ticket con el botón 📎 en WhatsApp:\n'
				'$nombre\n\n'
				'Se abrió la carpeta donde está guardado el archivo.',
			),
			actions: [
				FilledButton(
					onPressed: () => Navigator.pop(ctx),
					child: const Text('Entendido'),
				),
			],
		),
	);
}

/// Comparte un archivo (PNG/PDF) por WhatsApp con la leyenda como caption.
Future<void> compartirArchivoWhatsAppConAviso(
	BuildContext context, {
	required String rutaArchivo,
	required String mimeType,
	required String leyenda,
	String? telefono,
}) async {
	final origen = _origenCompartir(context);

	if (await _compartirArchivoAndroidWhatsApp(
		rutaArchivo: rutaArchivo,
		leyenda: leyenda,
		telefono: telefono,
	)) {
		return;
	}

	if (await _compartirArchivoHojaSistema(
		rutaArchivo: rutaArchivo,
		mimeType: mimeType,
		texto: leyenda,
		sharePositionOrigin: origen,
	)) {
		return;
	}

	if (_esEscritorio()) {
		await _abrirExploradorConArchivoSeleccionado(rutaArchivo);
		final webAbierto = await compartirTextoWhatsApp(
			texto: leyenda,
			telefono: telefono,
		);
		if (!context.mounted) {
			return;
		}
		if (!webAbierto) {
			PosiaNotificaciones.mostrarSnackBar(
				context,
				const SnackBar(content: Text('No se pudo abrir WhatsApp')),
			);
			return;
		}
		await _mostrarDialogoAdjuntarTicketWindows(
			context,
			rutaArchivo: rutaArchivo,
			esPdf: mimeType.contains('pdf'),
		);
		return;
	}

	final webAbierto = await compartirTextoWhatsApp(
		texto: leyenda,
		telefono: telefono,
	);
	if (!context.mounted) {
		return;
	}
	if (!webAbierto) {
		PosiaNotificaciones.mostrarSnackBar(
			context,
			const SnackBar(
				content: Text('No se pudo abrir WhatsApp ni WhatsApp Web'),
			),
		);
		return;
	}
	PosiaNotificaciones.mostrarSnackBar(
		context,
		SnackBar(
			content: Text(
				'Adjunte el archivo en WhatsApp con el clip:\n$rutaArchivo',
			),
			duration: const Duration(seconds: 10),
		),
	);
}

Rect? _origenCompartir(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
