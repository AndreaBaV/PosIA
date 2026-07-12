/// Repositorio SQLite de compras a proveedor.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';
import '../utils/transaccion_sqlite.dart';

/// Persiste compras y sus lineas de detalle.
class CompraRepository {
	CompraRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	/// Cuenta compras asociadas a un proveedor.
	Future<int> contarPorProveedor(String proveedorId) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM purchases WHERE proveedor_id = ?',
			[proveedorId],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	Future<void> guardar(Compra compra, {DatabaseExecutor? db}) async {
		await _padresFk.asegurarPadresDeCompra(compra);
		await _padresFk.asegurarCompra(
			compra.id,
			tiendaId: compra.tiendaId,
			proveedorId: compra.proveedorId,
		);
		await ejecutarEscrituraTransaccional(_baseDatos, db, (tx) async {
			await tx.insert(
				'purchases',
				{
					'id': compra.id,
					'tienda_id': compra.tiendaId,
					'proveedor_id': compra.proveedorId,
					'fecha_compra': compra.fechaCompra.toIso8601String(),
					'notas': compra.notas,
					'total': compra.total,
					'creada_en': compra.creadaEn.toIso8601String(),
					'creado_por': compra.creadoPor,
				},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
			await tx.delete(
				'purchase_lines',
				where: 'compra_id = ?',
				whereArgs: [compra.id],
			);
			for (final linea in compra.lineas) {
				await tx.insert('purchase_lines', {
					'compra_id': compra.id,
					'producto_id': linea.productoId,
					'nombre_producto': linea.nombreProducto,
					'cantidad': linea.cantidad,
					'costo_unitario': linea.costoUnitario,
					'subtotal': linea.subtotal,
				});
			}
		});
	}

	Future<List<Compra>> listarPorTienda(String tiendaId, {int limite = 200}) async {
		final filas = await _baseDatos.query(
			'purchases',
			where: 'tienda_id = ?',
			whereArgs: [tiendaId],
			orderBy: 'fecha_compra DESC, creada_en DESC',
			limit: limite,
		);
		final resultado = <Compra>[];
		for (final fila in filas) {
			resultado.add(await _mapear(fila));
		}
		return resultado;
	}

	/// Lista compras recientes de todas las tiendas (para reencolar sync).
	Future<List<Compra>> listarRecientes({int limite = 500}) async {
		final filas = await _baseDatos.query(
			'purchases',
			orderBy: 'fecha_compra DESC, creada_en DESC',
			limit: limite,
		);
		final resultado = <Compra>[];
		for (final fila in filas) {
			resultado.add(await _mapear(fila));
		}
		return resultado;
	}

	Future<Compra?> obtenerPorId(String id) async {
		final filas = await _baseDatos.query(
			'purchases',
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapear(filas.first);
	}

	Future<Compra> _mapear(Map<String, Object?> fila) async {
		final id = fila['id'] as String;
		final lineasFilas = await _baseDatos.query(
			'purchase_lines',
			where: 'compra_id = ?',
			whereArgs: [id],
		);
		return Compra(
			id: id,
			tiendaId: fila['tienda_id'] as String,
			proveedorId: fila['proveedor_id'] as String,
			fechaCompra: DateTime.parse(fila['fecha_compra'] as String),
			notas: fila['notas'] as String? ?? '',
			total: (fila['total'] as num).toDouble(),
			creadaEn: DateTime.parse(fila['creada_en'] as String),
			creadoPor: fila['creado_por'] as String?,
			lineas: lineasFilas
				.map(
					(l) => LineaCompra(
						productoId: l['producto_id'] as String,
						nombreProducto: l['nombre_producto'] as String,
						cantidad: (l['cantidad'] as num).toDouble(),
						costoUnitario: (l['costo_unitario'] as num).toDouble(),
						subtotal: (l['subtotal'] as num).toDouble(),
					),
				)
				.toList(),
		);
	}
}
