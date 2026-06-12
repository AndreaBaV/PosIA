/// Repositorio SQLite de ventas cerradas.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste ventas y lineas de detalle en SQLite.
class VentaRepository {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	VentaRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Guarda venta completa con lineas en transaccion.
	///
	/// [venta] Venta cerrada a persistir.
	Future<void> guardar(Venta venta) async {
		await _baseDatos.transaction((transaccion) async {
			await transaccion.insert('sales', {
				'id': venta.id,
				'tienda_id': venta.tiendaId,
				'caja_id': venta.cajaId,
				'cliente_id': venta.clienteId,
				'metodo_pago': venta.metodoPago.name,
				'total': venta.total,
				'creada_en': venta.creadaEn.toIso8601String(),
				'vendedor_id': venta.vendedorId,
				'estado': venta.estado.name,
				'turno_caja_id': venta.turnoCajaId,
			});
			for (final linea in venta.lineas) {
				await transaccion.insert('sale_lines', {
					'venta_id': venta.id,
					'producto_id': linea.productoId,
					'nombre_producto': linea.nombreProducto,
					'cantidad': linea.cantidad,
					'precio_unitario': linea.precioUnitario,
					'regla_precio': linea.reglaPrecio.name,
					'lote_id': linea.loteId,
					'etiqueta_lote': linea.etiquetaLote,
				});
			}
		});
	}

	/// Obtiene ventas del dia actual en tienda (frontera en hora local).
	///
	/// [tiendaId] Tienda consultada.
	/// Retorna ventas ordenadas por fecha descendente.
	Future<List<Venta>> listarVentasDelDia(String tiendaId) async {
		final ahoraLocal = DateTime.now();
		final inicioLocal = DateTime(ahoraLocal.year, ahoraLocal.month, ahoraLocal.day);
		final inicioUtc = inicioLocal.toUtc();
		final filas = await _baseDatos.query(
			'sales',
			where: 'tienda_id = ? AND creada_en >= ?',
			whereArgs: [tiendaId, inicioUtc.toIso8601String()],
			orderBy: 'creada_en DESC',
		);
		final ventas = <Venta>[];
		for (final fila in filas) {
			final venta = await _mapearVenta(fila);
			ventas.add(venta);
		}
		return ventas;
	}

	/// Lista ventas con filtros de historial.
	Future<List<Venta>> listarConFiltro(FiltroVentas filtro) async {
		final condiciones = <String>['tienda_id = ?', 'creada_en >= ?', 'creada_en <= ?'];
		final argumentos = <Object?>[
			filtro.tiendaId,
			filtro.desde.toIso8601String(),
			filtro.hasta.toIso8601String(),
		];
		if (filtro.vendedorId != null) {
			condiciones.add('vendedor_id = ?');
			argumentos.add(filtro.vendedorId);
		}
		if (filtro.clienteId != null) {
			condiciones.add('cliente_id = ?');
			argumentos.add(filtro.clienteId);
		}
		if (filtro.estado != null) {
			condiciones.add('estado = ?');
			argumentos.add(filtro.estado!.name);
		}
		final filas = await _baseDatos.query(
			'sales',
			where: condiciones.join(' AND '),
			whereArgs: argumentos,
			orderBy: 'creada_en DESC',
		);
		final ventas = <Venta>[];
		for (final fila in filas) {
			ventas.add(await _mapearVenta(fila));
		}
		return ventas;
	}

	/// Obtiene venta por identificador.
	Future<Venta?> obtenerPorId(String ventaId) async {
		final filas = await _baseDatos.query(
			'sales',
			where: 'id = ?',
			whereArgs: [ventaId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearVenta(filas.first);
	}

	/// Reemplaza lineas, total y estado de una venta existente.
	Future<void> actualizarVenta(Venta venta) async {
		await _baseDatos.transaction((transaccion) async {
			await transaccion.update(
				'sales',
				{
					'total': venta.total,
					'estado': venta.estado.name,
				},
				where: 'id = ?',
				whereArgs: [venta.id],
			);
			await transaccion.delete(
				'sale_lines',
				where: 'venta_id = ?',
				whereArgs: [venta.id],
			);
			for (final linea in venta.lineas) {
				await transaccion.insert('sale_lines', {
					'venta_id': venta.id,
					'producto_id': linea.productoId,
					'nombre_producto': linea.nombreProducto,
					'cantidad': linea.cantidad,
					'precio_unitario': linea.precioUnitario,
					'regla_precio': linea.reglaPrecio.name,
					'lote_id': linea.loteId,
					'etiqueta_lote': linea.etiquetaLote,
				});
			}
		});
	}

	/// Actualiza estado de una venta.
	Future<void> actualizarEstado(String ventaId, EstadoVenta estado) async {
		await _baseDatos.update(
			'sales',
			{'estado': estado.name},
			where: 'id = ?',
			whereArgs: [ventaId],
		);
	}

	/// Calcula total vendido en el dia para tienda.
	///
	/// [tiendaId] Tienda consultada.
	/// Retorna suma de totales del dia.
	Future<double> calcularTotalDelDia(String tiendaId) async {
		final ventas = await listarVentasDelDia(tiendaId);
		var acumulado = 0.0;
		for (final venta in ventas) {
			acumulado = acumulado + venta.total;
		}
		return redondearMonto(acumulado);
	}

	/// Reconstruye venta con lineas desde fila principal.
	///
	/// [filaVenta] Registro de tabla sales.
	/// Retorna entidad [Venta] completa.
	Future<Venta> _mapearVenta(Map<String, Object?> filaVenta) async {
		final ventaId = filaVenta['id'] as String;
		final filasLineas = await _baseDatos.query(
			'sale_lines',
			where: 'venta_id = ?',
			whereArgs: [ventaId],
		);
		final lineas = filasLineas
			.map(
				(fila) => LineaVenta(
					productoId: fila['producto_id'] as String,
					nombreProducto: fila['nombre_producto'] as String,
					cantidad: fila['cantidad'] as double,
					precioUnitario: fila['precio_unitario'] as double,
					reglaPrecio: ReglaPrecio.values.byName(fila['regla_precio'] as String),
					loteId: fila['lote_id'] as String?,
					etiquetaLote: fila['etiqueta_lote'] as String?,
				),
			)
			.toList();
		final estadoNombre = filaVenta['estado'] as String? ?? EstadoVenta.completada.name;
		return Venta(
			id: ventaId,
			tiendaId: filaVenta['tienda_id'] as String,
			cajaId: filaVenta['caja_id'] as String,
			clienteId: filaVenta['cliente_id'] as String?,
			lineas: lineas,
			metodoPago: MetodoPago.values.byName(filaVenta['metodo_pago'] as String),
			total: filaVenta['total'] as double,
			creadaEn: DateTime.parse(filaVenta['creada_en'] as String),
			vendedorId: filaVenta['vendedor_id'] as String?,
			estado: EstadoVenta.values.byName(estadoNombre),
			turnoCajaId: filaVenta['turno_caja_id'] as String?,
		);
	}

	/// Elimina venta y sus lineas de detalle.
	Future<void> eliminar(String ventaId) async {
		await _baseDatos.transaction((transaccion) async {
			await transaccion.delete(
				'sale_lines',
				where: 'venta_id = ?',
				whereArgs: [ventaId],
			);
			await transaccion.delete(
				'sales',
				where: 'id = ?',
				whereArgs: [ventaId],
			);
		});
	}
}
