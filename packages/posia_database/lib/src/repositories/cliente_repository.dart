/// Repositorio SQLite de clientes comerciales.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Persiste y consulta clientes locales.
class ClienteRepository {
	ClienteRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

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

	Future<List<Cliente>> listarActivosPorLista(String listaPreciosId) async {
		final filas = await _baseDatos.query(
			'customers',
			where: 'activo = 1 AND lista_precios_id = ?',
			whereArgs: [listaPreciosId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearCliente).toList();
	}

	/// Clientes asignados a una lista de precios (activos e inactivos).
	Future<List<Cliente>> listarPorLista(String listaPreciosId) async {
		final filas = await _baseDatos.query(
			'customers',
			where: 'lista_precios_id = ?',
			whereArgs: [listaPreciosId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearCliente).toList();
	}

	/// Quita la asignacion de lista de precios de todos los clientes.
	Future<void> desvincularListaPrecios(
		String listaPreciosId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.update(
			'customers',
			{'lista_precios_id': null},
			where: 'lista_precios_id = ?',
			whereArgs: [listaPreciosId],
		);
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
		await _padresFk.asegurarListaPrecios(cliente.listaPreciosId);
		// Sin ConflictAlgorithm.replace: borraria la fila y el ON DELETE CASCADE
		// se llevaria customer_product_prices y customer_discounts, es decir los
		// precios especiales y descuentos del cliente. Ver la misma correccion en
		// ProductoRepository.guardar.
		final datos = _mapearMapa(cliente);
		final filasActualizadas = await _baseDatos.update(
			'customers',
			datos,
			where: 'id = ?',
			whereArgs: [cliente.id],
		);
		if (filasActualizadas == 0) {
			await _baseDatos.insert(
				'customers',
				datos,
				conflictAlgorithm: ConflictAlgorithm.ignore,
			);
		}
	}

	/// Elimina cliente y datos comerciales vinculados (descuentos, precios especiales).
	Future<void> eliminar(String clienteId) async {
		await _baseDatos.transaction((tx) async {
			await tx.delete(
				'customer_discounts',
				where: 'cliente_id = ?',
				whereArgs: [clienteId],
			);
			await tx.delete(
				'customer_product_prices',
				where: 'cliente_id = ?',
				whereArgs: [clienteId],
			);
			await tx.delete(
				'customers',
				where: 'id = ?',
				whereArgs: [clienteId],
			);
		});
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
			'dias_credito': cliente.diasCredito,
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
			diasCredito: (fila['dias_credito'] as int?) ?? DIAS_CREDITO_PREDETERMINADO,
		);
	}
}
