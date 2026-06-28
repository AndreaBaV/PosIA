/// Repositorio SQLite de movimientos de inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Ledger de entradas, salidas y ajustes.
class MovimientoInventarioRepository {
	MovimientoInventarioRepository({required Database baseDatos})
		: _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<void> guardar(MovimientoInventario movimiento, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		await exec.insert('inventory_movements', {
			'id': movimiento.id,
			'producto_id': movimiento.productoId,
			'tienda_id': movimiento.tiendaId,
			'tipo': movimiento.tipo.name,
			'cantidad': movimiento.cantidad,
			'cantidad_anterior': movimiento.cantidadAnterior,
			'cantidad_nueva': movimiento.cantidadNueva,
			'motivo': movimiento.motivo,
			'referencia_id': movimiento.referenciaId,
			'proveedor_id': movimiento.proveedorId,
			'creado_en': movimiento.creadoEn.toIso8601String(),
			'creado_por': movimiento.creadoPor,
		});
	}

	Future<List<MovimientoInventario>> listarPorTienda(
		String tiendaId, {
		int limite = 50,
	}) async {
		final filas = await _baseDatos.query(
			'inventory_movements',
			where: 'tienda_id = ?',
			whereArgs: [tiendaId],
			orderBy: 'creado_en DESC',
			limit: limite,
		);
		return filas.map(_mapear).toList();
	}

	MovimientoInventario _mapear(Map<String, Object?> fila) {
		return MovimientoInventario(
			id: fila['id'] as String,
			productoId: fila['producto_id'] as String,
			tiendaId: fila['tienda_id'] as String,
			tipo: TipoMovimientoInventario.values.byName(fila['tipo'] as String),
			cantidad: fila['cantidad'] as double,
			cantidadAnterior: fila['cantidad_anterior'] as double,
			cantidadNueva: fila['cantidad_nueva'] as double,
			motivo: fila['motivo'] as String,
			referenciaId: fila['referencia_id'] as String?,
			proveedorId: fila['proveedor_id'] as String?,
			creadoEn: DateTime.parse(fila['creado_en'] as String),
			creadoPor: fila['creado_por'] as String?,
		);
	}
}
