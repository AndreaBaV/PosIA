/// Construye y encola los eventos de sincronizacion del catalogo/admin.
///
/// Unico lugar que arma el payload de cada `SyncEvent` hacia Neon para las
/// entidades administradas por `ServicioAdmin`. Los stubs FK (ver
/// `esStubFk` en `Categoria`/`Tienda`/`Proveedor`/`Producto`) nunca se emiten
/// para no contaminar el catalogo espejo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:uuid/uuid.dart';

import '../repositories/usuario_repository.dart' show UsuarioSnapshotSync;

/// Emisor de eventos de sincronizacion para el dominio de administracion.
class AdminEmisorEventosSync {
	AdminEmisorEventosSync({
		required SyncOrchestrator syncOrchestrator,
		required String tiendaActivaId,
		required String cajaId,
	}) : _syncOrchestrator = syncOrchestrator,
	     _tiendaActivaId = tiendaActivaId,
	     _cajaId = cajaId;

	final SyncOrchestrator _syncOrchestrator;
	final String _tiendaActivaId;
	final String _cajaId;
	final Uuid _generadorId = const Uuid();

	/// Id estable para upserts de catalogo: reencolar reemplaza, no duplica.
	String _idEventoEspejo(TipoSyncEvento tipo, String claveEntidad) {
		final clave = claveEntidad.trim();
		if (clave.isEmpty) {
			return _generadorId.v4();
		}
		return '${tipo.name}:$clave';
	}

