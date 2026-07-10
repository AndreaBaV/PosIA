/// Repositorio SQLite de reglas de precio comercial.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/transaccion_sqlite.dart';
import 'lote_promocion_repository.dart';

/// Implementa [RepositorioPrecio] sobre SQLite local.
class PrecioRepository implements RepositorioPrecio {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	PrecioRepository({
		required Database baseDatos,
		LotePromocionRepository? lotePromocionRepository,
	}) : _baseDatos = baseDatos,
	     _lotePromocionRepository =
	         lotePromocionRepository ??
	         LotePromocionRepository(baseDatos: baseDatos);

	final Database _baseDatos;
	final LotePromocionRepository _lotePromocionRepository;

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
		final escalasMayoreo = filas
			.map(
				(fila) => EscalaMayoreo(
					productoId: productoId,
					cantidadMinima: fila['cantidad_minima'] as double,
					precioUnitario: fila['precio_unitario'] as double,
				),
			)
			.toList();
		final escalasEmpaque = await _escalasDesdePresentaciones(productoId);
		if (escalasEmpaque.isEmpty) {
			return escalasMayoreo;
		}
		final fusionadas = fusionarEscalasMayoreo(
			escalasMayoreo: escalasMayoreo.map(
				(e) => (
					cantidadMinima: e.cantidadMinima,
					precioUnitario: e.precioUnitario,
				),
			),
			escalasEmpaque: escalasEmpaque,
		);
		return fusionadas
			.map(
				(e) => EscalaMayoreo(
					productoId: productoId,
					cantidadMinima: e.cantidadMinima,
					precioUnitario: e.precioUnitario,
				),
			)
			.toList();
	}

	@override
	Future<LotePromocion?> obtenerLotePromocionPorProducto(String productoId) {
		return _lotePromocionRepository.obtenerPorProducto(productoId);
	}

	/// Escalas guardadas en wholesale_tiers (sin fusionar presentaciones).
	Future<List<EscalaMayoreo>> listarEscalasMayoreoPersistidas(
		String productoId,
	) async {
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
					cantidadMinima: (fila['cantidad_minima'] as num).toDouble(),
					precioUnitario: (fila['precio_unitario'] as num).toDouble(),
				),
			)
			.toList();
	}

	/// Todos los precios preferenciales cliente-producto.
	Future<List<PrecioClienteProducto>> listarTodosPreciosClienteProducto() async {
		final filas = await _baseDatos.query('customer_product_prices');
		return filas
			.map(
				(fila) => PrecioClienteProducto(
					clienteId: fila['cliente_id'] as String,
					productoId: fila['producto_id'] as String,
					precioUnitario: (fila['precio_unitario'] as num).toDouble(),
				),
			)
			.toList();
	}

	Future<List<EscalaMayoreoRef>> _escalasDesdePresentaciones(
		String productoId,
	) async {
		final filas = await _baseDatos.rawQuery(
			'''
			SELECT pp.factor_a_base, pp.precio, p.precio_base
			FROM presentaciones_producto pp
			INNER JOIN products p ON p.id = pp.producto_id
			WHERE pp.producto_id = ?
			  AND pp.activo = 1
			  AND pp.es_presentacion_base = 0
			''',
			[productoId],
		);
		final escalas = <EscalaMayoreoRef>[];
		for (final fila in filas) {
			final factor = (fila['factor_a_base'] as num?)?.toDouble() ?? 0.0;
			if (factor <= 0.0) {
				continue;
			}
			final precioBase = (fila['precio_base'] as num?)?.toDouble() ?? 0.0;
			final precioTotal = (fila['precio'] as num?)?.toDouble() ??
				redondearMonto(precioBase * factor);
			if (precioTotal <= 0.0) {
				continue;
			}
			escalas.add((
				cantidadMinima: factor,
				precioUnitario: redondearMonto(precioTotal / factor),
			));
		}
		return escalas;
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
	Future<void> eliminarEscalasPorProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.delete(
			'wholesale_tiers',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
	}

	/// Reemplaza todas las escalas de mayoreo de un producto.
	Future<void> reemplazarEscalasMayoreo(
		String productoId,
		List<EscalaMayoreo> escalas, {
		DatabaseExecutor? db,
	}) async {
		await ejecutarEscrituraTransaccional(_baseDatos, db, (transaccion) async {
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

	Future<List<PrecioClienteProducto>> listarPreciosPorCliente(String clienteId) async {
		final filas = await _baseDatos.query(
			'customer_product_prices',
			where: 'cliente_id = ?',
			whereArgs: [clienteId],
		);
		return filas
			.map(
				(fila) => PrecioClienteProducto(
					clienteId: clienteId,
					productoId: fila['producto_id'] as String,
					precioUnitario: (fila['precio_unitario'] as num).toDouble(),
				),
			)
			.toList();
	}

	Future<void> eliminarPreciosPorCliente(String clienteId) async {
		await _baseDatos.delete(
			'customer_product_prices',
			where: 'cliente_id = ?',
			whereArgs: [clienteId],
		);
	}

	Future<void> eliminarPrecioClienteProducto(String clienteId, String productoId) async {
		await _baseDatos.delete(
			'customer_product_prices',
			where: 'cliente_id = ? AND producto_id = ?',
			whereArgs: [clienteId, productoId],
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

	/// Quita un producto de una lista comercial.
	Future<void> eliminarPrecioDeLista(String listaPreciosId, String productoId) async {
		await _baseDatos.delete(
			'price_list_items',
			where: 'lista_precios_id = ? AND producto_id = ?',
			whereArgs: [listaPreciosId, productoId],
		);
	}

	/// Elimina precios de listas y clientes asociados al producto.
	Future<void> eliminarPreciosPorProducto(
		String productoId, {
		DatabaseExecutor? db,
	}) async {
		await ejecutarEscrituraTransaccional(_baseDatos, db, (exec) async {
			await exec.delete(
				'price_list_items',
				where: 'producto_id = ?',
				whereArgs: [productoId],
			);
			await exec.delete(
				'customer_product_prices',
				where: 'producto_id = ?',
				whereArgs: [productoId],
			);
		});
	}

	/// Lista catalogos de precios activos.
	Future<List<ListaPrecios>> listarListasActivas() async {
		final filas = await _baseDatos.query(
			'price_lists',
			where: 'activa = 1',
			orderBy: 'nombre ASC',
		);
		return filas
			.map(
				(f) => ListaPrecios(
					id: f['id'] as String,
					nombre: f['nombre'] as String,
					activa: (f['activa'] as int) == 1,
				),
			)
			.toList();
	}

	/// Lista todos los catalogos de precios.
	Future<List<ListaPrecios>> listarTodasListas() async {
		final filas = await _baseDatos.query(
			'price_lists',
			orderBy: 'nombre ASC',
		);
		return filas
			.map(
				(f) => ListaPrecios(
					id: f['id'] as String,
					nombre: f['nombre'] as String,
					activa: (f['activa'] as int) == 1,
				),
			)
			.toList();
	}

	/// Guarda lista de precios.
	Future<void> guardarLista(ListaPrecios lista) async {
		await _baseDatos.insert(
			'price_lists',
			{
				'id': lista.id,
				'nombre': lista.nombre,
				'activa': lista.activa ? 1 : 0,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Precios de productos en una lista.
	Future<Map<String, double>> listarPreciosDeLista(String listaId) async {
		final filas = await _baseDatos.query(
			'price_list_items',
			where: 'lista_precios_id = ?',
			whereArgs: [listaId],
		);
		return {
			for (final f in filas)
				f['producto_id'] as String: f['precio_unitario'] as double,
		};
	}

	/// Precios del producto en cada lista comercial.
	Future<Map<String, double>> listarPreciosProductoEnListas(String productoId) async {
		final filas = await _baseDatos.query(
			'price_list_items',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
		return {
			for (final f in filas)
				f['lista_precios_id'] as String: (f['precio_unitario'] as num).toDouble(),
		};
	}

	/// Precios especiales del producto por cliente.
	Future<List<PrecioClienteProducto>> listarPreciosProductoPorCliente(
		String productoId,
	) async {
		final filas = await _baseDatos.query(
			'customer_product_prices',
			where: 'producto_id = ?',
			whereArgs: [productoId],
		);
		return filas
			.map(
				(fila) => PrecioClienteProducto(
					clienteId: fila['cliente_id'] as String,
					productoId: productoId,
					precioUnitario: (fila['precio_unitario'] as num).toDouble(),
				),
			)
			.toList();
	}

	/// Elimina lista, sus precios y desvincula clientes asignados.
	Future<void> eliminarLista(String listaId) async {
		await _baseDatos.transaction((tx) async {
			await tx.update(
				'customers',
				{'lista_precios_id': null},
				where: 'lista_precios_id = ?',
				whereArgs: [listaId],
			);
			await tx.delete(
				'price_list_items',
				where: 'lista_precios_id = ?',
				whereArgs: [listaId],
			);
			await tx.delete(
				'price_lists',
				where: 'id = ?',
				whereArgs: [listaId],
			);
		});
	}
}
