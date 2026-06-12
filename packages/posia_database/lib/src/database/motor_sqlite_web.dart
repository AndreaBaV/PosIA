/// Motor SQLite para web sobre WASM e IndexedDB.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:50:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:50:00 (UTC-6)
library;

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Configura factory SQLite WASM persistido en IndexedDB.
Future<void> inicializarMotorSqlite() async {
	databaseFactory = databaseFactoryFfiWeb;
}

/// Resuelve identificador de base de datos en navegador.
///
/// [nombreArchivo] Nombre logico del archivo SQLite.
/// Retorna el mismo nombre; el navegador gestiona el almacenamiento.
Future<String> resolverRutaBaseDatos(String nombreArchivo) async {
	return nombreArchivo;
}
