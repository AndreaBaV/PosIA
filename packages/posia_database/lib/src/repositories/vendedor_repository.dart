/// Repositorio SQLite de vendedores.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste personal de venta.
class VendedorRepository {
	VendedorRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<List<Vendedor>> listarActivos() async {
		final filas = await _baseDatos.query(
			'vendedores',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<List<Vendedor>> listarTodos() async {
		final filas = await _baseDatos.query('vendedores', orderBy: 'nombre ASC');
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

	Future<void> guardar(Vendedor vendedor) async {
		await _baseDatos.insert(
			'vendedores',
			{
				'id': vendedor.id,
				'nombre': vendedor.nombre,
				'codigo': vendedor.codigo,
				'activo': vendedor.activo ? 1 : 0,
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
		);
	}
}
