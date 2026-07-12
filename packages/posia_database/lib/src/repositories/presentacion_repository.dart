/// Repositorio de tipos y presentaciones de producto.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';
import '../utils/transaccion_sqlite.dart';

/// Persiste catalogo de presentaciones comerciales.
class PresentacionRepository {
	PresentacionRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<List<TipoPresentacion>> listarTiposActivos() async {
		final filas = await _baseDatos.query(
			'tipos_presentacion',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearTipo).toList();
	}

	Future<List<TipoPresentacion>> listarTodosTipos() async {
		final filas = await _baseDatos.query(
			'tipos_presentacion',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearTipo).toList();
	}

	Future<void> guardarTipo(TipoPresentacion tipo) async {
		await _baseDatos.insert(
			'tipos_presentacion',
			{
				'id': tipo.id,
				'nombre': tipo.nombre,
				'unidad': tipo.unidad,
				'activo': tipo.activo ? 1 : 0,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<List<PresentacionProducto>> listarPorProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'presentaciones_producto',
			where: 'producto_id = ?',
			whereArgs: [productoId],
			orderBy: 'es_presentacion_base DESC, nombre ASC',
		);
		return filas.map(_mapearPresentacion).toList();
	}

	Future<List<PresentacionProducto>> listarActivasPorProducto(
		String productoId,
	) async {
		final filas = await _baseDatos.query(
			'presentaciones_producto',
			where: 'producto_id = ? AND activo = 1',
			whereArgs: [productoId],
			orderBy: 'es_presentacion_base DESC, nombre ASC',
		);
		return filas.map(_mapearPresentacion).toList();
	}

	Future<PresentacionProducto?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'presentaciones_producto',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearPresentacion(filas.first);
	}

	Future<PresentacionProducto?> buscarPorCodigoBarras(String codigo) async {
		if (codigo.trim().isEmpty) {
			return null;
		}
		final filas = await _baseDatos.query(
			'presentaciones_producto',
			where: 'codigo_barras = ? AND activo = 1',
			whereArgs: [codigo.trim()],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearPresentacion(filas.first);
	}

	Future<void> guardarPresentacion(
		PresentacionProducto presentacion, {
		DatabaseExecutor? db,
	}) async {
		await _padresFk.asegurarPadresDePresentacion(presentacion);
		final exec = db ?? _baseDatos;
		await exec.insert(
			'presentaciones_producto',
			{
				'id': presentacion.id,
				'producto_id': presentacion.productoId,
				'tipo_presentacion_id': presentacion.tipoPresentacionId,
				'nombre': presentacion.nombre,
				'factor_a_base': presentacion.factorABase,
				'es_presentacion_base': presentacion.esPresentacionBase ? 1 : 0,
				'codigo_barras': presentacion.codigoBarras,
				'precio': presentacion.precio,
				'activo': presentacion.activo ? 1 : 0,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Reemplaza todas las presentaciones de un producto (sync remoto).
	Future<void> reemplazarPresentacionesProducto(
		String productoId,
		List<PresentacionProducto> presentaciones, {
		DatabaseExecutor? db,
	}) async {
		await _padresFk.asegurarProducto(productoId);
		await ejecutarEscrituraTransaccional(_baseDatos, db, (transaccion) async {
			await transaccion.delete(
				'presentaciones_producto',
				where: 'producto_id = ?',
				whereArgs: [productoId],
			);
			for (final presentacion in presentaciones) {
				await _padresFk.asegurarPadresDePresentacion(presentacion);
				await transaccion.insert(
					'presentaciones_producto',
					{
						'id': presentacion.id,
						'producto_id': productoId,
						'tipo_presentacion_id': presentacion.tipoPresentacionId,
						'nombre': presentacion.nombre,
						'factor_a_base': presentacion.factorABase,
						'es_presentacion_base':
							presentacion.esPresentacionBase ? 1 : 0,
						'codigo_barras': presentacion.codigoBarras,
						'precio': presentacion.precio,
						'activo': presentacion.activo ? 1 : 0,
					},
					conflictAlgorithm: ConflictAlgorithm.replace,
				);
			}
		});
	}

	TipoPresentacion _mapearTipo(Map<String, Object?> fila) {
		return TipoPresentacion(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			unidad: fila['unidad'] as String,
			activo: (fila['activo'] as int) == 1,
		);
	}

	PresentacionProducto _mapearPresentacion(Map<String, Object?> fila) {
		return PresentacionProducto(
			id: fila['id'] as String,
			productoId: fila['producto_id'] as String,
			tipoPresentacionId: fila['tipo_presentacion_id'] as String?,
			nombre: fila['nombre'] as String,
			factorABase: (fila['factor_a_base'] as num).toDouble(),
			esPresentacionBase: (fila['es_presentacion_base'] as int) == 1,
			codigoBarras: fila['codigo_barras'] as String? ?? '',
			precio: (fila['precio'] as num?)?.toDouble(),
			activo: (fila['activo'] as int) == 1,
		);
	}
}
