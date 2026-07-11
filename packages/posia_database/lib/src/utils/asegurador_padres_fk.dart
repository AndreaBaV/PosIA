/// Garantiza filas padre antes de escrituras con FOREIGN KEY (sync v33).
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Inserta stubs minimos cuando un evento hijo llega antes que su padre.
class AseguradorPadresFk {
	AseguradorPadresFk(this._baseDatos);

	final Database _baseDatos;

	Future<void> asegurarTienda(String? tiendaId) async {
		if (tiendaId == null || tiendaId.trim().isEmpty) {
			return;
		}
		final existente = await _baseDatos.query(
			'stores',
			where: 'id = ?',
			whereArgs: [tiendaId],
			limit: 1,
		);
		if (existente.isNotEmpty) {
			return;
		}
		await _baseDatos.insert(
			'stores',
			{
				'id': tiendaId,
				'nombre': 'Tienda',
				'direccion': '',
				'activa': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarListaPrecios(String? listaId) async {
		if (listaId == null || listaId.trim().isEmpty) {
			return;
		}
		final existente = await _baseDatos.query(
			'price_lists',
			where: 'id = ?',
			whereArgs: [listaId],
			limit: 1,
		);
		if (existente.isNotEmpty) {
			return;
		}
		await _baseDatos.insert(
			'price_lists',
			{
				'id': listaId,
				'nombre': 'Lista de precios',
				'activa': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarCliente(String? clienteId) async {
		if (clienteId == null || clienteId.trim().isEmpty) {
			return;
		}
		final existente = await _baseDatos.query(
			'customers',
			where: 'id = ?',
			whereArgs: [clienteId],
			limit: 1,
		);
		if (existente.isNotEmpty) {
			return;
		}
		await _baseDatos.insert(
			'customers',
			{
				'id': clienteId,
				'nombre': 'Cliente',
				'lista_precios_id': null,
				'credito_habilitado': 0,
				'activo': 1,
				'telefono': '',
				'email': '',
				'rfc': '',
				'direccion': '',
				'notas': '',
				'dias_credito': DIAS_CREDITO_PREDETERMINADO,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarProducto(
		String? productoId, {
		String? tiendaId,
	}) async {
		if (productoId == null || productoId.trim().isEmpty) {
			return;
		}
		final existente = await _baseDatos.query(
			'products',
			where: 'id = ?',
			whereArgs: [productoId],
			limit: 1,
		);
		if (existente.isNotEmpty) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true
			? tiendaId!.trim()
			: 'tienda-sync';
		await asegurarTienda(tienda);
		await _baseDatos.insert(
			'products',
			{
				'id': productoId,
				'nombre': 'Producto',
				'codigo_barras': '',
				'precio_base': 0.0,
				'unidad_medida': UnidadMedida.pieza.name,
				'ruta_imagen': '',
				'activo': 1,
				'tienda_id': tienda,
				'modulo_vertical': ModuloVertical.general.name,
				'notas': '',
				'costo_unitario': 0.0,
				'favorito_caja': 0,
				'permite_stock_negativo': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarRolPersonalizado(
		String? rolId, {
		String? tiendaId,
	}) async {
		if (rolId == null || rolId.trim().isEmpty) {
			return;
		}
		final existente = await _baseDatos.query(
			'roles_personalizados',
			where: 'id = ?',
			whereArgs: [rolId],
			limit: 1,
		);
		if (existente.isNotEmpty) {
			return;
		}
		if (tiendaId != null && tiendaId.trim().isNotEmpty) {
			await asegurarTienda(tiendaId);
		}
		await _baseDatos.insert(
			'roles_personalizados',
			{
				'id': rolId,
				'nombre': 'Rol',
				'descripcion': '',
				'permisos_json': '[]',
				'categorias_json': '[]',
				'activo': 1,
				'tienda_id': tiendaId,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}
}
