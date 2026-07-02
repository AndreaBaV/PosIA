/// Repositorio SQLite de ventas cerradas.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/transaccion_sqlite.dart';

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
	Future<void> guardar(Venta venta, {DatabaseExecutor? db}) async {
		await ejecutarEscrituraTransaccional(_baseDatos, db, (transaccion) async {
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
				'descuento_ticket': venta.descuentoTicket,
				'monto_efectivo': venta.montoEfectivo,
				'monto_tarjeta': venta.montoTarjeta,
				'monto_transferencia': venta.montoTransferencia,
				'credito_dias': venta.creditoDias,
				'credito_vence_en': venta.creditoVenceEn?.toIso8601String(),
				'credito_liquidado': venta.creditoLiquidado ? 1 : 0,
				'credito_liquidado_en': venta.creditoLiquidadoEn?.toIso8601String(),
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
					'descuento_linea': linea.descuentoLinea,
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
		final condiciones = <String>['creada_en >= ?', 'creada_en <= ?'];
		final argumentos = <Object?>[
			filtro.desde.toIso8601String(),
			filtro.hasta.toIso8601String(),
		];
		if (filtro.tiendaId != null) {
			condiciones.add('tienda_id = ?');
			argumentos.add(filtro.tiendaId);
		}
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
	Future<Venta?> obtenerPorId(String ventaId, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		final filas = await exec.query(
			'sales',
			where: 'id = ?',
			whereArgs: [ventaId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearVenta(filas.first, db: exec);
	}

	/// Reemplaza lineas, total y estado de una venta existente.
	Future<void> actualizarVenta(Venta venta, {DatabaseExecutor? db}) async {
		await ejecutarEscrituraTransaccional(_baseDatos, db, (transaccion) async {
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
					'descuento_linea': linea.descuentoLinea,
				});
			}
		});
	}

	/// Resumen de ventas agrupado por producto en periodo.
	///
	/// Agrupa por nombre normalizado para evitar duplicados cuando el mismo
	/// articulo se vendio con distintos IDs (varias tiendas o catalogo recreado).
	Future<List<ResumenProductoVenta>> resumenPorProducto(FiltroVentas filtro) async {
		final ventas = await listarConFiltro(filtro);
		final acumulado = <String, ResumenProductoVenta>{};
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			for (final linea in venta.lineas) {
				final clave = linea.nombreProducto.trim().toLowerCase();
				if (clave.isEmpty) {
					continue;
				}
				final previo = acumulado[clave];
				acumulado[clave] = ResumenProductoVenta(
					productoId: previo?.productoId ?? linea.productoId,
					nombreProducto: previo?.nombreProducto ?? linea.nombreProducto,
					cantidadVendida: (previo?.cantidadVendida ?? 0.0) + linea.cantidad,
					totalVendido: redondearMonto(
						(previo?.totalVendido ?? 0.0) + linea.calcularSubtotal(),
					),
				);
			}
		}
		final lista = acumulado.values.toList()
			..sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
		return lista;
	}

	/// Resumen de ventas agrupado por hora del dia (hora local).
	Future<List<ResumenVentasHora>> resumenPorHora(FiltroVentas filtro) async {
		final ventas = await listarConFiltro(filtro);
		final cantidadPorHora = List<int>.filled(24, 0);
		final totalPorHora = List<double>.filled(24, 0.0);
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			final hora = venta.creadaEn.toLocal().hour;
			cantidadPorHora[hora] = cantidadPorHora[hora] + 1;
			totalPorHora[hora] = redondearMonto(totalPorHora[hora] + venta.total);
		}
		return List.generate(
			24,
			(h) => ResumenVentasHora(
				hora: h,
				cantidadVentas: cantidadPorHora[h],
				totalVendido: totalPorHora[h],
			),
		);
	}

	/// Totales de ventas por metodo de pago en periodo.
	Future<Map<MetodoPago, double>> totalesPorMetodoPago(FiltroVentas filtro) async {
		final ventas = await listarConFiltro(filtro);
		final acumulado = <MetodoPago, double>{};
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			acumulado[venta.metodoPago] =
				redondearMonto((acumulado[venta.metodoPago] ?? 0.0) + venta.total);
		}
		return acumulado;
	}

	/// Actualiza estado de una venta.
	Future<void> actualizarEstado(
		String ventaId,
		EstadoVenta estado, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		await exec.update(
			'sales',
			{'estado': estado.name},
			where: 'id = ?',
			whereArgs: [ventaId],
		);
	}

	/// Cuenta ventas asociadas a un cliente.
	Future<int> contarPorCliente(String clienteId) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM sales WHERE cliente_id = ?',
			[clienteId],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	/// Lista ventas a credito pendientes de liquidar.
	Future<List<Venta>> listarCreditosPendientes(String tiendaId) async {
		final filas = await _baseDatos.query(
			'sales',
			where:
				"tienda_id = ? AND metodo_pago = 'credito' "
				'AND credito_liquidado = 0 AND estado = ?',
			whereArgs: [tiendaId, EstadoVenta.completada.name],
			orderBy: 'creada_en DESC',
		);
		final ventas = <Venta>[];
		for (final fila in filas) {
			ventas.add(await _mapearVenta(fila));
		}
		return ventas;
	}

	/// Marca credito como liquidado.
	Future<void> actualizarCreditoLiquidado(Venta venta, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		await exec.update(
			'sales',
			{
				'credito_liquidado': venta.creditoLiquidado ? 1 : 0,
				'credito_liquidado_en': venta.creditoLiquidadoEn?.toIso8601String(),
			},
			where: 'id = ?',
			whereArgs: [venta.id],
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
	Future<Venta> _mapearVenta(
		Map<String, Object?> filaVenta, {
		DatabaseExecutor? db,
	}) async {
		final exec = db ?? _baseDatos;
		final ventaId = filaVenta['id'] as String;
		final filasLineas = await exec.query(
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
					descuentoLinea: (fila['descuento_linea'] as num?)?.toDouble() ?? 0.0,
				),
			)
			.toList();
		final estadoNombre = filaVenta['estado'] as String? ?? EstadoVenta.completada.name;
		final venceRaw = filaVenta['credito_vence_en'] as String?;
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
			descuentoTicket: (filaVenta['descuento_ticket'] as num?)?.toDouble() ?? 0.0,
			montoEfectivo: (filaVenta['monto_efectivo'] as num?)?.toDouble(),
			montoTarjeta: (filaVenta['monto_tarjeta'] as num?)?.toDouble(),
			montoTransferencia: (filaVenta['monto_transferencia'] as num?)?.toDouble(),
			creditoDias: filaVenta['credito_dias'] as int?,
			creditoVenceEn: venceRaw == null ? null : DateTime.parse(venceRaw),
			creditoLiquidado: (filaVenta['credito_liquidado'] as int? ?? 0) == 1,
			creditoLiquidadoEn: filaVenta['credito_liquidado_en'] == null
				? null
				: DateTime.parse(filaVenta['credito_liquidado_en'] as String),
		);
	}

	/// Elimina venta y sus lineas de detalle.
	Future<void> eliminar(String ventaId, {DatabaseExecutor? db}) async {
		await ejecutarEscrituraTransaccional(_baseDatos, db, (transaccion) async {
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
