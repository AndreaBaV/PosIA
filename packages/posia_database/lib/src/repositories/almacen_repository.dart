/// Repositorio SQLite de almacenes.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste almacenes y stock por almacen.
class AlmacenRepository {
	AlmacenRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<List<Almacen>> listarActivos() async {
		final filas = await _baseDatos.query(
			'almacenes',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearAlmacen).toList();
	}

	Future<List<Almacen>> listarTodos() async {
		final filas = await _baseDatos.query(
			'almacenes',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearAlmacen).toList();
	}

	Future<Almacen?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'almacenes',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearAlmacen(filas.first);
	}

	Future<void> guardar(Almacen almacen) async {
		await _baseDatos.insert(
			'almacenes',
			{
				'id': almacen.id,
				'nombre': almacen.nombre,
				'tienda_id': almacen.tiendaId,
				'activo': almacen.activo ? 1 : 0,
				'latitud': almacen.latitud,
				'longitud': almacen.longitud,
				'radio_metros': almacen.radioMetros,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<StockAlmacen?> obtenerStock(
		String productoId,
		String almacenId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'stock_almacen',
			where: 'producto_id = ? AND almacen_id = ?',
			whereArgs: [productoId, almacenId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearStock(filas.first);
	}

	Future<void> guardarStock(StockAlmacen stock, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		await exec.insert(
			'stock_almacen',
			{
				'producto_id': stock.productoId,
				'almacen_id': stock.almacenId,
				'cantidad': stock.cantidad,
				'actualizado_en': stock.actualizadoEn.toIso8601String(),
				'stock_minimo': stock.stockMinimo,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<List<StockAlmacen>> listarStockPorAlmacen(String almacenId) async {
		final filas = await _baseDatos.query(
			'stock_almacen',
			where: 'almacen_id = ?',
			whereArgs: [almacenId],
		);
		return filas.map(_mapearStock).toList();
	}

	Future<List<StockAlmacen>> listarStockPorProducto(String productoId) async {
		final filas = await _baseDatos.query(
			'stock_almacen',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
		return filas.map(_mapearStock).toList();
	}

	Future<List<StockAlmacen>> listarTodoStock() async {
		final filas = await _baseDatos.query('stock_almacen');
		return filas.map(_mapearStock).toList();
	}

	Almacen _mapearAlmacen(Map<String, Object?> fila) {
		return Almacen(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			tiendaId: fila['tienda_id'] as String?,
			activo: (fila['activo'] as int) == 1,
			latitud: (fila['latitud'] as num?)?.toDouble(),
			longitud: (fila['longitud'] as num?)?.toDouble(),
			radioMetros: (fila['radio_metros'] as num?)?.toDouble() ?? 150,
		);
	}

	StockAlmacen _mapearStock(Map<String, Object?> fila) {
		return StockAlmacen(
			productoId: fila['producto_id'] as String,
			almacenId: fila['almacen_id'] as String,
			cantidad: (fila['cantidad'] as num).toDouble(),
			actualizadoEn: DateTime.parse(fila['actualizado_en'] as String),
			stockMinimo: (fila['stock_minimo'] as num?)?.toDouble() ?? 0,
		);
	}
}
