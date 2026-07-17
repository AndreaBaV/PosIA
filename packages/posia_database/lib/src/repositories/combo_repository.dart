/// Repositorio SQLite de combos de precio fijo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';
import '../utils/transaccion_sqlite.dart';

/// Persiste combos y sus productos miembro.
class ComboRepository {
	ComboRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	/// Lista todos los combos (activos e inactivos) con sus miembros.
	Future<List<Combo>> listarTodos({DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query('combos', orderBy: 'nombre ASC');
		final combos = <Combo>[];
		for (final fila in filas) {
			final id = fila['id']! as String;
			combos.add(_mapear(fila, await _miembrosDe(id, db: exec)));
		}
		return combos;
	}

	/// Lista combos activos (con miembros).
	Future<List<Combo>> listarActivos({DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'combos',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		final combos = <Combo>[];
		for (final fila in filas) {
			final id = fila['id']! as String;
			combos.add(_mapear(fila, await _miembrosDe(id, db: exec)));
		}
		return combos;
	}

	/// Obtiene combo por id (incluye miembros).
	Future<Combo?> obtenerPorId(String comboId, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'combos',
			where: 'id = ?',
			whereArgs: [comboId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first, await _miembrosDe(comboId, db: exec));
	}

	/// Lista combos activos a los que pertenece el producto.
	Future<List<Combo>> listarPorProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.rawQuery(
			'''
			SELECT DISTINCT c.*
			FROM combos c
			INNER JOIN combo_miembros m ON m.combo_id = c.id
			WHERE m.producto_id = ? AND c.activo = 1
			''',
			[productoId],
		);
		final combos = <Combo>[];
		for (final fila in filas) {
			final id = fila['id']! as String;
			combos.add(_mapear(fila, await _miembrosDe(id, db: exec)));
		}
		return combos;
	}

	/// Reemplaza un combo completo (cabecera + miembros) de forma atomica.
	Future<void> reemplazarCombo(Combo combo, {DatabaseExecutor? db}) async {
		await _padresFk.asegurarPadresDeCombo(combo);
		await ejecutarEscrituraTransaccional(_baseDatos, db, (tx) async {
			await tx.insert('combos', {
				'id': combo.id,
				'nombre': combo.nombre.trim(),
				'precio_combo': combo.precioCombo,
				'activo': combo.activo ? 1 : 0,
			}, conflictAlgorithm: ConflictAlgorithm.replace);
			await tx.delete(
				'combo_miembros',
				where: 'combo_id = ?',
				whereArgs: [combo.id],
			);
			final vistos = <String>{};
			for (final miembro in combo.miembros) {
				if (miembro.productoId.isEmpty || !vistos.add(miembro.productoId)) {
					continue;
				}
				await tx.insert('combo_miembros', {
					'combo_id': combo.id,
					'producto_id': miembro.productoId,
					'cantidad_requerida': miembro.cantidadRequerida,
				}, conflictAlgorithm: ConflictAlgorithm.replace);
			}
		});
	}

	Future<List<ComboMiembro>> _miembrosDe(
		String comboId, {
		required DatabaseExecutor db,
	}) async {
		final filas = await db.query(
			'combo_miembros',
			columns: ['producto_id', 'cantidad_requerida'],
			where: 'combo_id = ?',
			whereArgs: [comboId],
		);
		return filas
			.map(
				(f) => ComboMiembro(
					productoId: f['producto_id']! as String,
					cantidadRequerida: (f['cantidad_requerida'] as num).toDouble(),
				),
			)
			.toList();
	}

	Combo _mapear(Map<String, Object?> fila, List<ComboMiembro> miembros) {
		return Combo(
			id: fila['id']! as String,
			nombre: (fila['nombre'] as String?) ?? '',
			precioCombo: (fila['precio_combo'] as num).toDouble(),
			activo: ((fila['activo'] as int?) ?? 1) == 1,
			miembros: miembros,
		);
	}
}
