/// Repositorio SQLite de vendedores.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Persiste personal de venta.
class VendedorRepository {
	VendedorRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	Future<List<Vendedor>> listarActivos({String? tiendaId}) async {
		if (tiendaId == null) {
			final filas = await _baseDatos.query(
				'vendedores',
				where: 'activo = 1',
				orderBy: 'nombre ASC',
			);
			return filas.map(_mapear).toList();
		}
		final filas = await _baseDatos.query(
			'vendedores',
			where: 'activo = 1 AND (tienda_id IS NULL OR tienda_id = ?)',
			whereArgs: [tiendaId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<List<Vendedor>> listarTodos({String? tiendaId}) async {
		if (tiendaId == null) {
			final filas = await _baseDatos.query('vendedores', orderBy: 'nombre ASC');
			return filas.map(_mapear).toList();
		}
		final filas = await _baseDatos.query(
			'vendedores',
			where: 'tienda_id IS NULL OR tienda_id = ?',
			whereArgs: [tiendaId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<Vendedor?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'vendedores',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<Vendedor?> obtenerPorCodigo(String codigo, {String? excluirId}) async {
		final filas = await _baseDatos.query(
			'vendedores',
			where: excluirId == null ? 'codigo = ?' : 'codigo = ? AND id != ?',
			whereArgs: excluirId == null ? [codigo] : [codigo, excluirId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	/// Genera el siguiente codigo secuencial disponible (001, 002, ...).
	Future<String> generarSiguienteCodigo() async {
		final todos = await listarTodos();
		var maximo = 0;
		for (final vendedor in todos) {
			final numerico = int.tryParse(vendedor.codigo);
			if (numerico != null && numerico > maximo) {
				maximo = numerico;
			}
		}
		return (maximo + 1).toString().padLeft(3, '0');
	}

	Future<void> guardar(Vendedor vendedor) async {
		await _padresFk.asegurarTienda(vendedor.tiendaId);
		final duplicado = await obtenerPorCodigo(vendedor.codigo, excluirId: vendedor.id);
		if (duplicado != null) {
			throw StateError('Ya existe un vendedor con el codigo ${vendedor.codigo}');
		}
		await _baseDatos.insert(
			'vendedores',
			{
				'id': vendedor.id,
				'nombre': vendedor.nombre,
				'codigo': vendedor.codigo,
				'activo': vendedor.activo ? 1 : 0,
				'tienda_id': vendedor.tiendaId,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Vendedor _mapear(Map<String, Object?> fila) {
		return Vendedor(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			codigo: fila['codigo'] as String,
			activo: (fila['activo'] as int) == 1,
			tiendaId: fila['tienda_id'] as String?,
		);
	}
}
