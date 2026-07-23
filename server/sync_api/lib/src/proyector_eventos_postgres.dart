/// Proyecta eventos del hub a tablas espejo del POS en PostgreSQL.
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

import 'evento_hub.dart';

/// Aplica eventos de dominio sobre el esquema operativo Postgres.
class ProyectorEventosPostgres {
  /// [cacheTiendas] Ids de tienda ya asegurados en esta transaccion. Compartirlo
  /// entre los eventos de un mismo lote evita repetir el upsert de `stores` una
  /// vez por evento. Solo es valido mientras la transaccion no revierta: pasar
  /// `null` (default) cuando cada evento va en su propia transaccion.
  ProyectorEventosPostgres(this._sesion, {Set<String>? cacheTiendas})
    : _cacheTiendas = cacheTiendas;

  final Session _sesion;
  final Set<String>? _cacheTiendas;

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
      case 'customRoleUpserted':
        await _rolPersonalizado(evento);
      case 'quoteUpserted':
        await _cotizacion(evento);
      case 'quoteDeleted':
        await _cotizacionEliminada(evento);
      case 'orderUpserted':
        await _pedido(evento);
      case 'wholesaleTiersReplaced':
        await _escalasMayoreo(evento);
      case 'lotePromocionReplaced':
        await _lotePromocion(evento);
      case 'comboReplaced':
        await _combo(evento);
      case 'priceListUpserted':
        await _listaPrecios(evento);
      case 'priceListDeleted':
        await _listaPreciosEliminada(evento);
      case 'priceListItemUpserted':
        await _itemListaPrecios(evento);
      case 'priceListItemDeleted':
        await _itemListaPreciosEliminado(evento);
      case 'customerProductPriceUpserted':
        await _precioClienteProducto(evento);
      case 'customerProductPriceDeleted':
        await _precioClienteProductoEliminado(evento);
      case 'customerDiscountUpserted':
        await _descuentoCliente(evento);
      case 'customerDiscountDeleted':
        await _descuentoClienteEliminado(evento);
      case 'supplierUpserted':
        await _proveedor(evento);
      case 'supplierDeleted':
        await _proveedorEliminado(evento);
      case 'purchaseCompleted':
        await _compraCompletada(evento);
      case 'productPresentationsReplaced':
        await _presentacionesProducto(evento);
      case 'presentationTypeUpserted':
        await _tipoPresentacion(evento);
      case 'attendanceChallengeCreated':
        await _desafioAsistencia(evento);
      case 'attendanceCheckedIn':
        await _entradaAsistencia(evento);
      case 'attendanceCheckedOut':
        await _salidaAsistencia(evento);
      case 'cashShiftUpserted':
        await _turnoCaja(evento);
      case 'employeeProfileUpserted':
        await _perfilEmpleado(evento);
      case 'payrollPeriodClosed':
        await _periodoNomina(evento);
      case 'productPresentationUpserted':
        // Legacy: reemplazado por productPresentationsReplaced.
        break;
      default:
        break;
    }
  }

  Future<void> _tipoPresentacion(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO tipos_presentacion (id, nombre, unidad, activo)
				VALUES (@id, @nombre, @unidad, @activo)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					unidad = EXCLUDED.unidad,
					activo = EXCLUDED.activo
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'unidad': p['unidad'] ?? 'pieza',
        'activo': _boolInt(p['activo'], defaultValue: true),
      },
    );
  }

  Future<void> _producto(EventoHub evento) async {
    final p = evento.payload;
    var id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
    await _asegurarTienda(tiendaId);
    final codigo = (p['codigoBarras'] as String? ?? '').trim();
    final idOriginal = id;
    if (codigo.isNotEmpty) {
      final existente = await _sesion.execute(
        Sql.named('''
          SELECT id FROM products
          WHERE tienda_id = @tienda AND codigo_barras = @codigo AND id <> @id
          LIMIT 1
        '''),
        parameters: {'tienda': tiendaId, 'codigo': codigo, 'id': id},
      );
      if (existente.isNotEmpty) {
        id = existente.first[0] as String;
      }
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO products (
					id, nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
					activo, tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
					proveedor_id, unidades_por_bulto, notas,
					costo_unitario, permite_stock_negativo, favorito_caja
				) VALUES (
					@id, @nombre, @codigo, @precio, @unidad, @ruta, @activo, @tienda,
					@vertical, @categoria, @piezas, @proveedor, @bulto, @notas,
					@costo, @permiteNegativo, @favorito
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
					notas = EXCLUDED.notas,
					costo_unitario = EXCLUDED.costo_unitario,
					permite_stock_negativo = EXCLUDED.permite_stock_negativo,
					favorito_caja = EXCLUDED.favorito_caja
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
        'costo': _dbl(p['costoUnitario']),
        'permiteNegativo': _boolInt(p['permiteStockNegativo'], defaultValue: true),
        'favorito': _boolInt(p['favoritoCaja']),
      },
    );
    // Integridad referencial: si el id entrante se remapeó a un producto
    // canónico existente (mismo código), preservar el id original como alias
    // INACTIVO en vez de descartarlo. Antes se descartaba, y las ventas/stock
    // que ya lo referenciaban rompían la llave foránea (23503) para siempre.
    // Con código vacío no entra al índice único (tienda, código) y activo=0 lo
    // oculta del catálogo, así que no aparece como duplicado.
    if (id != idOriginal) {
      await _sesion.execute(
        Sql.named('''
					INSERT INTO products (
						id, nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
						activo, tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
						proveedor_id, unidades_por_bulto, notas,
						costo_unitario, permite_stock_negativo, favorito_caja
					) VALUES (
						@id, @nombre, '', @precio, @unidad, @ruta, 0, @tienda, @vertical,
						@categoria, @piezas, @proveedor, @bulto, @notas, @costo,
						@permiteNegativo, @favorito
					)
					ON CONFLICT (id) DO UPDATE SET activo = 0, codigo_barras = ''
				'''),
        parameters: {
          'id': idOriginal,
          'nombre': p['nombre'] ?? '',
          'precio': _dbl(p['precioBase']),
          'unidad': p['unidadMedida'] ?? 'pieza',
          'ruta': p['rutaImagen'] ?? '',
          'tienda': tiendaId,
          'vertical': p['moduloVertical'] ?? 'general',
          'categoria': p['categoriaId'],
          'piezas': _intNullable(p['piezasPorCaja']),
          'proveedor': p['proveedorId'],
          'bulto': _intNullable(p['unidadesPorBulto']),
          'notas': p['notas'] ?? '',
          'costo': _dbl(p['costoUnitario']),
          'permiteNegativo': _boolInt(p['permiteStockNegativo'], defaultValue: true),
          'favorito': _boolInt(p['favoritoCaja']),
        },
      );
    }
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
					telefono, email, rfc, direccion, notas, dias_credito
				) VALUES (
					@id, @nombre, @lista, @credito, @activo,
					@telefono, @email, @rfc, @direccion, @notas, @dias
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
					notas = EXCLUDED.notas,
					dias_credito = EXCLUDED.dias_credito
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
        'dias': _int(p['diasCredito'] ?? DIAS_CREDITO_PREDETERMINADO),
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
					creada_en, vendedor_id, estado, turno_caja_id,
					descuento_ticket, monto_efectivo, monto_tarjeta, monto_transferencia,
					credito_dias, credito_vence_en
				) VALUES (
					@id, @tienda, @caja, @cliente, @metodo, @total,
					@creada, @vendedor, 'completada', @turno,
					@descuento, @efectivo, @tarjeta, @transferencia,
					@creditoDias, @creditoVence
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
        'descuento': _dbl(p['descuentoTicket']),
        'efectivo': p['montoEfectivo'],
        'tarjeta': p['montoTarjeta'],
        'transferencia': p['montoTransferencia'],
        'creditoDias': p['creditoDias'],
        'creditoVence': p['creditoVenceEn'],
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
    await _deltaStock(productoId, evento.tiendaId, delta, actualizado);
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
      Sql.named(
        'UPDATE sales SET total = @total, estado = @estado WHERE id = @id',
      ),
      parameters: {'total': total, 'estado': nuevoEstado, 'id': ventaId},
    );
  }

  Future<void> _asegurarTienda(String tiendaId) async {
    if (tiendaId.isEmpty) {
      return;
    }
    final cache = _cacheTiendas;
    if (cache != null && !cache.add(tiendaId)) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO stores (id, nombre, direccion, activa)
				VALUES (@id, @nombre, '', 1)
				ON CONFLICT (id) DO NOTHING
			'''),
      parameters: {'id': tiendaId, 'nombre': tiendaId},
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
				INSERT INTO stores (id, nombre, direccion, activa, latitud, longitud, radio_metros)
				VALUES (@id, @nombre, @direccion, @activa, @lat, @lon, @radio)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					direccion = EXCLUDED.direccion,
					activa = EXCLUDED.activa,
					latitud = COALESCE(EXCLUDED.latitud, stores.latitud),
					longitud = COALESCE(EXCLUDED.longitud, stores.longitud),
					radio_metros = CASE
						WHEN EXCLUDED.latitud IS NOT NULL THEN EXCLUDED.radio_metros
						ELSE stores.radio_metros
					END
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'direccion': p['direccion'] ?? '',
        'activa': (p['activa'] as bool? ?? true) ? 1 : 0,
        'lat': p['latitud'],
        'lon': p['longitud'],
        'radio': _radioMetrosPayload(p),
      },
    );
  }

  double _radioMetrosPayload(Map<String, Object?> p) {
    final canonico = p['radioMetros'];
    if (canonico is num) {
      return canonico.toDouble();
    }
    final legacy = p['radioMetrosAsistencia'];
    if (legacy is num) {
      return legacy.toDouble();
    }
    return 150;
  }

  Future<void> _almacen(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO almacenes (
					id, nombre, tienda_id, activo, latitud, longitud, radio_metros
				) VALUES (
					@id, @nombre, @tienda, @activo, @lat, @lon, @radio
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					tienda_id = EXCLUDED.tienda_id,
					activo = EXCLUDED.activo,
					latitud = EXCLUDED.latitud,
					longitud = EXCLUDED.longitud,
					radio_metros = EXCLUDED.radio_metros
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'tienda': p['tiendaId'],
        'activo': _boolInt(p['activo'], defaultValue: true),
        'lat': p['latitud'],
        'lon': p['longitud'],
        'radio': (p['radioMetros'] as num?)?.toDouble() ?? 150,
      },
    );
  }

  Future<void> _turnoCaja(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
    await _asegurarTienda(tiendaId);
    await _sesion.execute(
      Sql.named('''
				INSERT INTO cash_shifts (
					id, tienda_id, caja_id, vendedor_id, fondo_inicial,
					total_efectivo, total_tarjeta, total_transferencia,
					total_ventas, cantidad_ventas, abierto_en, cerrado_en, estado
				) VALUES (
					@id, @tienda, @caja, @vendedor, @fondo,
					@efectivo, @tarjeta, @transferencia,
					@ventas, @cantidad, @abierto, @cerrado, @estado
				)
				ON CONFLICT (id) DO UPDATE SET
					tienda_id = EXCLUDED.tienda_id,
					caja_id = EXCLUDED.caja_id,
					vendedor_id = EXCLUDED.vendedor_id,
					fondo_inicial = EXCLUDED.fondo_inicial,
					total_efectivo = EXCLUDED.total_efectivo,
					total_tarjeta = EXCLUDED.total_tarjeta,
					total_transferencia = EXCLUDED.total_transferencia,
					total_ventas = EXCLUDED.total_ventas,
					cantidad_ventas = EXCLUDED.cantidad_ventas,
					abierto_en = EXCLUDED.abierto_en,
					cerrado_en = EXCLUDED.cerrado_en,
					estado = EXCLUDED.estado
			'''),
      parameters: {
        'id': id,
        'tienda': tiendaId,
        'caja': p['cajaId'] ?? evento.dispositivoId,
        'vendedor': p['vendedorId'],
        'fondo': _dbl(p['fondoInicial']),
        'efectivo': _dbl(p['totalEfectivo']),
        'tarjeta': _dbl(p['totalTarjeta']),
        'transferencia': _dbl(p['totalTransferencia']),
        'ventas': _dbl(p['totalVentas']),
        'cantidad': _int(p['cantidadVentas']),
        'abierto': p['abiertoEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'cerrado': p['cerradoEn'],
        'estado': p['estado'] ?? 'abierto',
      },
    );
  }

  Future<void> _perfilEmpleado(EventoHub evento) async {
    final p = evento.payload;
    final usuarioId = p['usuarioId'] as String? ?? '';
    if (usuarioId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO employee_profiles (
					usuario_id, tarifa_hora, tipo_pago, actualizado_en
				) VALUES (
					@usuario, @tarifa, @tipo, @actualizado
				)
				ON CONFLICT (usuario_id) DO UPDATE SET
					tarifa_hora = EXCLUDED.tarifa_hora,
					tipo_pago = EXCLUDED.tipo_pago,
					actualizado_en = EXCLUDED.actualizado_en
			'''),
      parameters: {
        'usuario': usuarioId,
        'tarifa': _dbl(p['tarifaHora']),
        'tipo': p['tipoPago'] ?? 'por_hora',
        'actualizado':
            p['actualizadoEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _periodoNomina(EventoHub evento) async {
    final p = evento.payload;
    final periodoId = p['periodoId'] as String? ?? '';
    if (periodoId.isEmpty) {
      return;
    }
    final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
    await _asegurarTienda(tiendaId);
    await _sesion.execute(
      Sql.named('''
				INSERT INTO payroll_periods (
					id, tienda_id, inicio_en, fin_en, estado, cerrado_en, cerrado_por
				) VALUES (
					@id, @tienda, @inicio, @fin, @estado, @cerrado, @cerradoPor
				)
				ON CONFLICT (id) DO UPDATE SET
					tienda_id = EXCLUDED.tienda_id,
					inicio_en = EXCLUDED.inicio_en,
					fin_en = EXCLUDED.fin_en,
					estado = EXCLUDED.estado,
					cerrado_en = EXCLUDED.cerrado_en,
					cerrado_por = EXCLUDED.cerrado_por
			'''),
      parameters: {
        'id': periodoId,
        'tienda': tiendaId,
        'inicio': p['inicioEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'fin': p['finEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'estado': p['estado'] ?? 'cerrado',
        'cerrado':
            p['cerradoEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'cerradoPor': p['cerradoPor'],
      },
    );
    await _sesion.execute(
      Sql.named('DELETE FROM payroll_lines WHERE periodo_id = @id'),
      parameters: {'id': periodoId},
    );
    for (final linea in _listaMapas(p['lineas'])) {
      final lineaId = linea['id'] as String? ?? '';
      if (lineaId.isEmpty) {
        continue;
      }
      await _sesion.execute(
        Sql.named('''
					INSERT INTO payroll_lines (
						id, periodo_id, usuario_id, horas_trabajadas,
						tarifa_hora, monto_bruto, monto_neto
					) VALUES (
						@id, @periodo, @usuario, @horas, @tarifa, @bruto, @neto
					)
					ON CONFLICT (id) DO UPDATE SET
						periodo_id = EXCLUDED.periodo_id,
						usuario_id = EXCLUDED.usuario_id,
						horas_trabajadas = EXCLUDED.horas_trabajadas,
						tarifa_hora = EXCLUDED.tarifa_hora,
						monto_bruto = EXCLUDED.monto_bruto,
						monto_neto = EXCLUDED.monto_neto
				'''),
        parameters: {
          'id': lineaId,
          'periodo': periodoId,
          'usuario': linea['usuarioId'] ?? '',
          'horas': _dbl(linea['horasTrabajadas']),
          'tarifa': _dbl(linea['tarifaHora']),
          'bruto': _dbl(linea['montoBruto']),
          'neto': _dbl(linea['montoNeto']),
        },
      );
    }
  }

  Future<void> _usuario(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    final pinCredencial = _extraerPinCredencial(p);
    if (id.isEmpty || pinCredencial == null) {
      return;
    }
    final actualizadoEn = _textoTemporal(
      p['actualizadoEn'],
      fallback: evento.creadoEn.toUtc().toIso8601String(),
    );
    final codigo = ValidadorCodigoUsuario.normalizar(
      p['codigo'] as String? ?? '',
    );
    if (codigo.isEmpty) {
      return;
    }
    final existente = await _sesion.execute(
      Sql.named('SELECT actualizado_en FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (existente.isNotEmpty) {
      final local = _textoTemporal(
        existente.first.toColumnMap()['actualizado_en'],
      );
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
					pin_credencial, creado_en, actualizado_en, rol_personalizado_id
				) VALUES (
					@id, @nombre, @codigo, @rol, @tienda, @activo,
					@credencial, @creado, @actualizado, @rolPersonalizado
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					codigo = EXCLUDED.codigo,
					rol = EXCLUDED.rol,
					tienda_id = EXCLUDED.tienda_id,
					activo = EXCLUDED.activo,
					pin_credencial = EXCLUDED.pin_credencial,
					creado_en = EXCLUDED.creado_en,
					actualizado_en = EXCLUDED.actualizado_en,
					rol_personalizado_id = EXCLUDED.rol_personalizado_id
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'codigo': codigo,
        'rol': p['rol'] ?? 'empleado',
        'tienda': p['tiendaId'],
        'activo': _boolInt(p['activo'], defaultValue: true),
        'credencial': pinCredencial,
        'creado': _textoTemporal(
          p['creadoEn'],
          fallback: evento.creadoEn.toUtc().toIso8601String(),
        ),
        'actualizado': actualizadoEn,
        'rolPersonalizado': p['rolPersonalizadoId'],
      },
    );
  }

  Future<void> _rolPersonalizado(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final permisos = p['permisosAdmin'];
    final categorias = p['categoriasPermitidas'];
    await _sesion.execute(
      Sql.named('''
				INSERT INTO custom_roles (
					id, nombre, descripcion, permisos_json, categorias_json, activo, tienda_id
				) VALUES (
					@id, @nombre, @descripcion, @permisos, @categorias, @activo, @tienda
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					descripcion = EXCLUDED.descripcion,
					permisos_json = EXCLUDED.permisos_json,
					categorias_json = EXCLUDED.categorias_json,
					activo = EXCLUDED.activo,
					tienda_id = EXCLUDED.tienda_id
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'descripcion': p['descripcion'] ?? '',
        'permisos': jsonEncode(permisos ?? []),
        'categorias': jsonEncode(categorias ?? []),
        'activo': _boolInt(p['activo'], defaultValue: true),
        'tienda': p['tiendaId'],
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
      parameters: {'codigo': codigo, 'id': usuarioId},
    );
    if (conflicto.isEmpty) {
      return;
    }
    final cols = conflicto.first.toColumnMap();
    final otroId = cols['id'] as String? ?? '';
    final otroActualizado = _textoTemporal(cols['actualizado_en']);
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

  Future<void> _cotizacion(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _asegurarTienda(evento.tiendaId);
    await _sesion.execute(
      Sql.named('''
				INSERT INTO quotes (
					id, tienda_id, nombre, cliente_id, nombre_cliente, total, notas,
					vigencia_dias, creada_en, caja_id, vendedor_id
				) VALUES (
					@id, @tienda, @nombre, @cliente, @nombreCliente, @total, @notas,
					@vigencia, @creada, @caja, @vendedor
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					cliente_id = EXCLUDED.cliente_id,
					nombre_cliente = EXCLUDED.nombre_cliente,
					total = EXCLUDED.total,
					notas = EXCLUDED.notas,
					vigencia_dias = EXCLUDED.vigencia_dias
			'''),
      parameters: {
        'id': id,
        'tienda': p['tiendaId'] ?? evento.tiendaId,
        'nombre': p['nombre'] ?? '',
        'cliente': p['clienteId'],
        'nombreCliente': p['nombreCliente'],
        'total': _dbl(p['total']),
        'notas': p['notas'] ?? '',
        'vigencia': _int(p['vigenciaDias'] ?? VIGENCIA_COTIZACION_DIAS),
        'creada': p['creadaEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'caja': p['cajaId'],
        'vendedor': p['vendedorId'],
      },
    );
    await _sesion.execute(
      Sql.named('DELETE FROM quote_lines WHERE cotizacion_id = @id'),
      parameters: {'id': id},
    );
    for (final linea in _listaMapas(p['lineas'])) {
      await _sesion.execute(
        Sql.named('''
					INSERT INTO quote_lines (
						cotizacion_id, producto_id, nombre_producto, cantidad,
						precio_unitario, regla_precio, subtotal
					) VALUES (
						@cotizacion, @producto, @nombre, @cantidad,
						@precio, @regla, @subtotal
					)
				'''),
        parameters: {
          'cotizacion': id,
          'producto': linea['productoId'] ?? '',
          'nombre': linea['nombreProducto'] ?? '',
          'cantidad': _dbl(linea['cantidad']),
          'precio': _dbl(linea['precioUnitario']),
          'regla': linea['reglaPrecio'] ?? 'precioBase',
          'subtotal': _dbl(linea['subtotal']),
        },
      );
    }
  }

  Future<void> _cotizacionEliminada(EventoHub evento) async {
    final id = evento.payload['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('DELETE FROM quote_lines WHERE cotizacion_id = @id'),
      parameters: {'id': id},
    );
    await _sesion.execute(
      Sql.named('DELETE FROM quotes WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> _pedido(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
    await _asegurarTienda(tiendaId);
    await _sesion.execute(
      Sql.named('''
				INSERT INTO orders (
					id, tienda_id, cliente_id, nombre_entrega, telefono_entrega,
					direccion_entrega, es_credito, credito_dias, credito_vence_en,
					metodo_pago, total, notas, estado, asignado_a_usuario_id,
					asignado_a_usuario_nombre, asignado_en, creado_en,
					creado_por_usuario_id, venta_id
				) VALUES (
					@id, @tienda, @cliente, @nombre, @telefono, @direccion,
					@esCredito, @creditoDias, @creditoVence, @metodo, @total,
					@notas, @estado, @asignadoId, @asignadoNombre, @asignadoEn,
					@creado, @creadoPor, @venta
				)
				ON CONFLICT (id) DO UPDATE SET
					cliente_id = EXCLUDED.cliente_id,
					nombre_entrega = EXCLUDED.nombre_entrega,
					telefono_entrega = EXCLUDED.telefono_entrega,
					direccion_entrega = EXCLUDED.direccion_entrega,
					es_credito = EXCLUDED.es_credito,
					credito_dias = EXCLUDED.credito_dias,
					credito_vence_en = EXCLUDED.credito_vence_en,
					metodo_pago = EXCLUDED.metodo_pago,
					total = EXCLUDED.total,
					notas = EXCLUDED.notas,
					estado = EXCLUDED.estado,
					asignado_a_usuario_id = EXCLUDED.asignado_a_usuario_id,
					asignado_a_usuario_nombre = EXCLUDED.asignado_a_usuario_nombre,
					asignado_en = EXCLUDED.asignado_en,
					venta_id = EXCLUDED.venta_id
			'''),
      parameters: {
        'id': id,
        'tienda': tiendaId,
        'cliente': p['clienteId'],
        'nombre': p['nombreEntrega'] ?? '',
        'telefono': p['telefonoEntrega'] ?? '',
        'direccion': p['direccionEntrega'] ?? '',
        'esCredito': _boolInt(p['esCredito']),
        'creditoDias': p['creditoDias'],
        'creditoVence': p['creditoVenceEn'],
        'metodo': p['metodoPago'] ?? 'efectivo',
        'total': _dbl(p['total']),
        'notas': p['notas'] ?? '',
        'estado': p['estado'] ?? 'recibido',
        'asignadoId': p['asignadoAUsuarioId'],
        'asignadoNombre': p['asignadoAUsuarioNombre'],
        'asignadoEn': p['asignadoEn'],
        'creado': p['creadoEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'creadoPor': p['creadoPorUsuarioId'],
        'venta': p['ventaId'],
      },
    );
    await _sesion.execute(
      Sql.named('DELETE FROM order_lines WHERE pedido_id = @id'),
      parameters: {'id': id},
    );
    for (final linea in _listaMapas(p['lineas'])) {
      await _sesion.execute(
        Sql.named('''
					INSERT INTO order_lines (
						pedido_id, producto_id, nombre_producto, cantidad,
						precio_unitario, subtotal
					) VALUES (
						@pedido, @producto, @nombre, @cantidad, @precio, @subtotal
					)
				'''),
        parameters: {
          'pedido': id,
          'producto': linea['productoId'] ?? '',
          'nombre': linea['nombreProducto'] ?? '',
          'cantidad': _dbl(linea['cantidad']),
          'precio': _dbl(linea['precioUnitario']),
          'subtotal': _dbl(linea['subtotal']),
        },
      );
    }
  }

  Future<void> _escalasMayoreo(EventoHub evento) async {
    final p = evento.payload;
    final productoId = p['productoId'] as String? ?? '';
    if (productoId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('DELETE FROM wholesale_tiers WHERE producto_id = @producto'),
      parameters: {'producto': productoId},
    );
    for (final escala in _listaMapas(p['escalas'])) {
      await _sesion.execute(
        Sql.named('''
					INSERT INTO wholesale_tiers (producto_id, cantidad_minima, precio_unitario)
					VALUES (@producto, @cantidad, @precio)
				'''),
        parameters: {
          'producto': productoId,
          'cantidad': _dbl(escala['cantidadMinima']),
          'precio': _dbl(escala['precioUnitario']),
        },
      );
    }
  }

  Future<void> _lotePromocion(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO lotes_promocion (
					id, codigo_externo, nombre, cantidad_minima, precio_unitario, activo
				) VALUES (
					@id, @codigo, @nombre, @cantidad, @precio, @activo
				)
				ON CONFLICT (id) DO UPDATE SET
					codigo_externo = EXCLUDED.codigo_externo,
					nombre = EXCLUDED.nombre,
					cantidad_minima = EXCLUDED.cantidad_minima,
					precio_unitario = EXCLUDED.precio_unitario,
					activo = EXCLUDED.activo
			'''),
      parameters: {
        'id': id,
        'codigo': p['codigoExterno'] ?? '',
        'nombre': p['nombre'] ?? '',
        'cantidad': _dbl(p['cantidadMinima']),
        'precio': _dbl(p['precioUnitario']),
        'activo': _boolInt(p['activo'], defaultValue: true),
      },
    );
    await _sesion.execute(
      Sql.named('DELETE FROM lote_promocion_miembros WHERE lote_id = @id'),
      parameters: {'id': id},
    );
    final productoIds = p['productoIds'];
    if (productoIds is! List) {
      return;
    }
    for (final crudo in productoIds) {
      final productoId = crudo?.toString() ?? '';
      if (productoId.isEmpty) {
        continue;
      }
      await _sesion.execute(
        Sql.named('''
					INSERT INTO lote_promocion_miembros (lote_id, producto_id)
					VALUES (@lote, @producto)
					ON CONFLICT (lote_id, producto_id) DO NOTHING
				'''),
        parameters: {'lote': id, 'producto': productoId},
      );
    }
  }

  Future<void> _combo(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO combos (id, nombre, precio_combo, activo)
				VALUES (@id, @nombre, @precio, @activo)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					precio_combo = EXCLUDED.precio_combo,
					activo = EXCLUDED.activo
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'precio': _dbl(p['precioCombo']),
        'activo': _boolInt(p['activo'], defaultValue: true),
      },
    );
    await _sesion.execute(
      Sql.named('DELETE FROM combo_miembros WHERE combo_id = @id'),
      parameters: {'id': id},
    );
    final miembros = p['miembros'];
    if (miembros is! List) {
      return;
    }
    for (final crudo in miembros) {
      if (crudo is! Map) {
        continue;
      }
      final productoId = crudo['productoId']?.toString() ?? '';
      if (productoId.isEmpty) {
        continue;
      }
      final cantidadRequerida = _dbl(crudo['cantidadRequerida']);
      await _sesion.execute(
        Sql.named('''
					INSERT INTO combo_miembros (combo_id, producto_id, cantidad_requerida)
					VALUES (@combo, @producto, @cantidad)
					ON CONFLICT (combo_id, producto_id) DO UPDATE SET
						cantidad_requerida = EXCLUDED.cantidad_requerida
				'''),
        parameters: {
          'combo': id,
          'producto': productoId,
          'cantidad': cantidadRequerida == 0 ? 1.0 : cantidadRequerida,
        },
      );
    }
  }

  Future<void> _listaPrecios(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO price_lists (id, nombre, activa)
				VALUES (@id, @nombre, @activa)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					activa = EXCLUDED.activa
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'activa': _boolInt(p['activa'], defaultValue: true),
      },
    );
  }

  Future<void> _listaPreciosEliminada(EventoHub evento) async {
    final id = evento.payload['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('DELETE FROM price_list_items WHERE lista_precios_id = @id'),
      parameters: {'id': id},
    );
    await _sesion.execute(
      Sql.named(
        'UPDATE customers SET lista_precios_id = NULL WHERE lista_precios_id = @id',
      ),
      parameters: {'id': id},
    );
    await _sesion.execute(
      Sql.named('DELETE FROM price_lists WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> _itemListaPrecios(EventoHub evento) async {
    final p = evento.payload;
    final listaId = p['listaPreciosId'] as String? ?? '';
    final productoId = p['productoId'] as String? ?? '';
    if (listaId.isEmpty || productoId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO price_list_items (
					lista_precios_id, producto_id, precio_unitario
				) VALUES (@lista, @producto, @precio)
				ON CONFLICT (lista_precios_id, producto_id) DO UPDATE SET
					precio_unitario = EXCLUDED.precio_unitario
			'''),
      parameters: {
        'lista': listaId,
        'producto': productoId,
        'precio': _dbl(p['precioUnitario']),
      },
    );
  }

  Future<void> _itemListaPreciosEliminado(EventoHub evento) async {
    final p = evento.payload;
    final listaId = p['listaPreciosId'] as String? ?? '';
    final productoId = p['productoId'] as String? ?? '';
    if (listaId.isEmpty || productoId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				DELETE FROM price_list_items
				WHERE lista_precios_id = @lista AND producto_id = @producto
			'''),
      parameters: {'lista': listaId, 'producto': productoId},
    );
  }

  Future<void> _precioClienteProducto(EventoHub evento) async {
    final p = evento.payload;
    final clienteId = p['clienteId'] as String? ?? '';
    final productoId = p['productoId'] as String? ?? '';
    if (clienteId.isEmpty || productoId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO customer_product_prices (
					cliente_id, producto_id, precio_unitario
				) VALUES (@cliente, @producto, @precio)
				ON CONFLICT (cliente_id, producto_id) DO UPDATE SET
					precio_unitario = EXCLUDED.precio_unitario
			'''),
      parameters: {
        'cliente': clienteId,
        'producto': productoId,
        'precio': _dbl(p['precioUnitario']),
      },
    );
  }

  Future<void> _precioClienteProductoEliminado(EventoHub evento) async {
    final p = evento.payload;
    final clienteId = p['clienteId'] as String? ?? '';
    final productoId = p['productoId'] as String? ?? '';
    if (clienteId.isEmpty || productoId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				DELETE FROM customer_product_prices
				WHERE cliente_id = @cliente AND producto_id = @producto
			'''),
      parameters: {'cliente': clienteId, 'producto': productoId},
    );
  }

  Future<void> _descuentoCliente(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO customer_discounts (
					id, cliente_id, tipo, valor, producto_id,
					condicion, umbral, activo, descripcion
				) VALUES (
					@id, @cliente, @tipo, @valor, @producto,
					@condicion, @umbral, @activo, @descripcion
				)
				ON CONFLICT (id) DO UPDATE SET
					cliente_id = EXCLUDED.cliente_id,
					tipo = EXCLUDED.tipo,
					valor = EXCLUDED.valor,
					producto_id = EXCLUDED.producto_id,
					condicion = EXCLUDED.condicion,
					umbral = EXCLUDED.umbral,
					activo = EXCLUDED.activo,
					descripcion = EXCLUDED.descripcion
			'''),
      parameters: {
        'id': id,
        'cliente': p['clienteId'] ?? '',
        'tipo': p['tipo'] ?? 'porcentajeGeneral',
        'valor': _dbl(p['valor']),
        'producto': p['productoId'],
        'condicion': p['condicion'] ?? 'siempre',
        'umbral': p['umbral'],
        'activo': _boolInt(p['activo'], defaultValue: true),
        'descripcion': p['descripcion'] ?? '',
      },
    );
  }

  Future<void> _descuentoClienteEliminado(EventoHub evento) async {
    final id = evento.payload['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('DELETE FROM customer_discounts WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> _proveedor(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				INSERT INTO suppliers (
					id, nombre, contacto, telefono, activo,
					email, rfc, direccion, notas, dias_credito
				) VALUES (
					@id, @nombre, @contacto, @telefono, @activo,
					@email, @rfc, @direccion, @notas, @dias
				)
				ON CONFLICT (id) DO UPDATE SET
					nombre = EXCLUDED.nombre,
					contacto = EXCLUDED.contacto,
					telefono = EXCLUDED.telefono,
					activo = EXCLUDED.activo,
					email = EXCLUDED.email,
					rfc = EXCLUDED.rfc,
					direccion = EXCLUDED.direccion,
					notas = EXCLUDED.notas,
					dias_credito = EXCLUDED.dias_credito
			'''),
      parameters: {
        'id': id,
        'nombre': p['nombre'] ?? '',
        'contacto': p['contacto'] ?? '',
        'telefono': p['telefono'] ?? '',
        'activo': _boolInt(p['activo'], defaultValue: true),
        'email': p['email'] ?? '',
        'rfc': p['rfc'] ?? '',
        'direccion': p['direccion'] ?? '',
        'notas': p['notas'] ?? '',
        'dias': _int(p['diasCredito']),
      },
    );
  }

  Future<void> _proveedorEliminado(EventoHub evento) async {
    final id = evento.payload['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named(
        'UPDATE products SET proveedor_id = NULL WHERE proveedor_id = @id',
      ),
      parameters: {'id': id},
    );
    await _sesion.execute(
      Sql.named('DELETE FROM suppliers WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> _compraCompletada(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final tiendaRaw = p['tiendaId'];
    final tiendaId = (tiendaRaw is String && tiendaRaw.trim().isNotEmpty)
        ? tiendaRaw
        : null;
    if (tiendaId != null) {
      await _asegurarTienda(tiendaId);
    }
    final existente = await _sesion.execute(
      Sql.named('SELECT id FROM purchases WHERE id = @id'),
      parameters: {'id': id},
    );
    final esNueva = existente.isEmpty;
    await _sesion.execute(
      Sql.named('''
				INSERT INTO purchases (
					id, tienda_id, proveedor_id, fecha_compra, notas, total,
					creada_en, creado_por
				) VALUES (
					@id, @tienda, @proveedor, @fecha, @notas, @total, @creada, @creadoPor
				)
				ON CONFLICT (id) DO UPDATE SET
					tienda_id = EXCLUDED.tienda_id,
					proveedor_id = EXCLUDED.proveedor_id,
					fecha_compra = EXCLUDED.fecha_compra,
					notas = EXCLUDED.notas,
					total = EXCLUDED.total,
					creada_en = EXCLUDED.creada_en,
					creado_por = EXCLUDED.creado_por
			'''),
      parameters: {
        'id': id,
        'tienda': tiendaId,
        'proveedor': p['proveedorId'] ?? '',
        'fecha': p['fechaCompra'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'notas': p['notas'] ?? '',
        'total': _dbl(p['total']),
        'creada': p['creadaEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'creadoPor': p['creadoPor'],
      },
    );
    await _sesion.execute(
      Sql.named('DELETE FROM purchase_lines WHERE compra_id = @id'),
      parameters: {'id': id},
    );
    await _sesion.execute(
      Sql.named('DELETE FROM purchase_allocations WHERE compra_id = @id'),
      parameters: {'id': id},
    );
    final creadaEn =
        p['creadaEn'] as String? ?? evento.creadoEn.toUtc().toIso8601String();
    for (final linea in _listaMapas(p['lineas'])) {
      await _sesion.execute(
        Sql.named('''
					INSERT INTO purchase_lines (
						compra_id, producto_id, nombre_producto, cantidad,
						costo_unitario, subtotal
					) VALUES (
						@compra, @producto, @nombre, @cantidad, @costo, @subtotal
					)
				'''),
        parameters: {
          'compra': id,
          'producto': linea['productoId'] ?? '',
          'nombre': linea['nombreProducto'] ?? '',
          'cantidad': _dbl(linea['cantidad']),
          'costo': _dbl(linea['costoUnitario']),
          'subtotal': _dbl(linea['subtotal']),
        },
      );
    }
    final asignaciones = _listaMapas(p['asignaciones']);
    if (asignaciones.isEmpty) {
      // Compatibilidad legacy: stock a tienda del evento.
      if (esNueva) {
        final destino = tiendaId ?? evento.tiendaId;
        for (final linea in _listaMapas(p['lineas'])) {
          await _deltaStock(
            linea['productoId'] as String? ?? '',
            destino,
            _dbl(linea['cantidad']),
            creadaEn,
          );
        }
      }
      return;
    }
    var seq = 0;
    for (final a in asignaciones) {
      seq++;
      final allocId = a['id'] as String? ?? '$id-alloc-$seq';
      final destinoTipo = a['destinoTipo'] as String? ?? 'almacen';
      final destinoId = a['destinoId'] as String? ?? '';
      final productoId = a['productoId'] as String? ?? '';
      final cantidad = _dbl(a['cantidad']);
      await _sesion.execute(
        Sql.named('''
					INSERT INTO purchase_allocations (
						id, compra_id, producto_id, destino_tipo, destino_id, cantidad
					) VALUES (
						@id, @compra, @producto, @tipo, @destino, @cantidad
					)
				'''),
        parameters: {
          'id': allocId,
          'compra': id,
          'producto': productoId,
          'tipo': destinoTipo,
          'destino': destinoId,
          'cantidad': cantidad,
        },
      );
      if (esNueva) {
        if (destinoTipo == 'tienda') {
          await _deltaStock(productoId, destinoId, cantidad, creadaEn);
        } else {
          await _deltaStockAlmacen(productoId, destinoId, cantidad, creadaEn);
        }
      }
    }
  }

  Future<void> _presentacionesProducto(EventoHub evento) async {
    final p = evento.payload;
    final productoId = p['productoId'] as String? ?? '';
    if (productoId.isEmpty) {
      return;
    }
    // Merge aditivo (no destructivo): upsert por id, sin borrar las que no
    // vengan en el evento. Antes se hacía DELETE de todas las presentaciones del
    // producto + reinsert, así que un evento viejo de un equipo con el catálogo
    // desactualizado borraba los bultos que otros equipos habían creado. Un
    // borrado real se hace inactivando (activo=0), que se propaga como campo. Así
    // la unión de presentaciones de todos los dispositivos converge sin pérdida.
    for (final presentacion in _listaMapas(p['presentaciones'])) {
      final id = presentacion['id'] as String? ?? '';
      if (id.isEmpty) {
        continue;
      }
      await _sesion.execute(
        Sql.named('''
					INSERT INTO product_presentations (
						id, producto_id, tipo_presentacion_id, nombre, factor_a_base,
						es_presentacion_base, codigo_barras, precio, activo
					) VALUES (
						@id, @producto, @tipo, @nombre, @factor, @base, @codigo, @precio, @activo
					)
					ON CONFLICT (id) DO UPDATE SET
						producto_id = EXCLUDED.producto_id,
						tipo_presentacion_id = EXCLUDED.tipo_presentacion_id,
						nombre = EXCLUDED.nombre,
						factor_a_base = EXCLUDED.factor_a_base,
						es_presentacion_base = EXCLUDED.es_presentacion_base,
						codigo_barras = EXCLUDED.codigo_barras,
						precio = EXCLUDED.precio,
						activo = EXCLUDED.activo
				'''),
        parameters: {
          'id': id,
          'producto': productoId,
          'tipo': presentacion['tipoPresentacionId'],
          'nombre': presentacion['nombre'] ?? '',
          'factor': (presentacion['factorABase'] as num?)?.toDouble() ?? 1.0,
          'base': _boolInt(presentacion['esPresentacionBase']),
          'codigo': presentacion['codigoBarras'] ?? '',
          'precio': (presentacion['precio'] as num?)?.toDouble(),
          'activo': _boolInt(presentacion['activo'], defaultValue: true),
        },
      );
    }
  }

  Future<void> _desafioAsistencia(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
    await _asegurarTienda(tiendaId);
    await _sesion.execute(
      Sql.named(
        'UPDATE attendance_challenges SET activo = 0 WHERE tienda_id = @tienda AND activo = 1',
      ),
      parameters: {'tienda': tiendaId},
    );
    await _sesion.execute(
      Sql.named('''
				INSERT INTO attendance_challenges (
					id, tienda_id, pin_hash, expira_en, creado_por,
					latitud, longitud, radio_metros, activo
				) VALUES (
					@id, @tienda, @pin, @expira, @creado,
					@lat, @lon, @radio, 1
				)
				ON CONFLICT (id) DO UPDATE SET
					pin_hash = EXCLUDED.pin_hash,
					expira_en = EXCLUDED.expira_en,
					latitud = EXCLUDED.latitud,
					longitud = EXCLUDED.longitud,
					radio_metros = EXCLUDED.radio_metros,
					activo = EXCLUDED.activo
			'''),
      parameters: {
        'id': id,
        'tienda': tiendaId,
        'pin': p['pinHash'] ?? '',
        'expira': p['expiraEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'creado': evento.dispositivoId,
        'lat': p['latitud'],
        'lon': p['longitud'],
        'radio': _dbl(p['radioMetros'] ?? 150),
      },
    );
  }

  Future<void> _entradaAsistencia(EventoHub evento) async {
    final p = evento.payload;
    final id = p['id'] as String? ?? '';
    if (id.isEmpty) {
      return;
    }
    final tiendaId = p['tiendaId'] as String? ?? evento.tiendaId;
    await _asegurarTienda(tiendaId);
    await _sesion.execute(
      Sql.named('''
				INSERT INTO attendance_records (
					id, usuario_id, tienda_id, entrada_en, metodo,
					latitud, longitud, desafio_id
				) VALUES (
					@id, @usuario, @tienda, @entrada, @metodo,
					@lat, @lon, @desafio
				)
				ON CONFLICT (id) DO UPDATE SET
					entrada_en = EXCLUDED.entrada_en,
					metodo = EXCLUDED.metodo,
					latitud = EXCLUDED.latitud,
					longitud = EXCLUDED.longitud,
					desafio_id = EXCLUDED.desafio_id
			'''),
      parameters: {
        'id': id,
        'usuario': p['usuarioId'] ?? '',
        'tienda': tiendaId,
        'entrada': p['entradaEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
        'metodo': p['metodo'] ?? '',
        'lat': p['latitud'],
        'lon': p['longitud'],
        'desafio': p['desafioId'],
      },
    );
  }

  Future<void> _salidaAsistencia(EventoHub evento) async {
    final p = evento.payload;
    final registroId = p['registroId'] as String? ?? '';
    if (registroId.isEmpty) {
      return;
    }
    await _sesion.execute(
      Sql.named('''
				UPDATE attendance_records
				SET salida_en = @salida
				WHERE id = @id
			'''),
      parameters: {
        'id': registroId,
        'salida': p['salidaEn'] ?? evento.creadoEn.toUtc().toIso8601String(),
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
    if (valor is num) {
      return valor != 0 ? 1 : 0;
    }
    return defaultValue ? 1 : 0;
  }

  /// Normaliza TIMESTAMPTZ (DateTime) o TEXT ISO a cadena comparable.
  String _textoTemporal(Object? valor, {String fallback = ''}) {
    if (valor is DateTime) {
      return valor.toUtc().toIso8601String();
    }
    if (valor is String && valor.isNotEmpty) {
      return valor;
    }
    return fallback;
  }

  String? _extraerPinCredencial(Map<String, Object?> payload) {
    final credencial = payload['pinCredencial'] as String?;
    if (credencial == null || credencial.isEmpty) {
      return null;
    }
    return credencial;
  }
}
