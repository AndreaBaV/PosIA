/// Repositorio SQLite de proveedores.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste proveedores de mercancia.
class ProveedorRepository {
	ProveedorRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<List<Proveedor>> listarActivos() async {
		final filas = await _baseDatos.query(
			'proveedores',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<List<Proveedor>> listarTodos() async {
		final filas = await _baseDatos.query('proveedores', orderBy: 'nombre ASC');
		return filas.map(_mapear).toList();
	}

	Future<Proveedor?> obtenerPorId(String proveedorId) async {
		final filas = await _baseDatos.query(
			'proveedores',
			where: 'id = ?',
			whereArgs: [proveedorId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<void> guardar(Proveedor proveedor) async {
		await _baseDatos.insert(
			'proveedores',
			_mapearMapa(proveedor),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Map<String, Object?> _mapearMapa(Proveedor proveedor) {
		return {
			'id': proveedor.id,
			'nombre': proveedor.nombre,
			'contacto': proveedor.contacto,
			'telefono': proveedor.telefono,
			'activo': proveedor.activo ? 1 : 0,
			'email': proveedor.email,
			'rfc': proveedor.rfc,
			'direccion': proveedor.direccion,
			'notas': proveedor.notas,
			'dias_credito': proveedor.diasCredito,
		};
	}

	Proveedor _mapear(Map<String, Object?> fila) {
		return Proveedor(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			contacto: fila['contacto'] as String,
			telefono: fila['telefono'] as String,
			activo: (fila['activo'] as int) == 1,
			email: fila['email'] as String? ?? '',
			rfc: fila['rfc'] as String? ?? '',
			direccion: fila['direccion'] as String? ?? '',
			notas: fila['notas'] as String? ?? '',
			diasCredito: fila['dias_credito'] as int? ?? 0,
		);
	}
}
