/// Proyecta eventos del hub a tablas espejo del POS en PostgreSQL.
library;

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

import 'evento_hub.dart';

/// Aplica eventos de dominio sobre el esquema operativo Postgres.
class ProyectorEventosPostgres {
	ProyectorEventosPostgres(this._sesion);

	final Session _sesion;

	/// Proyecta un evento recien persistido en sync_events.
	Future<void> aplicar(EventoHub evento) async {
		switch (evento.tipo) {
			case 'productUpserted':
				await _producto(evento);
			case 'customerUpserted':
				await _cliente(evento);
			case 'categoryUpserted':
				await _categoria(evento);
			case 'variantUpserted':
				await _variante(evento);
			case 'saleCompleted':
				await _ventaCompletada(evento);
			case 'stockAdjusted':
				await _ajusteStock(evento);
			case 'saleVoided':
				await _ventaAnulada(evento);
			case 'transferRequested':
				await _traspaso(evento, completado: false);
			case 'transferCompleted':
				await _traspaso(evento, completado: true);
			case 'salePartialReturn':
				await _devolucionParcial(evento);
			case 'storeUpserted':
				await _tienda(evento);
			case 'warehouseUpserted':
				await _almacen(evento);
			case 'userUpserted':
				await _usuario(evento);
			default:
				break;
		}
	}

	Future<void> _producto(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
		await _asegurarTienda(tiendaId);
		await _sesion.execute(
			Sql.named('''
				INSERT INTO products (
					id, nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
					activo, tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
					proveedor_id, unidades_por_bulto, notas
				) VALUES (
					@id, @nombre, @codigo, @precio, @unidad, @ruta, @activo, @tienda,
					@vertical, @categoria, @piezas, @proveedor, @bulto, @notas
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					codigo_barras = EXCLUDED.codigo_barras,
					precio_base = EXCLUDED.precio_base,
					unidad_medida = EXCLUDED.unidad_medida,
					ruta_imagen = EXCLUDED.ruta_imagen,
					activo = EXCLUDED.activo,
					tienda_id = EXCLUDED.tienda_id,
					modulo_vertical = EXCLUDED.modulo_vertical,
					categoria_id = EXCLUDED.categoria_id,
					piezas_por_caja = EXCLUDED.piezas_por_caja,
					proveedor_id = EXCLUDED.proveedor_id,
					unidades_por_bulto = EXCLUDED.unidades_por_bulto,
					notas = EXCLUDED.notas
			'''),
			parameters: {
				'id': id,
				'nombre': p['nombre'] ?? '',
				'codigo': p['codigoBarras'] ?? '',
				'precio': _dbl(p['precioBase']),
				'unidad': p['unidadMedida'] ?? 'pieza',
				'ruta': p['rutaImagen'] ?? '',
				'activo': _boolInt(p['activo'], defaultValue: true),
				'tienda': p['tiendaId'] ?? evento.tiendaId,
				'vertical': p['moduloVertical'] ?? 'general',
				'categoria': p['categoriaId'],
				'piezas': _intNullable(p['piezasPorCaja']),
				'proveedor': p['proveedorId'],
				'bulto': _intNullable(p['unidadesPorBulto']),
				'notas': p['notas'] ?? '',
			},
		);
	}

