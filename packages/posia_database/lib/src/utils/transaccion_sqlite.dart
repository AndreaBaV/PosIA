/// Utilidades para escrituras transaccionales SQLite.
library;

import 'package:sqflite/sqflite.dart';

/// Ejecuta [accion] en [db] si se proporciona; si no, abre transacción en [baseDatos].
Future<T> ejecutarEscrituraTransaccional<T>(
	Database baseDatos,
	DatabaseExecutor? db,
	Future<T> Function(DatabaseExecutor exec) accion,
) {
	if (db != null) {
		return accion(db);
	}
	return baseDatos.transaction((tx) => accion(tx));
}
