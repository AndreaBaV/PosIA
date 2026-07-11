/// Repositorio SQLite de descuentos por cliente.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste reglas de descuento comercial por cliente.
class DescuentoClienteRepository {
	DescuentoClienteRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<List<DescuentoCliente>> listarPorCliente(String clienteId) async {
		final filas = await _baseDatos.query(
			'customer_discounts',
			where: 'cliente_id = ?',
			whereArgs: [clienteId],
			orderBy: 'tipo ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<List<DescuentoCliente>> listarActivosPorCliente(String clienteId) async {
		final filas = await _baseDatos.query(
			'customer_discounts',
			where: 'cliente_id = ? AND activo = 1',
			whereArgs: [clienteId],
			orderBy: 'tipo ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<List<DescuentoCliente>> listarTodos() async {
		final filas = await _baseDatos.query(
			'customer_discounts',
			orderBy: 'cliente_id ASC, tipo ASC',
		);
		return filas.map(_mapear).toList();
	}

	Future<void> guardar(DescuentoCliente descuento) async {
		await _baseDatos.insert(
			'customer_discounts',
			{
				'id': descuento.id,
				'cliente_id': descuento.clienteId,
				'tipo': descuento.tipo.name,
				'valor': descuento.valor,
				'producto_id': descuento.productoId,
				'condicion': descuento.condicion.name,
				'umbral': descuento.umbral,
				'activo': descuento.activo ? 1 : 0,
				'descripcion': descuento.descripcion,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<void> eliminarPorCliente(String clienteId) async {
		await _baseDatos.delete(
			'customer_discounts',
			where: 'cliente_id = ?',
			whereArgs: [clienteId],
		);
	}

	Future<void> eliminar(String id) async {
		await _baseDatos.delete(
			'customer_discounts',
			where: 'id = ?',
			whereArgs: [id],
		);
	}

	DescuentoCliente _mapear(Map<String, Object?> fila) {
		return DescuentoCliente(
			id: fila['id'] as String,
			clienteId: fila['cliente_id'] as String,
			tipo: TipoDescuentoCliente.values.byName(fila['tipo'] as String),
			valor: (fila['valor'] as num).toDouble(),
			productoId: fila['producto_id'] as String?,
			condicion: CondicionDescuentoCliente.values.byName(fila['condicion'] as String),
			umbral: (fila['umbral'] as num?)?.toDouble(),
			activo: (fila['activo'] as int) == 1,
			descripcion: fila['descripcion'] as String? ?? '',
		);
	}
}
