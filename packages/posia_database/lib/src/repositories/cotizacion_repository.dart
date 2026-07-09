/// Repositorio SQLite de cotizaciones.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste cotizaciones y lineas de detalle.
class CotizacionRepository {
	CotizacionRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Cuenta cotizaciones asociadas a un cliente.
	Future<int> contarPorCliente(String clienteId) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM quotes WHERE cliente_id = ?',
			[clienteId],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	Future<void> guardar(Cotizacion cotizacion) async {
		await _baseDatos.transaction((transaccion) async {
			await transaccion.insert(
				'quotes',
				_mapearMapa(cotizacion),
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
			await transaccion.delete(
				'quote_lines',
				where: 'cotizacion_id = ?',
				whereArgs: [cotizacion.id],
			);
			for (final linea in cotizacion.lineas) {
				await transaccion.insert('quote_lines', {
					'cotizacion_id': cotizacion.id,
					'producto_id': linea.productoId,
					'nombre_producto': linea.nombreProducto,
					'cantidad': linea.cantidad,
					'precio_unitario': linea.precioUnitario,
					'regla_precio': linea.reglaPrecio.name,
					'subtotal': linea.subtotal,
				});
			}
		});
	}

	Future<void> eliminar(String cotizacionId) async {
		await _baseDatos.transaction((transaccion) async {
			await transaccion.delete(
				'quote_lines',
				where: 'cotizacion_id = ?',
				whereArgs: [cotizacionId],
			);
			await transaccion.delete(
				'quotes',
				where: 'id = ?',
				whereArgs: [cotizacionId],
			);
		});
	}

	Future<Cotizacion?> obtenerPorId(String cotizacionId) async {
		final filas = await _baseDatos.query(
			'quotes',
			where: 'id = ?',
			whereArgs: [cotizacionId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearCotizacion(filas.first);
	}

	Future<List<Cotizacion>> listarPorTienda(
		String tiendaId, {
		DateTime? desde,
		DateTime? hasta,
	}) async {
		final condiciones = <String>['tienda_id = ?'];
		final args = <Object?>[tiendaId];
		if (desde != null) {
			condiciones.add('creada_en >= ?');
			args.add(desde.toUtc().toIso8601String());
		}
		if (hasta != null) {
			condiciones.add('creada_en <= ?');
			args.add(hasta.toUtc().toIso8601String());
		}
		final filas = await _baseDatos.query(
			'quotes',
			where: condiciones.join(' AND '),
			whereArgs: args,
			orderBy: 'creada_en DESC',
		);
		final cotizaciones = <Cotizacion>[];
		for (final fila in filas) {
			cotizaciones.add(await _mapearCotizacion(fila));
		}
		return cotizaciones;
	}

	Future<Cotizacion> _mapearCotizacion(Map<String, Object?> fila) async {
		final cotizacionId = fila['id'] as String;
		final filasLineas = await _baseDatos.query(
			'quote_lines',
			where: 'cotizacion_id = ?',
			whereArgs: [cotizacionId],
		);
		final lineas = filasLineas
			.map(
				(l) => LineaCotizacion(
					productoId: l['producto_id'] as String,
					nombreProducto: l['nombre_producto'] as String,
					cantidad: (l['cantidad'] as num).toDouble(),
					precioUnitario: (l['precio_unitario'] as num).toDouble(),
					reglaPrecio: ReglaPrecio.values.byName(l['regla_precio'] as String),
				),
			)
			.toList();
		return Cotizacion(
			id: cotizacionId,
			tiendaId: fila['tienda_id'] as String,
			clienteId: fila['cliente_id'] as String?,
			nombreCliente: fila['nombre_cliente'] as String?,
			total: (fila['total'] as num).toDouble(),
			notas: fila['notas'] as String? ?? '',
			vigenciaDias: fila['vigencia_dias'] as int? ?? VIGENCIA_COTIZACION_DIAS,
			creadaEn: DateTime.parse(fila['creada_en'] as String),
			cajaId: fila['caja_id'] as String?,
			vendedorId: fila['vendedor_id'] as String?,
			lineas: lineas,
		);
	}

	Map<String, Object?> _mapearMapa(Cotizacion cotizacion) {
		return {
			'id': cotizacion.id,
			'tienda_id': cotizacion.tiendaId,
			'cliente_id': cotizacion.clienteId,
			'nombre_cliente': cotizacion.nombreCliente,
			'total': cotizacion.total,
			'notas': cotizacion.notas,
			'vigencia_dias': cotizacion.vigenciaDias,
			'creada_en': cotizacion.creadaEn.toIso8601String(),
			'caja_id': cotizacion.cajaId,
			'vendedor_id': cotizacion.vendedorId,
		};
	}
}
