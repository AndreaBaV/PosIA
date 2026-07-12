/// Garantiza filas padre antes de escrituras con FOREIGN KEY (sync v33).
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Inserta stubs minimos cuando un evento hijo llega antes que su padre.
///
/// Cubre todas las tablas con REFERENCES en [MigracionIntegridadReferencial].
class AseguradorPadresFk {
	AseguradorPadresFk(this._baseDatos);

	final Database _baseDatos;

	static const _tiendaSync = 'tienda-sync';

	Future<bool> _existe(String tabla, String id) async {
		final filas = await _baseDatos.query(
			tabla,
			where: 'id = ?',
			whereArgs: [id],
			limit: 1,
		);
		return filas.isNotEmpty;
	}

	Future<void> asegurarTienda(String? tiendaId) async {
		if (tiendaId == null || tiendaId.trim().isEmpty) {
			return;
		}
		if (await _existe('stores', tiendaId)) {
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
		if (await _existe('price_lists', listaId)) {
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

	Future<void> asegurarCategoria(String? categoriaId) async {
		if (categoriaId == null || categoriaId.trim().isEmpty) {
			return;
		}
		if (await _existe('categories', categoriaId)) {
			return;
		}
		await _baseDatos.insert(
			'categories',
			{
				'id': categoriaId,
				'nombre': 'Categoría',
				'icono': 'shopping_basket',
				'color_hex': '#4CAF50',
				'orden': 0,
				'activa': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarProveedor(String? proveedorId) async {
		if (proveedorId == null || proveedorId.trim().isEmpty) {
			return;
		}
		if (await _existe('proveedores', proveedorId)) {
			return;
		}
		await _baseDatos.insert(
			'proveedores',
			{
				'id': proveedorId,
				'nombre': 'Proveedor',
				'contacto': '',
				'telefono': '',
				'activo': 1,
				'email': '',
				'rfc': '',
				'direccion': '',
				'notas': '',
				'dias_credito': 0,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarCliente(String? clienteId) async {
		if (clienteId == null || clienteId.trim().isEmpty) {
			return;
		}
		if (await _existe('customers', clienteId)) {
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

	Future<void> asegurarRolPersonalizado(
		String? rolId, {
		String? tiendaId,
	}) async {
		if (rolId == null || rolId.trim().isEmpty) {
			return;
		}
		if (await _existe('roles_personalizados', rolId)) {
			return;
		}
		await asegurarTienda(tiendaId);
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

	Future<void> asegurarUsuario(
		String? usuarioId, {
		String? tiendaId,
	}) async {
		if (usuarioId == null || usuarioId.trim().isEmpty) {
			return;
		}
		if (await _existe('usuarios', usuarioId)) {
			return;
		}
		await asegurarTienda(tiendaId);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'usuarios',
			{
				'id': usuarioId,
				'nombre': 'Usuario',
				'codigo': 'sync-${usuarioId.replaceAll('-', '')}',
				'pin_credencial': 'sync',
				'rol': RolUsuario.empleado.name,
				'tienda_id': tiendaId,
				'activo': 1,
				'creado_en': ahora,
				'actualizado_en': ahora,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarVendedor(
		String? vendedorId, {
		String? tiendaId,
	}) async {
		if (vendedorId == null || vendedorId.trim().isEmpty) {
			return;
		}
		if (await _existe('vendedores', vendedorId)) {
			return;
		}
		await asegurarTienda(tiendaId);
		await _baseDatos.insert(
			'vendedores',
			{
				'id': vendedorId,
				'nombre': 'Vendedor',
				'codigo': '000',
				'activo': 1,
				'tienda_id': tiendaId,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarAlmacen(
		String? almacenId, {
		String? tiendaId,
	}) async {
		if (almacenId == null || almacenId.trim().isEmpty) {
			return;
		}
		if (await _existe('almacenes', almacenId)) {
			return;
		}
		await asegurarTienda(tiendaId);
		await _baseDatos.insert(
			'almacenes',
			{
				'id': almacenId,
				'nombre': 'Almacén',
				'tienda_id': tiendaId,
				'activo': 1,
				'radio_metros': 150,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarTurnoCaja(
		String? turnoId, {
		String? tiendaId,
	}) async {
		if (turnoId == null || turnoId.trim().isEmpty) {
			return;
		}
		if (await _existe('cash_shifts', turnoId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		await asegurarTienda(tienda);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'cash_shifts',
			{
				'id': turnoId,
				'tienda_id': tienda,
				'caja_id': 'sync',
				'fondo_inicial': 0.0,
				'total_efectivo': 0.0,
				'total_tarjeta': 0.0,
				'total_transferencia': 0.0,
				'total_ventas': 0.0,
				'cantidad_ventas': 0,
				'abierto_en': ahora,
				'estado': EstadoTurnoCaja.cerrado.name,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarVenta(
		String? ventaId, {
		String? tiendaId,
	}) async {
		if (ventaId == null || ventaId.trim().isEmpty) {
			return;
		}
		if (await _existe('sales', ventaId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		await asegurarTienda(tienda);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'sales',
			{
				'id': ventaId,
				'tienda_id': tienda,
				'caja_id': 'sync',
				'metodo_pago': MetodoPago.efectivo.name,
				'total': 0.0,
				'creada_en': ahora,
				'estado': EstadoVenta.completada.name,
				'descuento_ticket': 0.0,
				'credito_liquidado': 0,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarTraspaso(String? traspasoId) async {
		if (traspasoId == null || traspasoId.trim().isEmpty) {
			return;
		}
		if (await _existe('transfers', traspasoId)) {
			return;
		}
		await asegurarTienda(_tiendaSync);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'transfers',
			{
				'id': traspasoId,
				'tienda_origen_id': _tiendaSync,
				'tienda_destino_id': _tiendaSync,
				'estado': EstadoTraspaso.solicitado.name,
				'solicitado_en': ahora,
				'notas': '',
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarCompra(
		String? compraId, {
		String? tiendaId,
		String? proveedorId,
	}) async {
		if (compraId == null || compraId.trim().isEmpty) {
			return;
		}
		if (await _existe('purchases', compraId)) {
			return;
		}
		if (tiendaId != null && tiendaId.trim().isNotEmpty) {
			await asegurarTienda(tiendaId);
		}
		await asegurarProveedor(proveedorId ?? 'proveedor-sync');
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'purchases',
			{
				'id': compraId,
				'tienda_id': tiendaId?.trim().isNotEmpty == true ? tiendaId : null,
				'proveedor_id': proveedorId ?? 'proveedor-sync',
				'fecha_compra': ahora,
				'notas': '',
				'total': 0.0,
				'creada_en': ahora,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarPedido(
		String? pedidoId, {
		String? tiendaId,
	}) async {
		if (pedidoId == null || pedidoId.trim().isEmpty) {
			return;
		}
		if (await _existe('orders', pedidoId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		await asegurarTienda(tienda);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'orders',
			{
				'id': pedidoId,
				'tienda_id': tienda,
				'nombre_entrega': '',
				'telefono_entrega': '',
				'direccion_entrega': '',
				'es_credito': 0,
				'metodo_pago': MetodoPago.efectivo.name,
				'total': 0.0,
				'notas': '',
				'estado': EstadoPedido.recibido.name,
				'creado_en': ahora,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarCotizacion(
		String? cotizacionId, {
		String? tiendaId,
	}) async {
		if (cotizacionId == null || cotizacionId.trim().isEmpty) {
			return;
		}
		if (await _existe('quotes', cotizacionId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		await asegurarTienda(tienda);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'quotes',
			{
				'id': cotizacionId,
				'tienda_id': tienda,
				'nombre': '',
				'total': 0.0,
				'notas': '',
				'vigencia_dias': 15,
				'creada_en': ahora,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarTicketEspera(
		String? ticketId, {
		String? tiendaId,
	}) async {
		if (ticketId == null || ticketId.trim().isEmpty) {
			return;
		}
		if (await _existe('held_tickets', ticketId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		await asegurarTienda(tienda);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'held_tickets',
			{
				'id': ticketId,
				'tienda_id': tienda,
				'caja_id': 'sync',
				'notas': '',
				'descuento_ticket': 0.0,
				'total': 0.0,
				'creado_en': ahora,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarLotePromocion(String? loteId) async {
		if (loteId == null || loteId.trim().isEmpty) {
			return;
		}
		if (await _existe('lotes_promocion', loteId)) {
			return;
		}
		await _baseDatos.insert(
			'lotes_promocion',
			{
				'id': loteId,
				'codigo_externo': loteId,
				'nombre': 'Lote promoción',
				'cantidad_minima': 1.0,
				'precio_unitario': 0.0,
				'activo': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarTipoPresentacion(String? tipoId) async {
		if (tipoId == null || tipoId.trim().isEmpty) {
			return;
		}
		if (await _existe('tipos_presentacion', tipoId)) {
			return;
		}
		await _baseDatos.insert(
			'tipos_presentacion',
			{
				'id': tipoId,
				'nombre': 'Presentación',
				'unidad': UnidadMedida.pieza.name,
				'activo': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarPeriodoNomina(
		String? periodoId, {
		String? tiendaId,
	}) async {
		if (periodoId == null || periodoId.trim().isEmpty) {
			return;
		}
		if (await _existe('periodos_nomina', periodoId)) {
			return;
		}
		await asegurarTienda(tiendaId);
		final ahora = DateTime.now().toUtc().toIso8601String();
		await _baseDatos.insert(
			'periodos_nomina',
			{
				'id': periodoId,
				'tienda_id': tiendaId,
				'inicio_en': ahora,
				'fin_en': ahora,
				'estado': 'abierto',
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarDesafioAsistencia(
		String? desafioId, {
		String? tiendaId,
	}) async {
		if (desafioId == null || desafioId.trim().isEmpty) {
			return;
		}
		if (await _existe('desafios_asistencia', desafioId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		await asegurarTienda(tienda);
		final expira = DateTime.now().toUtc().add(const Duration(hours: 1));
		await _baseDatos.insert(
			'desafios_asistencia',
			{
				'id': desafioId,
				'tienda_id': tienda,
				'pin_hash': 'sync',
				'expira_en': expira.toIso8601String(),
				'creado_por': 'sync',
				'radio_metros': 150,
				'activo': 0,
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
		if (await _existe('products', productoId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId!.trim() : _tiendaSync;
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

	Future<void> asegurarLoteFarmacia(
		String? loteId, {
		String? productoId,
		String? tiendaId,
	}) async {
		if (loteId == null || loteId.trim().isEmpty) {
			return;
		}
		if (await _existe('pharmacy_lots', loteId)) {
			return;
		}
		final tienda = tiendaId?.trim().isNotEmpty == true ? tiendaId! : _tiendaSync;
		final producto = productoId?.trim().isNotEmpty == true
			? productoId!.trim()
			: 'producto-sync';
		await asegurarProducto(producto, tiendaId: tienda);
		await asegurarTienda(tienda);
		final caduca = DateTime.now().toUtc().add(const Duration(days: 365));
		await _baseDatos.insert(
			'pharmacy_lots',
			{
				'id': loteId,
				'producto_id': producto,
				'tienda_id': tienda,
				'numero_lote': 'sync',
				'caduca_en': caduca.toIso8601String(),
				'cantidad': 0.0,
				'activo': 1,
			},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	Future<void> asegurarPadresDeProducto({
		required String tiendaId,
		String? categoriaId,
		String? proveedorId,
	}) async {
		await asegurarTienda(tiendaId);
		await asegurarCategoria(categoriaId);
		await asegurarProveedor(proveedorId);
	}

	Future<void> asegurarPadresDeVenta(Venta venta) async {
		await asegurarTienda(venta.tiendaId);
		await asegurarCliente(venta.clienteId);
		await asegurarVendedor(venta.vendedorId, tiendaId: venta.tiendaId);
		await asegurarTurnoCaja(venta.turnoCajaId, tiendaId: venta.tiendaId);
		for (final linea in venta.lineas) {
			await asegurarProducto(linea.productoId, tiendaId: venta.tiendaId);
			await asegurarLoteFarmacia(
				linea.loteId,
				productoId: linea.productoId,
				tiendaId: venta.tiendaId,
			);
		}
	}

	Future<void> asegurarPadresDeLineaVenta({
		required String ventaId,
		required LineaVenta linea,
		String? tiendaId,
	}) async {
		await asegurarVenta(ventaId, tiendaId: tiendaId);
		await asegurarProducto(linea.productoId, tiendaId: tiendaId);
		await asegurarLoteFarmacia(
			linea.loteId,
			productoId: linea.productoId,
			tiendaId: tiendaId,
		);
	}

	Future<void> asegurarPadresDeTraspaso(Traspaso traspaso) async {
		await asegurarTienda(traspaso.tiendaOrigenId);
		await asegurarTienda(traspaso.tiendaDestinoId);
		for (final linea in traspaso.lineas) {
			await asegurarProducto(
				linea.productoId,
				tiendaId: traspaso.tiendaOrigenId,
			);
		}
	}

	Future<void> asegurarPadresDeCompra(Compra compra) async {
		if (compra.tiendaId != null && compra.tiendaId!.trim().isNotEmpty) {
			await asegurarTienda(compra.tiendaId);
		}
		await asegurarProveedor(compra.proveedorId);
		for (final linea in compra.lineas) {
			await asegurarProducto(
				linea.productoId,
				tiendaId: compra.tiendaId ?? _tiendaSync,
			);
		}
		for (final asignacion in compra.asignaciones) {
			if (asignacion.esTienda) {
				await asegurarTienda(asignacion.destinoId);
			} else if (asignacion.esAlmacen) {
				await asegurarAlmacen(asignacion.destinoId);
			}
			await asegurarProducto(
				asignacion.productoId,
				tiendaId: asignacion.esTienda ? asignacion.destinoId : _tiendaSync,
			);
		}
	}

	Future<void> asegurarPadresDePedido(Pedido pedido) async {
		await asegurarTienda(pedido.tiendaId);
		await asegurarCliente(pedido.clienteId);
		await asegurarUsuario(pedido.asignadoAUsuarioId, tiendaId: pedido.tiendaId);
		await asegurarUsuario(pedido.creadoPorUsuarioId, tiendaId: pedido.tiendaId);
		await asegurarVenta(pedido.ventaId, tiendaId: pedido.tiendaId);
		for (final linea in pedido.lineas) {
			await asegurarProducto(linea.productoId, tiendaId: pedido.tiendaId);
		}
	}

	Future<void> asegurarPadresDeCotizacion(Cotizacion cotizacion) async {
		await asegurarTienda(cotizacion.tiendaId);
		await asegurarCliente(cotizacion.clienteId);
		await asegurarVendedor(cotizacion.vendedorId, tiendaId: cotizacion.tiendaId);
		for (final linea in cotizacion.lineas) {
			await asegurarProducto(linea.productoId, tiendaId: cotizacion.tiendaId);
		}
	}

	Future<void> asegurarPadresDeTicketEspera(TicketEnEspera ticket) async {
		await asegurarTienda(ticket.tiendaId);
		await asegurarCliente(ticket.clienteId);
		await asegurarVendedor(ticket.vendedorId, tiendaId: ticket.tiendaId);
		for (final linea in ticket.lineas) {
			await asegurarProducto(linea.productoId, tiendaId: ticket.tiendaId);
			await asegurarLoteFarmacia(
				linea.loteId,
				productoId: linea.productoId,
				tiendaId: ticket.tiendaId,
			);
		}
	}

	Future<void> asegurarPadresDeLotePromocion(LotePromocion lote) async {
		await asegurarLotePromocion(lote.id);
		for (final productoId in lote.productoIds) {
			await asegurarProducto(productoId);
		}
	}

	Future<void> asegurarPadresDePresentacion(PresentacionProducto presentacion) async {
		await asegurarProducto(presentacion.productoId);
		await asegurarTipoPresentacion(presentacion.tipoPresentacionId);
	}

	Future<void> asegurarPadresDeMovimientoInventario(
		MovimientoInventario movimiento,
	) async {
		await asegurarProducto(movimiento.productoId, tiendaId: movimiento.tiendaId);
		await asegurarTienda(movimiento.tiendaId);
		await asegurarProveedor(movimiento.proveedorId);
	}

	Future<void> asegurarPadresDeRegistroAsistencia(RegistroAsistencia registro) async {
		await asegurarUsuario(registro.usuarioId, tiendaId: registro.tiendaId);
		await asegurarTienda(registro.tiendaId);
		await asegurarDesafioAsistencia(registro.desafioId, tiendaId: registro.tiendaId);
	}

	Future<void> asegurarPadresDeLineaNomina(LineaNomina linea) async {
		await asegurarPeriodoNomina(linea.periodoId);
		await asegurarUsuario(linea.usuarioId);
	}
}
