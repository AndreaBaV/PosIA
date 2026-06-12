/// Repositorio SQLite de lotes farmaceuticos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_module_pharmacy/posia_module_pharmacy.dart';
import 'package:sqflite/sqflite.dart';

/// Implementa persistencia de lotes con caducidad para farmacia.
class LoteFarmaciaRepository implements RepositorioLoteFarmacia {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	LoteFarmaciaRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	@override
	Future<List<LoteFarmacia>> listarDisponiblesPorProducto(
		String productoId,
		String tiendaId,
	) async {
		final filas = await _baseDatos.query(
			'pharmacy_lots',
			where: 'producto_id = ? AND tienda_id = ? AND activo = 1 AND cantidad > 0',
			whereArgs: [productoId, tiendaId],
			orderBy: 'caduca_en ASC',
		);
		return filas.map(_mapearLote).toList();
	}

	@override
	Future<LoteFarmacia?> obtenerPorId(String loteId) async {
		final filas = await _baseDatos.query(
			'pharmacy_lots',
			where: 'id = ?',
			whereArgs: [loteId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearLote(filas.first);
	}

	@override
	Future<void> descontarCantidad(String loteId, double cantidad) async {
		final lote = await obtenerPorId(loteId);
		if (lote == null) {
			return;
		}
		final cantidadNueva = lote.cantidad - cantidad;
		await _baseDatos.update(
			'pharmacy_lots',
			{'cantidad': cantidadNueva < 0.0 ? 0.0 : cantidadNueva},
			where: 'id = ?',
			whereArgs: [loteId],
		);
	}

	@override
	Future<List<LoteFarmacia>> listarPorTienda(String tiendaId) async {
		final filas = await _baseDatos.query(
			'pharmacy_lots',
			where: 'tienda_id = ? AND activo = 1',
			whereArgs: [tiendaId],
			orderBy: 'caduca_en ASC',
		);
		return filas.map(_mapearLote).toList();
	}

	@override
	Future<void> guardar(LoteFarmacia lote) async {
		await _baseDatos.insert(
			'pharmacy_lots',
			{
				'id': lote.id,
				'producto_id': lote.productoId,
				'tienda_id': lote.tiendaId,
				'numero_lote': lote.numeroLote,
				'caduca_en': lote.caducaEn.toIso8601String(),
				'cantidad': lote.cantidad,
				'activo': lote.activo ? 1 : 0,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Convierte fila SQLite a entidad [LoteFarmacia].
	///
	/// [fila] Registro de lote.
	/// Retorna instancia de dominio.
	LoteFarmacia _mapearLote(Map<String, Object?> fila) {
		return LoteFarmacia(
			id: fila['id'] as String,
			productoId: fila['producto_id'] as String,
			tiendaId: fila['tienda_id'] as String,
			numeroLote: fila['numero_lote'] as String,
			caducaEn: DateTime.parse(fila['caduca_en'] as String),
			cantidad: fila['cantidad'] as double,
			activo: (fila['activo'] as int) == 1,
		);
	}
}