	Future<void> _cliente(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO customers (
					id, nombre, lista_precios_id, credito_habilitado, activo,
					telefono, email, rfc, direccion, notas
				) VALUES (
					@id, @nombre, @lista, @credito, @activo,
					@telefono, @email, @rfc, @direccion, @notas
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					lista_precios_id = EXCLUDED.lista_precios_id,
					credito_habilitado = EXCLUDED.credito_habilitado,
					activo = EXCLUDED.activo,
					telefono = EXCLUDED.telefono,
					email = EXCLUDED.email,
					rfc = EXCLUDED.rfc,
					direccion = EXCLUDED.direccion,
					notas = EXCLUDED.notas
			'''),
			parameters: {
				'id': id,
				'nombre': p['nombre'] ?? '',
				'lista': p['listaPreciosId'],
				'credito': _boolInt(p['creditoHabilitado']),
				'activo': _boolInt(p['activo'], defaultValue: true),
				'telefono': p['telefono'] ?? '',
				'email': p['email'] ?? '',
				'rfc': p['rfc'] ?? '',
				'direccion': p['direccion'] ?? '',
				'notas': p['notas'] ?? '',
			},
		);
	}

	Future<void> _categoria(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO categories (id, nombre, icono, color_hex, orden, activa)
				VALUES (@id, @nombre, @icono, @color, @orden, @activa)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					icono = EXCLUDED.icono,
					color_hex = EXCLUDED.color_hex,
					orden = EXCLUDED.orden,
					activa = EXCLUDED.activa
			'''),
			parameters: {
				'id': id,
				'nombre': p['nombre'] ?? '',
				'icono': p['icono'] ?? 'shopping_basket',
				'color': p['colorHex'] ?? '#4CAF50',
				'orden': _int(p['orden']),
				'activa': _boolInt(p['activa'], defaultValue: true),
			},
		);
	}

	Future<void> _variante(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO product_variants (
					id, producto_padre_id, nombre, sku, codigo_barras, precio_base, activo
				) VALUES (
					@id, @padre, @nombre, @sku, @codigo, @precio, @activo
				)
				ON CONFLICT (id) DO UPDATE SET
					producto_padre_id = EXCLUDED.producto_padre_id,
					nombre = EXCLUDED.nombre,
					sku = EXCLUDED.sku,
					codigo_barras = EXCLUDED.codigo_barras,
					precio_base = EXCLUDED.precio_base,
					activo = EXCLUDED.activo
			'''),
			parameters: {
				'id': id,
				'padre': p['productoPadreId'] ?? '',
				'nombre': p['nombre'] ?? '',
				'sku': p['sku'] ?? '',
				'codigo': p['codigoBarras'] ?? '',
				'precio': _dbl(p['precioBase']),
				'activo': _boolInt(p['activo'], defaultValue: true),
			},
		);
	}

	Future<void> _ventaCompletada(EventoHub evento) async {
		final p = evento.payload;
		final ventaId = p['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final existente = await _sesion.execute(
			Sql.named('SELECT 1 FROM sales WHERE id = @id LIMIT 1'),
			parameters: {'id': ventaId},
		);
		if (existente.isNotEmpty) {
			return;
		}
		await _asegurarTienda(evento.tiendaId);
		final creadaEn = evento.creadoEn.toUtc().toIso8601String();
		await _sesion.execute(
			Sql.named('''
				INSERT INTO sales (
					id, tienda_id, caja_id, cliente_id, metodo_pago, total,
					creada_en, vendedor_id, estado, turno_caja_id
				) VALUES (
					@id, @tienda, @caja, @cliente, @metodo, @total,
					@creada, @vendedor, 'completada', @turno
				)
			'''),
			parameters: {
				'id': ventaId,
				'tienda': evento.tiendaId,
				'caja': evento.dispositivoId,
				'cliente': p['clienteId'],
				'metodo': p['metodoPago'] ?? 'efectivo',
				'total': _dbl(p['total']),
				'creada': creadaEn,
				'vendedor': p['vendedorId'],
				'turno': p['turnoCajaId'],
			},
		);
		final lineas = _listaMapas(p['lineas']);
		for (final linea in lineas) {
			await _sesion.execute(
				Sql.named('''
					INSERT INTO sale_lines (
						venta_id, producto_id, nombre_producto, cantidad,
						precio_unitario, regla_precio, lote_id, etiqueta_lote
					) VALUES (
						@venta, @producto, @nombre, @cantidad,
						@precio, @regla, @lote, @etiqueta
					)
				'''),
				parameters: {
					'venta': ventaId,
					'producto': linea['productoId'] ?? '',
					'nombre': linea['nombreProducto'] ?? '',
					'cantidad': _dbl(linea['cantidad']),
					'precio': _dbl(linea['precioUnitario']),
					'regla': linea['reglaPrecio'] ?? 'precioBase',
					'lote': linea['loteId'],
					'etiqueta': linea['etiquetaLote'],
				},
			);
			await _deltaStock(
				linea['productoId'] as String? ?? '',
				evento.tiendaId,
				-_dbl(linea['cantidad']),
				creadaEn,
			);
		}
	}

	Future<void> _ajusteStock(EventoHub evento) async {
		final p = evento.payload;
		final productoId = p['productoId'] as String? ?? '';
		final delta = _dbl(p['delta']);
		if (productoId.isEmpty || delta == 0.0) {
			return;
		}
		final almacenId = p['almacenId'] as String? ?? '';
		final actualizado = evento.creadoEn.toUtc().toIso8601String();
		if (almacenId.isNotEmpty) {
			await _deltaStockAlmacen(productoId, almacenId, delta, actualizado);
			return;
		}
		await _deltaStock(
			productoId,
			evento.tiendaId,
			delta,
			actualizado,
		);
	}

	Future<void> _ventaAnulada(EventoHub evento) async {
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final venta = await _sesion.execute(
			Sql.named('SELECT tienda_id, estado FROM sales WHERE id = @id'),
			parameters: {'id': ventaId},
		);
		if (venta.isEmpty) {
			return;
		}
		final fila = venta.first.toColumnMap();
		if (fila['estado'] == 'cancelada') {
			return;
		}
		final tiendaId = fila['tienda_id'] as String;
		final lineas = await _sesion.execute(
			Sql.named(
				'SELECT producto_id, cantidad FROM sale_lines WHERE venta_id = @id',
			),
			parameters: {'id': ventaId},
		);
		final ahora = evento.creadoEn.toUtc().toIso8601String();
		for (final linea in lineas) {
			final cols = linea.toColumnMap();
			await _deltaStock(
				cols['producto_id'] as String,
				tiendaId,
				_dbl(cols['cantidad']),
				ahora,
			);
		}
		await _sesion.execute(
			Sql.named("UPDATE sales SET estado = 'cancelada' WHERE id = @id"),
			parameters: {'id': ventaId},
		);
	}

	Future<void> _traspaso(EventoHub evento, {required bool completado}) async {
		final p = evento.payload;
		final id = p['traspasoId'] as String? ?? evento.id;
		final estado = completado ? 'completado' : 'enTransito';
		final solicitado = evento.creadoEn.toUtc().toIso8601String();
		final completadoEn = completado ? solicitado : null;
		await _sesion.execute(
			Sql.named('''
				INSERT INTO transfers (
					id, tienda_origen_id, tienda_destino_id, estado,
					solicitado_en, completado_en, notas
				) VALUES (
					@id, @origen, @destino, @estado, @solicitado, @completado, ''
				)
				ON CONFLICT (id) DO UPDATE SET
					estado = EXCLUDED.estado,
					completado_en = EXCLUDED.completado_en
			'''),
			parameters: {
				'id': id,
				'origen': p['tiendaOrigenId'] ?? '',
				'destino': p['tiendaDestinoId'] ?? '',
				'estado': estado,
				'solicitado': solicitado,
				'completado': completadoEn,
			},
		);
		await _sesion.execute(
			Sql.named('DELETE FROM transfer_lines WHERE transfer_id = @id'),
			parameters: {'id': id},
		);
		final lineas = _listaMapas(p['lineas']);
		for (final linea in lineas) {
			await _sesion.execute(
				Sql.named('''
					INSERT INTO transfer_lines (
						transfer_id, producto_id, cantidad_solicitada, cantidad_recibida
					) VALUES (@transfer, @producto, @solicitada, @recibida)
				'''),
				parameters: {
					'transfer': id,
					'producto': linea['productoId'] ?? '',
					'solicitada': _dbl(linea['cantidadSolicitada']),
					'recibida': linea['cantidadRecibida'] != null
						? _dbl(linea['cantidadRecibida'])
						: null,
				},
			);
			if (!completado) {
				continue;
			}
			final cantidad = linea['cantidadRecibida'] != null
				? _dbl(linea['cantidadRecibida'])
				: _dbl(linea['cantidadSolicitada']);
			final productoId = linea['productoId'] as String? ?? '';
			final almacenOrigen = p['almacenOrigenId'] as String? ?? '';
			final almacenDestino = p['almacenDestinoId'] as String? ?? '';
			final tiendaOrigen = p['tiendaOrigenId'] as String? ?? '';
			final tiendaDestino = p['tiendaDestinoId'] as String? ?? '';
			if (productoId.isEmpty || cantidad <= 0) {
				continue;
			}
			if (almacenOrigen.isNotEmpty) {
				await _deltaStockAlmacen(
					productoId,
					almacenOrigen,
					-cantidad,
					solicitado,
				);
			} else if (tiendaOrigen.isNotEmpty) {
				await _deltaStock(productoId, tiendaOrigen, -cantidad, solicitado);
			}
			if (almacenDestino.isNotEmpty) {
				await _deltaStockAlmacen(
					productoId,
					almacenDestino,
					cantidad,
					solicitado,
				);
			} else if (tiendaDestino.isNotEmpty) {
				await _deltaStock(productoId, tiendaDestino, cantidad, solicitado);
			}
		}
	}

	Future<void> _devolucionParcial(EventoHub evento) async {
		final p = evento.payload;
		final ventaId = p['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final ventaRows = await _sesion.execute(
			Sql.named('SELECT tienda_id, estado FROM sales WHERE id = @id'),
			parameters: {'id': ventaId},
		);
		if (ventaRows.isEmpty) {
			return;
		}
		final venta = ventaRows.first.toColumnMap();
		if (venta['estado'] == 'cancelada') {
			return;
		}
		final tiendaId = venta['tienda_id'] as String;
		final lineasActuales = await _sesion.execute(
			Sql.named('SELECT * FROM sale_lines WHERE venta_id = @id'),
			parameters: {'id': ventaId},
		);
		final devoluciones = _listaMapas(p['lineas']);
		final ahora = evento.creadoEn.toUtc().toIso8601String();
		final lineasRestantes = <Map<String, Object?>>[];
		for (final fila in lineasActuales) {
			final cols = fila.toColumnMap();
			var cantidad = _dbl(cols['cantidad']);
			final productoId = cols['producto_id'] as String;
			for (final dev in devoluciones) {
				if (dev['productoId'] == productoId) {
					final devuelta = _dbl(dev['cantidadDevuelta']);
					cantidad = cantidad - devuelta;
					await _deltaStock(productoId, tiendaId, devuelta, ahora);
				}
			}
			if (cantidad > 0.0) {
				lineasRestantes.add({...cols, 'cantidad': cantidad});
			}
		}
		await _sesion.execute(
			Sql.named('DELETE FROM sale_lines WHERE venta_id = @id'),
			parameters: {'id': ventaId},
		);
		var total = 0.0;
		for (final linea in lineasRestantes) {
			final sub = _dbl(linea['cantidad']) * _dbl(linea['precio_unitario']);
			total = total + sub;
			await _sesion.execute(
				Sql.named('''
					INSERT INTO sale_lines (
						venta_id, producto_id, nombre_producto, cantidad,
						precio_unitario, regla_precio, lote_id, etiqueta_lote
					) VALUES (
						@venta, @producto, @nombre, @cantidad,
						@precio, @regla, @lote, @etiqueta
					)
				'''),
				parameters: {
					'venta': ventaId,
					'producto': linea['producto_id'],
					'nombre': linea['nombre_producto'],
					'cantidad': linea['cantidad'],
					'precio': linea['precio_unitario'],
					'regla': linea['regla_precio'],
					'lote': linea['lote_id'],
					'etiqueta': linea['etiqueta_lote'],
				},
			);
		}
		final nuevoEstado = lineasRestantes.isEmpty ? 'devuelta' : 'completada';
		await _sesion.execute(
			Sql.named('UPDATE sales SET total = @total, estado = @estado WHERE id = @id'),
			parameters: {'total': total, 'estado': nuevoEstado, 'id': ventaId},
		);
	}

	Future<void> _asegurarTienda(String tiendaId) async {
		if (tiendaId.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO stores (id, nombre, direccion, activa)
				VALUES (@id, @nombre, '', 1)
				ON CONFLICT (id) DO NOTHING
			'''),
			parameters: {
				'id': tiendaId,
				'nombre': tiendaId,
			},
		);
	}

	Future<void> _tienda(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO stores (id, nombre, direccion, activa)
				VALUES (@id, @nombre, @direccion, @activa)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					direccion = EXCLUDED.direccion,
					activa = EXCLUDED.activa
			'''),
			parameters: {
				'id': id,
				'nombre': p['nombre'] ?? '',
				'direccion': p['direccion'] ?? '',
				'activa': (p['activa'] as bool? ?? true) ? 1 : 0,
			},
		);
	}

	Future<void> _almacen(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO almacenes (id, nombre, tienda_id, activo)
				VALUES (@id, @nombre, @tienda, @activo)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					tienda_id = EXCLUDED.tienda_id,
					activo = EXCLUDED.activo
			'''),
			parameters: {
				'id': id,
				'nombre': p['nombre'] ?? '',
				'tienda': p['tiendaId'],
				'activo': _boolInt(p['activo'], defaultValue: true),
			},
		);
	}

	Future<void> _usuario(EventoHub evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		final pinCredencial = _extraerPinCredencial(p);
		if (id.isEmpty || pinCredencial == null) {
			return;
		}
		final actualizadoEn = p['actualizadoEn'] as String? ?? evento.creadoEn.toUtc().toIso8601String();
		final codigo = ValidadorCodigoUsuario.normalizar(p['codigo'] as String? ?? '');
		if (codigo.isEmpty) {
			return;
		}
		final existente = await _sesion.execute(
			Sql.named('SELECT actualizado_en FROM users WHERE id = @id'),
			parameters: {'id': id},
		);
		if (existente.isNotEmpty) {
			final local = existente.first.toColumnMap()['actualizado_en'] as String? ?? '';
			if (local.compareTo(actualizadoEn) > 0) {
				return;
			}
		}
		await _liberarCodigoEnConflicto(
			codigo: codigo,
			usuarioId: id,
			actualizadoEn: actualizadoEn,
		);
		await _sesion.execute(
			Sql.named('''
				INSERT INTO users (
					id, nombre, codigo, rol, tienda_id, activo,
					pin_credencial, creado_en, actualizado_en
				) VALUES (
					@id, @nombre, @codigo, @rol, @tienda, @activo,
					@credencial, @creado, @actualizado
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					codigo = EXCLUDED.codigo,
					rol = EXCLUDED.rol,
					tienda_id = EXCLUDED.tienda_id,
					activo = EXCLUDED.activo,
					pin_credencial = EXCLUDED.pin_credencial,
					creado_en = EXCLUDED.creado_en,
					actualizado_en = EXCLUDED.actualizado_en
			'''),
			parameters: {
				'id': id,
				'nombre': p['nombre'] ?? '',
				'codigo': codigo,
				'rol': p['rol'] ?? 'empleado',
				'tienda': p['tiendaId'],
				'activo': (p['activo'] as bool? ?? true) ? 1 : 0,
				'credencial': pinCredencial,
				'creado': p['creadoEn'] as String? ?? evento.creadoEn.toUtc().toIso8601String(),
				'actualizado': actualizadoEn,
			},
		);
	}

	Future<void> _liberarCodigoEnConflicto({
		required String codigo,
		required String usuarioId,
		required String actualizadoEn,
	}) async {
		final conflicto = await _sesion.execute(
			Sql.named('''
				SELECT id, actualizado_en
				FROM users
				WHERE codigo = @codigo AND id <> @id
				LIMIT 1
			'''),
			parameters: {
				'codigo': codigo,
				'id': usuarioId,
			},
		);
		if (conflicto.isEmpty) {
			return;
		}
		final cols = conflicto.first.toColumnMap();
		final otroId = cols['id'] as String? ?? '';
		final otroActualizado = cols['actualizado_en'] as String? ?? '';
		if (otroId.isEmpty || otroActualizado.compareTo(actualizadoEn) >= 0) {
			return;
		}
		final sufijo = otroId.length > 8 ? otroId.substring(0, 8) : otroId;
		await _sesion.execute(
			Sql.named('''
				UPDATE users
				SET codigo = @nuevo, actualizado_en = @actualizado
				WHERE id = @id
			'''),
			parameters: {
				'id': otroId,
				'nuevo': '${codigo}_LEGACY_$sufijo',
				'actualizado': actualizadoEn,
			},
		);
	}

	Future<void> _deltaStock(
		String productoId,
		String tiendaId,
		double delta,
		String actualizadoEn,
	) async {
		if (productoId.isEmpty || tiendaId.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO stock_levels (producto_id, tienda_id, cantidad, actualizado_en, stock_minimo)
				VALUES (@producto, @tienda, @delta, @actualizado, 0)
				ON CONFLICT (producto_id, tienda_id) DO UPDATE SET
					cantidad = stock_levels.cantidad + @delta,
					actualizado_en = @actualizado
			'''),
			parameters: {
				'producto': productoId,
				'tienda': tiendaId,
				'delta': delta,
				'actualizado': actualizadoEn,
			},
		);
	}

	Future<void> _deltaStockAlmacen(
		String productoId,
		String almacenId,
		double delta,
		String actualizadoEn,
	) async {
		if (productoId.isEmpty || almacenId.isEmpty) {
			return;
		}
		await _sesion.execute(
			Sql.named('''
				INSERT INTO warehouse_stock (producto_id, almacen_id, cantidad, actualizado_en, stock_minimo)
				VALUES (@producto, @almacen, @delta, @actualizado, 0)
				ON CONFLICT (producto_id, almacen_id) DO UPDATE SET
					cantidad = warehouse_stock.cantidad + @delta,
					actualizado_en = @actualizado
			'''),
			parameters: {
				'producto': productoId,
				'almacen': almacenId,
				'delta': delta,
				'actualizado': actualizadoEn,
			},
		);
	}

	List<Map<String, Object?>> _listaMapas(Object? crudo) {
		if (crudo is! List<Object?>) {
			return [];
		}
		return crudo
			.whereType<Map<Object?, Object?>>()
			.map((m) => Map<String, Object?>.from(m))
			.toList();
	}

	double _dbl(Object? valor) => (valor as num?)?.toDouble() ?? 0.0;

	int _int(Object? valor) => (valor as num?)?.toInt() ?? 0;

	int? _intNullable(Object? valor) {
		if (valor == null) {
			return null;
		}
		return (valor as num).toInt();
	}

	int _boolInt(Object? valor, {bool defaultValue = false}) {
		if (valor is bool) {
			return valor ? 1 : 0;
		}
		return defaultValue ? 1 : 0;
	}

	String? _extraerPinCredencial(Map<String, Object?> payload) {
		final credencial = payload['pinCredencial'] as String?;
		if (credencial == null || credencial.isEmpty) {
			return null;
		}
		return credencial;
	}
}
