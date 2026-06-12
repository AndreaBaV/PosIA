/// Repositorio SQLite de reglas de precio comercial.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_pricing/posia_pricing.dart';
import 'package:sqflite/sqflite.dart';

/// Implementa [RepositorioPrecio] sobre SQLite local.
class PrecioRepository implements RepositorioPrecio {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	PrecioRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	@override
	Future<PrecioClienteProducto?> obtenerPrecioClienteProducto(
		String clienteId,
		String productoId,
	) async {
		final filas = await _baseDatos.query(
			'customer_product_prices',
			where: 'cliente_id = ? AND producto_id = ?',
			whereArgs: [clienteId, productoId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		final fila = filas.first;
		return PrecioClienteProducto(
			clienteId: clienteId,
			productoId: productoId,
			precioUnitario: fila['precio_unitario'] as double,
		);
	}

	@override
	Future<double?> obtenerPrecioLista(String listaPreciosId, String productoId) async {
		final filas = await _baseDatos.query(
			'price_list_items',
			where: 'lista_precios_id = ? AND producto_id = ?',
			whereArgs: [listaPreciosId, productoId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return filas.first['precio_unitario'] as double;
	}

	@override
	Future<List<EscalaMayoreo>> obtenerEscalasMayoreo(String productoId) async {
		final filas = await _baseDatos.query(
			'wholesale_tiers',
			where: 'producto_id = ?',
			whereArgs: [productoId],
			orderBy: 'cantidad_minima ASC',
		);
		return filas
			.map(
				(fila) => EscalaMayoreo(
					productoId: productoId,
					cantidadMinima: fila['cantidad_minima'] as double,
					precioUnitario: fila['precio_unitario'] as double,
				),
			)
			.toList();
	}

	/// Inserta escala de mayoreo para producto.
	///
	/// [escala] Escala comercial a registrar.
	Future<void> guardarEscalaMayoreo(EscalaMayoreo escala) async {
		await _baseDatos.insert('wholesale_tiers', {
			'producto_id': escala.productoId,
			'cantidad_minima': escala.cantidadMinima,
			'precio_unitario': escala.precioUnitario,
		}		);
	}

	/// Elimina escalas de mayoreo de un producto.
	Future<void> eliminarEscalasPorProducto(String productoId) async {
		await _baseDatos.delete(
			'wholesale_tiers',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
	}

	/// Reemplaza todas las escalas de mayoreo de un producto.
	Future<void> reemplazarEscalasMayoreo(
		String productoId,
		List<EscalaMayoreo> escalas,
	) async {
		await _baseDatos.transaction((transaccion) async {
			await transaccion.delete(
				'wholesale_tiers',
				where: 'producto_id = ?',
				whereArgs: [productoId],
			);
			for (final escala in escalas) {
				await transaccion.insert('wholesale_tiers', {
					'producto_id': productoId,
					'cantidad_minima': escala.cantidadMinima,
					'precio_unitario': escala.precioUnitario,
				});
			}
		});
	}

	/// Inserta precio preferencial cliente-producto.
	///
	/// [precio] Registro de precio especial.
	Future<void> guardarPrecioClienteProducto(PrecioClienteProducto precio) async {
		await _baseDatos.insert(
			'customer_product_prices',
			{
				'cliente_id': precio.clienteId,
				'producto_id': precio.productoId,
				'precio_unitario': precio.precioUnitario,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Inserta precio de lista comercial.
	///
	/// [listaPreciosId] Identificador de lista.
	/// [productoId] Producto incluido.
	/// [precioUnitario] Precio en MXN.
	Future<void> guardarPrecioLista(
		String listaPreciosId,
		String productoId,
		double precioUnitario,
	) async {
		await _baseDatos.insert(
			'price_list_items',
			{
				'lista_precios_id': listaPreciosId,
				'producto_id': productoId,
				'precio_unitario': precioUnitario,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}
}