	Future<void> _emitir(SyncEvent evento) {
		return _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> categoria(Categoria categoria) {
		// Stubs FK ("Categoría") no son catálogo real; no contaminar Neon/categories.
		if (categoria.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.categoryUpserted, categoria.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.categoryUpserted,
				payload: {
					'id': categoria.id,
					'nombre': categoria.nombre,
					'icono': categoria.icono,
					'colorHex': categoria.colorHex,
					'orden': categoria.orden,
					'activa': categoria.activa,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> rolPersonalizado(RolPersonalizado rol) {
		// Stubs FK ("Rol") no son catálogo real; no contaminar Neon.
		if (rol.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.customRoleUpserted, rol.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.customRoleUpserted,
				payload: {
					'id': rol.id,
					'nombre': rol.nombre,
					'descripcion': rol.descripcion,
					'permisosAdmin': rol.permisosAdmin,
					'categoriasPermitidas': rol.categoriasPermitidas,
					'activo': rol.activo,
					'tiendaId': rol.tiendaId,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> cliente(Cliente cliente) {
		// Stubs FK ("Cliente") no son catálogo real; no contaminar Neon.
		if (cliente.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.customerUpserted, cliente.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.customerUpserted,
				payload: {
					'id': cliente.id,
					'nombre': cliente.nombre,
					'listaPreciosId': cliente.listaPreciosId,
					'creditoHabilitado': cliente.creditoHabilitado,
					'activo': cliente.activo,
					'telefono': cliente.telefono,
					'email': cliente.email,
					'rfc': cliente.rfc,
					'direccion': cliente.direccion,
					'notas': cliente.notas,
					'diasCredito': cliente.diasCredito,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> proveedor(Proveedor proveedor) {
		// Stubs FK ("Proveedor") no son catálogo real; no contaminar Neon/suppliers.
		if (proveedor.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.supplierUpserted, proveedor.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.supplierUpserted,
				payload: {
					'id': proveedor.id,
					'nombre': proveedor.nombre,
					'contacto': proveedor.contacto,
					'telefono': proveedor.telefono,
					'activo': proveedor.activo,
					'email': proveedor.email,
					'rfc': proveedor.rfc,
					'direccion': proveedor.direccion,
					'notas': proveedor.notas,
					'diasCredito': proveedor.diasCredito,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> proveedorEliminado(String proveedorId) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.supplierDeleted,
				payload: {'id': proveedorId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> compra(Compra compra) {
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.purchaseCompleted, compra.id),
				tiendaId: (compra.tiendaId != null && compra.tiendaId!.isNotEmpty)
					? compra.tiendaId!
					: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.purchaseCompleted,
				payload: {
					'id': compra.id,
					'tiendaId': compra.tiendaId,
					'proveedorId': compra.proveedorId,
					'fechaCompra': compra.fechaCompra.toIso8601String(),
					'notas': compra.notas,
					'total': compra.total,
					'creadaEn': compra.creadaEn.toIso8601String(),
					'creadoPor': compra.creadoPor,
					'lineas': compra.lineas
						.map(
							(l) => {
								'productoId': l.productoId,
								'nombreProducto': l.nombreProducto,
								'cantidad': l.cantidad,
								'costoUnitario': l.costoUnitario,
								'subtotal': l.subtotal,
							},
						)
						.toList(),
					'asignaciones': compra.asignaciones
						.map(
							(a) => {
								'id': a.id,
								'productoId': a.productoId,
								'destinoTipo': a.destinoTipo.name,
								'destinoId': a.destinoId,
								'cantidad': a.cantidad,
							},
						)
						.toList(),
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> cotizacion(Cotizacion cotizacion) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: cotizacion.tiendaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.quoteUpserted,
				payload: {
					'id': cotizacion.id,
					'tiendaId': cotizacion.tiendaId,
					'nombre': cotizacion.nombre,
					'clienteId': cotizacion.clienteId,
					'nombreCliente': cotizacion.nombreCliente,
					'total': cotizacion.total,
					'notas': cotizacion.notas,
					'vigenciaDias': cotizacion.vigenciaDias,
					'creadaEn': cotizacion.creadaEn.toIso8601String(),
					'cajaId': cotizacion.cajaId,
					'vendedorId': cotizacion.vendedorId,
					'lineas': cotizacion.lineas
						.map(
							(linea) => {
								'productoId': linea.productoId,
								'nombreProducto': linea.nombreProducto,
								'cantidad': linea.cantidad,
								'precioUnitario': linea.precioUnitario,
								'reglaPrecio': linea.reglaPrecio.name,
								'subtotal': linea.subtotal,
							},
						)
						.toList(),
				},
				creadoEn: cotizacion.creadaEn,
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> cotizacionEliminada(String cotizacionId) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.quoteDeleted,
				payload: {'id': cotizacionId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	/// Retorna el id del evento encolado (para empujarlo de inmediato si aplica).
	Future<String> pedido(Pedido pedido) async {
		final evento = SyncEvent(
			id: _idEventoEspejo(TipoSyncEvento.orderUpserted, pedido.id),
			tiendaId: pedido.tiendaId,
			dispositivoId: _cajaId,
			tipo: TipoSyncEvento.orderUpserted,
			payload: {
				'id': pedido.id,
				'tiendaId': pedido.tiendaId,
				'clienteId': pedido.clienteId,
				'nombreEntrega': pedido.nombreEntrega,
				'telefonoEntrega': pedido.telefonoEntrega,
				'direccionEntrega': pedido.direccionEntrega,
				'esCredito': pedido.esCredito,
				'creditoDias': pedido.creditoDias,
				'creditoVenceEn': pedido.creditoVenceEn?.toIso8601String(),
				'metodoPago': pedido.metodoPago.name,
				'total': pedido.total,
				'notas': pedido.notas,
				'estado': pedido.estado.name,
				'asignadoAUsuarioId': pedido.asignadoAUsuarioId,
				'asignadoAUsuarioNombre': pedido.asignadoAUsuarioNombre,
				'asignadoEn': pedido.asignadoEn?.toIso8601String(),
				'creadoEn': pedido.creadoEn.toIso8601String(),
				'creadoPorUsuarioId': pedido.creadoPorUsuarioId,
				'ventaId': pedido.ventaId,
				'lineas': pedido.lineas
					.map(
						(linea) => {
							'productoId': linea.productoId,
							'nombreProducto': linea.nombreProducto,
							'cantidad': linea.cantidad,
							'precioUnitario': linea.precioUnitario,
							'subtotal': linea.subtotal,
						},
					)
					.toList(),
			},
			creadoEn: pedido.creadoEn,
			estado: EstadoSyncEvento.pendiente,
		);
		await _emitir(evento);
		return evento.id;
	}

	Future<void> escalasMayoreo(String productoId, List<EscalaMayoreo> escalas) {
		// UUID: el log de Neon es append-only; un id espejo fijo deja el primer
		// payload congelado (ON CONFLICT DO NOTHING) y otras cajas/rebuilds
		// vuelven a proyectar escalas viejas.
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.wholesaleTiersReplaced,
				payload: {
					'productoId': productoId,
					'escalas': escalas
						.map(
							(escala) => {
								'cantidadMinima': escala.cantidadMinima,
								'precioUnitario': escala.precioUnitario,
							},
						)
						.toList(),
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	/// Retorna el id del evento encolado (para empujarlo de inmediato si aplica).
	/// Retorna el id del evento encolado, o cadena vacia si no se emitio.
	Future<String> lotePromocion(LotePromocion lote) async {
		// Stubs FK ("Lote promoción") no son promociones reales.
		if (lote.esStubFk) {
			return '';
		}
		final evento = SyncEvent(
			id: _idEventoEspejo(TipoSyncEvento.lotePromocionReplaced, lote.id),
			tiendaId: _tiendaActivaId,
			dispositivoId: _cajaId,
			tipo: TipoSyncEvento.lotePromocionReplaced,
			payload: {
				'id': lote.id,
				'codigoExterno': lote.codigoExterno,
				'nombre': lote.nombre,
				'cantidadMinima': lote.cantidadMinima,
				'precioUnitario': lote.precioUnitario,
				'activo': lote.activo,
				'productoIds': lote.productoIds,
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _emitir(evento);
		return evento.id;
	}

	/// Retorna el id del evento encolado (para empujarlo de inmediato si aplica).
	/// Retorna el id del evento encolado, o cadena vacia si no se emitio.
	Future<String> combo(Combo combo) async {
		// Stubs FK ("Combo") no son promociones reales.
		if (combo.esStubFk) {
			return '';
		}
		final evento = SyncEvent(
			id: _idEventoEspejo(TipoSyncEvento.comboReplaced, combo.id),
			tiendaId: _tiendaActivaId,
			dispositivoId: _cajaId,
			tipo: TipoSyncEvento.comboReplaced,
			payload: {
				'id': combo.id,
				'nombre': combo.nombre,
				'precioCombo': combo.precioCombo,
				'activo': combo.activo,
				'miembros': combo.miembros
					.map(
						(m) => {
							'productoId': m.productoId,
							'cantidadRequerida': m.cantidadRequerida,
						},
					)
					.toList(),
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _emitir(evento);
		return evento.id;
	}

	Future<void> listaPrecios(ListaPrecios lista) {
		// Stubs FK ("Lista de precios") no son catálogo real; no contaminar Neon.
		if (lista.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.priceListUpserted, lista.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.priceListUpserted,
				payload: {'id': lista.id, 'nombre': lista.nombre, 'activa': lista.activa},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> listaPreciosEliminada(String listaId) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.priceListDeleted,
				payload: {'id': listaId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> itemListaPrecios({
		required String listaId,
		required String productoId,
		required double precioUnitario,
	}) {
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(
					TipoSyncEvento.priceListItemUpserted,
					'$listaId:$productoId',
				),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.priceListItemUpserted,
				payload: {
					'listaPreciosId': listaId,
					'productoId': productoId,
					'precioUnitario': precioUnitario,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> itemListaPreciosEliminado({
		required String listaId,
		required String productoId,
	}) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.priceListItemDeleted,
				payload: {'listaPreciosId': listaId, 'productoId': productoId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> precioClienteProducto({
		required String clienteId,
		required String productoId,
		required double precioUnitario,
	}) {
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(
					TipoSyncEvento.customerProductPriceUpserted,
					'$clienteId:$productoId',
				),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.customerProductPriceUpserted,
				payload: {
					'clienteId': clienteId,
					'productoId': productoId,
					'precioUnitario': precioUnitario,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> precioClienteProductoEliminado({
		required String clienteId,
		required String productoId,
	}) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.customerProductPriceDeleted,
				payload: {'clienteId': clienteId, 'productoId': productoId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> descuentoCliente(DescuentoCliente descuento) {
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(
					TipoSyncEvento.customerDiscountUpserted,
					descuento.id,
				),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.customerDiscountUpserted,
				payload: {
					'id': descuento.id,
					'clienteId': descuento.clienteId,
					'tipo': descuento.tipo.name,
					'valor': descuento.valor,
					'productoId': descuento.productoId,
					'condicion': descuento.condicion.name,
					'umbral': descuento.umbral,
					'activo': descuento.activo,
					'descripcion': descuento.descripcion,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> descuentoClienteEliminado(String descuentoId) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.customerDiscountDeleted,
				payload: {'id': descuentoId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> presentacionesReemplazadas(
		String productoId,
		List<PresentacionProducto> presentaciones,
	) {
		// UUID por cambio: con id espejo fijo Neon conservaba solo el primer
		// snapshot; empaques/precios nuevos no entraban al log ni a otras cajas.
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.productPresentationsReplaced,
				payload: {
					'productoId': productoId,
					'presentaciones': presentaciones
						.map(
							(p) => {
								'id': p.id,
								'tipoPresentacionId': p.tipoPresentacionId,
								'nombre': p.nombre,
								'factorABase': p.factorABase,
								'esPresentacionBase': p.esPresentacionBase,
								'codigoBarras': p.codigoBarras,
								'precio': p.precio,
								'activo': p.activo,
							},
						)
						.toList(),
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> ventaCompletada(Venta venta) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.saleCompleted,
				payload: {
					'ventaId': venta.id,
					'total': venta.total,
					'metodoPago': venta.metodoPago.name,
					'clienteId': venta.clienteId,
					'creditoDias': venta.creditoDias,
					'creditoVenceEn': venta.creditoVenceEn?.toIso8601String(),
					'lineas': venta.lineas
						.map(
							(linea) => {
								'productoId': linea.productoId,
								'nombreProducto': linea.nombreProducto,
								'cantidad': linea.cantidad,
								'precioUnitario': linea.precioUnitario,
								'reglaPrecio': linea.reglaPrecio.name,
								'loteId': linea.loteId,
								'etiquetaLote': linea.etiquetaLote,
							},
						)
						.toList(),
				},
				creadoEn: venta.creadaEn,
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> anulacion(Venta venta) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.saleVoided,
				payload: {
					'ventaId': venta.id,
					'total': venta.total,
					'tiendaId': venta.tiendaId,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> traspaso(
		Traspaso traspaso,
		TipoSyncEvento tipo, {
		String? almacenOrigenId,
		String? almacenDestinoId,
	}) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: tipo,
				payload: {
					'traspasoId': traspaso.id,
					'tiendaOrigenId': traspaso.tiendaOrigenId,
					'tiendaDestinoId': traspaso.tiendaDestinoId,
					if (almacenOrigenId != null && almacenOrigenId.isNotEmpty)
						'almacenOrigenId': almacenOrigenId,
					if (almacenDestinoId != null && almacenDestinoId.isNotEmpty)
						'almacenDestinoId': almacenDestinoId,
					'estado': traspaso.estado.name,
					'lineas': traspaso.lineas
						.map(
							(l) => {
								'productoId': l.productoId,
								'cantidadSolicitada': l.cantidadSolicitada,
								'cantidadRecibida': l.cantidadRecibida,
							},
						)
						.toList(),
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> variante(VarianteProducto variante) {
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.variantUpserted, variante.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.variantUpserted,
				payload: {
					'id': variante.id,
					'productoPadreId': variante.productoPadreId,
					'nombre': variante.nombre,
					'sku': variante.sku,
					'codigoBarras': variante.codigoBarras,
					'precioBase': variante.precioBase,
					'activo': variante.activo,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> ajusteStock(
		String productoId,
		double delta,
		String motivo, {
		required String tiendaId,
	}) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: tiendaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.stockAdjusted,
				payload: {'productoId': productoId, 'delta': delta, 'motivo': motivo},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> devolucionParcial(
		Venta venta,
		List<Map<String, Object?>> lineas,
		double montoDevuelto,
	) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.salePartialReturn,
				payload: {
					'ventaId': venta.id,
					'montoDevuelto': montoDevuelto,
					'lineas': lineas,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> tienda(Tienda tienda) {
		// Stubs FK ("Tienda") no son sucursales reales; no contaminar Neon/stores.
		if (tienda.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.storeUpserted, tienda.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.storeUpserted,
				payload: {
					'id': tienda.id,
					'nombre': tienda.nombre,
					'direccion': tienda.direccion,
					'activa': tienda.activa,
					'latitud': tienda.latitud,
					'longitud': tienda.longitud,
					'radioMetros': tienda.radioMetrosAsistencia,
					// Compatibilidad con eventos/clientes previos.
					'radioMetrosAsistencia': tienda.radioMetrosAsistencia,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	/// [snapshot] viene de `UsuarioRepository.obtenerSnapshotSync`: contiene
	/// campos (pin, timestamps) que no vive en el modelo `Usuario` de dominio.
	Future<void> usuario(Usuario usuario, {required UsuarioSnapshotSync snapshot}) {
		// Stubs FK ("Usuario" con codigo sync-) no son personal real.
		if (usuario.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.userUpserted, usuario.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.userUpserted,
				payload: {
					'id': usuario.id,
					'nombre': usuario.nombre,
					'codigo': usuario.codigo,
					'rol': usuario.rol.name,
					'tiendaId': usuario.tiendaId,
					'rolPersonalizadoId': usuario.rolPersonalizadoId,
					'activo': usuario.activo,
					'pinCredencial': snapshot.pinCredencial,
					'creadoEn': snapshot.creadoEn,
					'actualizadoEn': snapshot.actualizadoEn,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	/// Encola la lapida de un producto borrado por el administrador.
	///
	/// El id del evento no se deriva del producto (a diferencia de los espejos):
	/// una lapida nunca debe colapsarse contra un `productUpserted` del mismo
	/// producto, porque son afirmaciones opuestas.
	Future<void> productoEliminado(String productoId) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.productDeleted,
				payload: {'id': productoId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	/// Encola la lapida de una categoria borrada por el administrador.
	Future<void> categoriaEliminada(String categoriaId) {
		return _emitir(
			SyncEvent(
				id: _generadorId.v4(),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.categoryDeleted,
				payload: {'id': categoriaId},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	/// Encola evento productUpserted para replicar catalogo.
	Future<void> producto(Producto producto) {
		// Stubs FK ("Producto") no son catálogo real; no contaminar Neon/products.
		// Emitirlos hace que pisen al producto legítimo en los demás equipos.
		if (producto.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.productUpserted, producto.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.productUpserted,
				payload: {
					'id': producto.id,
					'nombre': producto.nombre,
					'codigoBarras': producto.codigoBarras,
					'precioBase': producto.precioBase,
					'unidadMedida': producto.unidadMedida.name,
					'rutaImagen': producto.rutaImagen,
					'activo': producto.activo,
					'tiendaId': producto.tiendaId,
					'moduloVertical': producto.moduloVertical.name,
					'categoriaId': producto.categoriaId,
					'piezasPorCaja': producto.piezasPorCaja,
					'unidadesPorBulto': producto.unidadesPorBulto,
					'proveedorId': producto.proveedorId,
					'notas': producto.notas,
					'costoUnitario': producto.costoUnitario,
					'favoritoCaja': producto.favoritoCaja,
					'permiteStockNegativo': producto.permiteStockNegativo,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> almacen(Almacen almacen) {
		// Stubs FK ("Almacén") no son ubicaciones reales; no contaminar Neon.
		if (almacen.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.warehouseUpserted, almacen.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.warehouseUpserted,
				payload: {
					'id': almacen.id,
					'nombre': almacen.nombre,
					'tiendaId': almacen.tiendaId,
					'activo': almacen.activo,
					'latitud': almacen.latitud,
					'longitud': almacen.longitud,
					'radioMetros': almacen.radioMetros,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}

	Future<void> tipoPresentacion(TipoPresentacion tipo) {
		// Stubs FK ("Presentación") no son tipos de empaque reales.
		if (tipo.esStubFk) {
			return Future.value();
		}
		return _emitir(
			SyncEvent(
				id: _idEventoEspejo(TipoSyncEvento.presentationTypeUpserted, tipo.id),
				tiendaId: _tiendaActivaId,
				dispositivoId: _cajaId,
				tipo: TipoSyncEvento.presentationTypeUpserted,
				payload: {
					'id': tipo.id,
					'nombre': tipo.nombre,
					'unidad': tipo.unidad,
					'activo': tipo.activo,
				},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
	}
}
