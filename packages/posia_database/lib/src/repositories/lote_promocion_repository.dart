/// Repositorio SQLite de lotes de promocion mayoreo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/transaccion_sqlite.dart';

/// Persiste lotes de promocion y sus productos miembros.
class LotePromocionRepository {
	LotePromocionRepository({required Database baseDatos})
		: _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Lista lotes de promocion activos (con miembros).
	Future<List<LotePromocion>> listarActivos({DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'lotes_promocion',
			where: 'activo = 1',
			orderBy: 'codigo_externo ASC',
		);
		final lotes = <LotePromocion>[];
		for (final fila in filas) {
			final id = fila['id']! as String;
			lotes.add(_mapear(fila, await _miembrosDe(id, db: exec)));
		}
		return lotes;
	}

	/// Obtiene lote activo por codigo externo de importacion.
	Future<LotePromocion?> obtenerPorCodigoExterno(
		String codigoExterno, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'lotes_promocion',
			where: 'codigo_externo = ? AND activo = 1',
			whereArgs: [codigoExterno.trim()],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first, await _miembrosDe(filas.first['id']! as String, db: exec));
	}

	/// Obtiene lote por id (incluye miembros).
	Future<LotePromocion?> obtenerPorId(
		String loteId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'lotes_promocion',
			where: 'id = ?',
			whereArgs: [loteId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first, await _miembrosDe(loteId, db: exec));
	}

	/// Obtiene lote activo al que pertenece el producto.
	Future<LotePromocion?> obtenerPorProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.rawQuery(
			'''
			SELECT lp.*
			FROM lotes_promocion lp
			INNER JOIN lote_promocion_miembros m ON m.lote_id = lp.id
			WHERE m.producto_id = ? AND lp.activo = 1
			LIMIT 1
			''',
			[productoId],
		);
		if (filas.isEmpty) {
			return null;
		}
		final loteId = filas.first['id']! as String;
		return _mapear(filas.first, await _miembrosDe(loteId, db: exec));
	}

	/// Reemplaza un lote completo (cabecera + miembros) de forma atomica.
	Future<void> reemplazarLote(
		LotePromocion lote, {
		DatabaseExecutor? db,
	}) async {
		await ejecutarEscrituraTransaccional(_baseDatos, db, (tx) async {
			await tx.insert(
				'lotes_promocion',
				{
					'id': lote.id,
					'codigo_externo': lote.codigoExterno.trim(),
					'nombre': lote.nombre.trim(),
					'cantidad_minima': lote.cantidadMinima,
					'precio_unitario': lote.precioUnitario,
					'activo': lote.activo ? 1 : 0,
				},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
			await tx.delete(
				'lote_promocion_miembros',
				where: 'lote_id = ?',
				whereArgs: [lote.id],
			);
			for (final productoId in lote.productoIds.toSet()) {
				if (productoId.isEmpty) {
					continue;
				}
				await tx.insert(
					'lote_promocion_miembros',
					{
						'lote_id': lote.id,
						'producto_id': productoId,
					},
					conflictAlgorithm: ConflictAlgorithm.replace,
				);
			}
		});
	}

	/// Agrega un producto a un lote existente sin quitar los demas.
	Future<void> agregarMiembro(
		String loteId,
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.insert(
			'lote_promocion_miembros',
			{
				'lote_id': loteId,
				'producto_id': productoId,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Quita membresia de un producto en cualquier lote.
	Future<void> eliminarMiembroProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.delete(
			'lote_promocion_miembros',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
	}

	Future<List<String>> _miembrosDe(
		String loteId, {
		required DatabaseExecutor db,
	}) async {
		final filas = await db.query(
			'lote_promocion_miembros',
			columns: ['producto_id'],
			where: 'lote_id = ?',
			whereArgs: [loteId],
		);
		return filas.map((f) => f['producto_id']! as String).toList();
	}

	LotePromocion _mapear(Map<String, Object?> fila, List<String> miembros) {
		return LotePromocion(
			id: fila['id']! as String,
			codigoExterno: fila['codigo_externo']! as String,
			nombre: (fila['nombre'] as String?) ?? '',
			cantidadMinima: (fila['cantidad_minima'] as num).toDouble(),
			precioUnitario: (fila['precio_unitario'] as num).toDouble(),
			activo: ((fila['activo'] as int?) ?? 1) == 1,
			productoIds: miembros,
		);
	}
}
