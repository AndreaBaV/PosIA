/// Motor SQLite para plataformas nativas (Windows, Android, Linux).
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:50:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:50:00 (UTC-6)
library;

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
/// [nombreArchivo] Nombre del archivo SQLite.
/// Retorna ruta dentro del directorio de documentos.
Future<String> resolverRutaBaseDatos(String nombreArchivo) async {
	final directorio = await getApplicationDocumentsDirectory();
	return path_lib.join(directorio.path, nombreArchivo);
}
