/// Repositorio SQLite del estado de sincronizacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:40:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

/// Implementa [AlmacenCursorSync] sobre tabla sync_state.
class SyncStateRepository implements AlmacenCursorSync {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	SyncStateRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	static const String _claveCursorHub = 'last_synced_event_seq';

	final Database _baseDatos;

	@override
	Future<int> leerCursorHub() async {
		final filas = await _baseDatos.query(
			'sync_state',
			where: 'clave = ?',
			whereArgs: [_claveCursorHub],
			limit: 1,
		);
		if (filas.isEmpty) {
			return 0;
		}
		return int.tryParse(filas.first['valor'] as String? ?? '0') ?? 0;
	}

	@override
	Future<void> guardarCursorHub(int seq) async {
		await _baseDatos.insert(
			'sync_state',
			{'clave': _claveCursorHub, 'valor': seq.toString()},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}
}
