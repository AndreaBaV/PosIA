/// Repositorio SQLite de categorias de productos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste categorias personalizables de catalogo.
class CategoriaRepository {
	/// Crea repositorio con conexion SQLite activa.
	CategoriaRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Lista categorias activas ordenadas.
	Future<List<Categoria>> listarActivas() async {
		final filas = await _baseDatos.query(
			'categories',
			where: 'activa = 1',
			orderBy: 'orden ASC, nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	/// Obtiene categoria por identificador, o null si no existe.
	Future<Categoria?> obtenerPorId(String categoriaId) async {
		final filas = await _baseDatos.query(
			'categories',
			where: 'id = ?',
			whereArgs: [categoriaId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	/// Lista todas las categorias para administracion.
	Future<List<Categoria>> listarTodas() async {
		final filas = await _baseDatos.query(
			'categories',
			orderBy: 'orden ASC, nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	/// Guarda o reemplaza categoria.
	Future<void> guardar(Categoria categoria) async {
		await _baseDatos.insert(
			'categories',
			_mapearMapa(categoria),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Categoria _mapear(Map<String, Object?> fila) {
		return Categoria(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			icono: fila['icono'] as String,
			colorHex: fila['color_hex'] as String,
			orden: fila['orden'] as int,
			activa: (fila['activa'] as int) == 1,
		);
	}

	Map<String, Object?> _mapearMapa(Categoria categoria) {
		return {
			'id': categoria.id,
			'nombre': categoria.nombre,
			'icono': categoria.icono,
			'color_hex': categoria.colorHex,
			'orden': categoria.orden,
			'activa': categoria.activa ? 1 : 0,
		};
	}
}
