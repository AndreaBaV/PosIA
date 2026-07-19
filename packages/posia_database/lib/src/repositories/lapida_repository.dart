/// Registro de entidades eliminadas por un administrador (lapidas).
///
/// El borrado manual es absoluto y tiene prioridad sobre el hub. Sin este
/// registro, borrar un producto o una categoria no se propagaba —el protocolo
/// no tenia evento de borrado— y el siguiente pull lo recreaba; ademas
/// cualquier evento hijo atrasado (una venta de otra caja, un movimiento de
/// inventario) resucitaba al padre como stub FK.
library;

import 'package:sqflite/sqflite.dart';

/// Tipos de entidad que admiten lapida.
class TipoLapida {
	const TipoLapida._();

	static const String producto = 'producto';
	static const String categoria = 'categoria';
}

/// Persiste y consulta las lapidas de borrado.
class LapidaRepository {
	/// Crea repositorio con conexion SQLite activa.
	LapidaRepository({required DatabaseExecutor baseDatos})
		: _baseDatos = baseDatos;

	final DatabaseExecutor _baseDatos;

	/// Registra el borrado de una entidad.
	///
	/// [tipo] Ver [TipoLapida]. [entidadId] Identificador borrado.
	/// [eliminadoPor] Usuario que ordeno el borrado, para auditoria.
	Future<void> registrar({
		required String tipo,
		required String entidadId,
		String eliminadoPor = '',
		DateTime? eliminadoEn,
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.insert(
			'entidades_eliminadas',
			{
				'tipo': tipo,
				'entidad_id': entidadId,
				'eliminado_en':
					(eliminadoEn ?? DateTime.now().toUtc()).toIso8601String(),
				'eliminado_por': eliminadoPor,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Indica si la entidad fue eliminada por un administrador.
	Future<bool> estaEliminada(
		String tipo,
		String entidadId, {
		DatabaseExecutor? db,
	}) async {
		if (entidadId.trim().isEmpty) {
			return false;
		}
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'entidades_eliminadas',
			columns: const ['entidad_id'],
			where: 'tipo = ? AND entidad_id = ?',
			whereArgs: [tipo, entidadId],
			limit: 1,
		);
		return filas.isNotEmpty;
	}

	/// Lista los identificadores enterrados de un tipo.
	Future<Set<String>> idsEliminados(String tipo, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'entidades_eliminadas',
			columns: const ['entidad_id'],
			where: 'tipo = ?',
			whereArgs: [tipo],
		);
		return filas.map((f) => f['entidad_id'] as String).toSet();
	}

	/// Quita la lapida: permite volver a dar de alta ese identificador.
	Future<void> revivir({
		required String tipo,
		required String entidadId,
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.delete(
			'entidades_eliminadas',
			where: 'tipo = ? AND entidad_id = ?',
			whereArgs: [tipo, entidadId],
		);
	}
}
