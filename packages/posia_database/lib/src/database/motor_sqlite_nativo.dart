/// Motor SQLite para plataformas nativas (Windows, Android, Linux).
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:50:00 (UTC-6)
/// Ultima modificacion: 2026-07-19 14:05:00 (UTC-6)
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Configura factory SQLite FFI en escritorio.
///
/// En Android usa el plugin sqflite nativo sin cambios.
Future<void> inicializarMotorSqlite() async {
	final esEscritorio = defaultTargetPlatform == TargetPlatform.windows ||
		defaultTargetPlatform == TargetPlatform.linux;
	if (esEscritorio) {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	}
}

/// Resuelve ruta absoluta del archivo de base de datos.
///
/// Usa el directorio de **soporte de aplicacion**, no el de documentos: en
/// Windows "Documentos" suele estar redirigido a OneDrive, y una base SQLite en
/// modo WAL dentro de una carpeta sincronizada se corrompe. OneDrive virtualiza
/// los archivos mapeados en memoria, el `-shm` (indice del WAL) deja de
/// actualizarse y los lectores dejan de ver lo que hay en el `-wal`: escrituras
/// que no aterrizan y catalogos desfasados entre pantallas.
///
/// [nombreArchivo] Nombre del archivo SQLite.
/// Retorna ruta dentro del directorio de soporte de la aplicacion.
Future<String> resolverRutaBaseDatos(String nombreArchivo) async {
	final directorio = await getApplicationSupportDirectory();
	final rutaNueva = path_lib.join(directorio.path, nombreArchivo);
	await _migrarDesdeDocumentosSiHaceFalta(nombreArchivo, rutaNueva);
	return rutaNueva;
}

/// Copia una base preexistente de Documentos a soporte de aplicacion.
///
/// Solo actua si el destino aun no existe y el origen si. Copia `.db` y `-wal`
/// pero **no** el `-shm`: ese indice se reconstruye solo al abrir, y el que
/// quedo en la carpeta sincronizada puede estar desfasado respecto al WAL.
/// Copiar (en vez de mover) deja el original intacto como respaldo.
Future<void> _migrarDesdeDocumentosSiHaceFalta(
	String nombreArchivo,
	String rutaNueva,
) async {
	try {
		if (await File(rutaNueva).exists()) {
			return;
		}
		final documentos = await getApplicationDocumentsDirectory();
		final rutaVieja = path_lib.join(documentos.path, nombreArchivo);
		if (!await File(rutaVieja).exists()) {
			return;
		}
		await Directory(path_lib.dirname(rutaNueva)).create(recursive: true);
		await File(rutaVieja).copy(rutaNueva);
		final walViejo = File('$rutaVieja-wal');
		if (await walViejo.exists()) {
			await walViejo.copy('$rutaNueva-wal');
		}
	} on Object catch (error) {
		// Si la migracion falla se sigue con la ruta nueva vacia: la base se
		// recrea y el sync la repuebla desde el hub. El original no se toca.
		debugPrint('POSIA: no se pudo migrar $nombreArchivo desde Documentos: $error');
	}
}
