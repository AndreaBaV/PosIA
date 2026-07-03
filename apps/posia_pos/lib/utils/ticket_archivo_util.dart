/// Rutas y nombres de archivos de tickets en disco.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';

/// Nombre legible: ticket_020725-ABCD.pdf
String nombreArchivoTicket(String folio, String extension) {
	final limpio = folio.replaceAll(RegExp(r'[^\w\-]'), '_');
	return 'ticket_$limpio.$extension';
}

/// Carpeta Documents/La Fortuna/tickets (Windows) o equivalente movil.
Future<Directory?> carpetaTicketsDocumentos() async {
	if (kIsWeb) {
		return null;
	}
	Directory base;
	if (Platform.isIOS || Platform.isAndroid) {
		base = await getApplicationDocumentsDirectory();
	} else {
		final perfil = Platform.environment['USERPROFILE'];
		if (perfil == null || perfil.isEmpty) {
			base = Directory.current;
		} else {
			base = Directory('$perfil${Platform.pathSeparator}Documents');
		}
	}
	final ruta =
		'${base.path}${Platform.pathSeparator}$CARPETA_DOCUMENTOS_APP'
		'${Platform.pathSeparator}tickets';
	final carpeta = Directory(ruta);
	if (!carpeta.existsSync()) {
		carpeta.createSync(recursive: true);
	}
	return carpeta;
}

/// Guarda bytes en Documents/La Fortuna/tickets/ con nombre por folio.
Future<File?> guardarTicketEnDocumentos({
	required String folio,
	required List<int> bytes,
	required String extension,
}) async {
	final carpeta = await carpetaTicketsDocumentos();
	if (carpeta == null) {
		return null;
	}
	final archivo = File(
		'${carpeta.path}${Platform.pathSeparator}'
		'${nombreArchivoTicket(folio, extension)}',
	);
	await archivo.writeAsBytes(bytes);
	return archivo;
}
