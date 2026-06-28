/// Repositorio SQLite de inventario multi-tienda.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:sqflite/sqflite.dart';

/// Implementa [RepositorioInventario] sobre SQLite local.
class InventarioRepository implements RepositorioInventario {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	InventarioRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	@override
	Future<StockNivel?> obtenerStock(
		String productoId,
		String tiendaId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'stock_levels',
			where: 'producto_id = ? AND tienda_id = ?',
			whereArgs: [productoId, tiendaId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearStock(filas.first);
	}

	@override
	Future<void> guardarStock(StockNivel stock, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		await exec.insert(
			'stock_levels',
			{
				'producto_id': stock.productoId,
				'tienda_id': stock.tiendaId,
				'cantidad': stock.cantidad,
				'actualizado_en': stock.actualizadoEn.toIso8601String(),
				'stock_minimo': stock.stockMinimo,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	@override
	Future<List<StockNivel>> listarStockPorTienda(String tiendaId) async {
		final filas = await _baseDatos.query(
			'stock_levels',
			where: 'tienda_id = ?',
			whereArgs: [tiendaId],
		);
		return filas.map(_mapearStock).toList();
	}

	/// Convierte fila SQLite a [StockNivel].
	///
	/// [fila] Registro de inventario.
	/// Retorna entidad de dominio.
	/// Lista productos con stock bajo minimo en tienda.
	Future<List<StockNivel>> listarBajoMinimo(String tiendaId) async {
		final filas = await _baseDatos.query(
			'stock_levels',
			where: 'tienda_id = ? AND stock_minimo > 0 AND cantidad <= stock_minimo',
			whereArgs: [tiendaId],
		);
		return filas.map(_mapearStock).toList();
	}

	/// Elimina registros de stock del producto en todas las tiendas.
	Future<void> eliminarStockPorProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.delete(
			'stock_levels',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
	}

	StockNivel _mapearStock(Map<String, Object?> fila) {
		return StockNivel(
			productoId: fila['producto_id'] as String,
			tiendaId: fila['tienda_id'] as String,
			cantidad: fila['cantidad'] as double,
			actualizadoEn: DateTime.parse(fila['actualizado_en'] as String),
			stockMinimo: (fila['stock_minimo'] as num?)?.toDouble() ?? 0.0,
		);
	}
}
