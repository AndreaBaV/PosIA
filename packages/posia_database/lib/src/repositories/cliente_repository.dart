/// Repositorio SQLite de clientes comerciales.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste y consulta clientes locales.
class ClienteRepository {
	ClienteRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<List<Cliente>> listarTodos() async {
		final filas = await _baseDatos.query('customers', orderBy: 'nombre ASC');
		return filas.map(_mapearCliente).toList();
	}

	Future<List<Cliente>> listarActivos() async {
		final filas = await _baseDatos.query(
			'customers',
			where: 'activo = 1',
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearCliente).toList();
	}

	Future<Cliente?> obtenerPorId(String clienteId) async {
		final filas = await _baseDatos.query(
			'customers',
			where: 'id = ?',
			whereArgs: [clienteId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearCliente(filas.first);
	}

	Future<void> guardar(Cliente cliente) async {
		await _baseDatos.insert(
			'customers',
			_mapearMapa(cliente),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Map<String, Object?> _mapearMapa(Cliente cliente) {
		return {
			'id': cliente.id,
			'nombre': cliente.nombre,
			'lista_precios_id': cliente.listaPreciosId,
			'credito_habilitado': cliente.creditoHabilitado ? 1 : 0,
			'activo': cliente.activo ? 1 : 0,
			'telefono': cliente.telefono,
			'email': cliente.email,
			'rfc': cliente.rfc,
			'direccion': cliente.direccion,
			'notas': cliente.notas,
		};
	}

	Cliente _mapearCliente(Map<String, Object?> fila) {
		return Cliente(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			listaPreciosId: fila['lista_precios_id'] as String?,
			creditoHabilitado: (fila['credito_habilitado'] as int) == 1,
			activo: (fila['activo'] as int) == 1,
			telefono: fila['telefono'] as String? ?? '',
			email: fila['email'] as String? ?? '',
			rfc: fila['rfc'] as String? ?? '',
			direccion: fila['direccion'] as String? ?? '',
			notas: fila['notas'] as String? ?? '',
		);
	}
}
