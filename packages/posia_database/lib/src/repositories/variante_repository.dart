/// Repositorio SQLite de variantes o presentaciones de producto.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Persiste presentaciones comerciales bajo un producto padre.
class VarianteRepository {
	VarianteRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<VarianteProducto?> obtenerPorId(String varianteId) async {
		final filas = await _baseDatos.query(
			'product_variants',
			where: 'id = ?',
			whereArgs: [varianteId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<List<VarianteProducto>> listarPorProductoPadre(String productoPadreId) async {
		final filas = await _baseDatos.query(
			'product_variants',
			where: 'producto_padre_id = ?',
			whereArgs: [productoPadreId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<List<VarianteProducto>> listarActivasPorProductoPadre(
		String productoPadreId,
	) async {
		final filas = await _baseDatos.query(
			'product_variants',
			where: 'producto_padre_id = ? AND activo = 1',
			whereArgs: [productoPadreId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<VarianteProducto?> buscarPorCodigoBarras(String codigoBarras) async {
		final filas = await _baseDatos.query(
			'product_variants',
			where: 'codigo_barras = ? AND activo = 1',
			whereArgs: [codigoBarras],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<int> contarActivasPorProducto(String productoPadreId) async {
		return Sqflite.firstIntValue(
				await _baseDatos.rawQuery(
					'SELECT COUNT(*) FROM product_variants '
					'WHERE producto_padre_id = ? AND activo = 1',
					[productoPadreId],
				),
			) ??
			0;
	}

	Future<void> guardar(VarianteProducto variante) async {
		await _padresFk.asegurarProducto(variante.productoPadreId);
		await _baseDatos.insert(
			'product_variants',
			{
				'id': variante.id,
				'producto_padre_id': variante.productoPadreId,
				'nombre': variante.nombre,
				'sku': variante.sku,
				'codigo_barras': variante.codigoBarras,
				'precio_base': variante.precioBase,
				'activo': variante.activo ? 1 : 0,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<void> eliminarPorProductoPadre(
		String productoPadreId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.delete(
			'product_variants',
			where: 'producto_padre_id = ?',
			whereArgs: [productoPadreId],
		);
	}

	VarianteProducto _mapear(Map<String, Object?> fila) {
		return VarianteProducto(
			id: fila['id'] as String,
			productoPadreId: fila['producto_padre_id'] as String,
			nombre: fila['nombre'] as String,
			sku: fila['sku'] as String,
			codigoBarras: fila['codigo_barras'] as String,
			precioBase: (fila['precio_base'] as num).toDouble(),
			activo: (fila['activo'] as int) == 1,
		);
	}
}
