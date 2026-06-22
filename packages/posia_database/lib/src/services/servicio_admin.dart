/// Servicio de administracion: reportes, catalogo e inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:uuid/uuid.dart';

import '../models/alta_producto_request.dart';
import '../models/alerta_faltante.dart';
import '../models/config_dispositivo.dart';
import '../models/config_impresora.dart';
import '../models/estado_sync_admin.dart';
import '../models/resumen_vendedor.dart';
import '../models/resumen_ventas_dia.dart';
import '../models/stock_por_tienda.dart';
import '../database/posia_local_database.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/sync_event_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../repositories/venta_repository.dart';
import 'servicio_corte_caja.dart';

/// Coordina operaciones del panel de administracion minimalista.
class ServicioAdmin {
	/// Crea servicio admin con repositorios requeridos.
	///
	/// [tiendaRepository] Acceso a sucursales.
	/// [ventaRepository] Acceso a ventas.
	/// [productoRepository] Acceso a catalogo.
	/// [inventarioRepository] Acceso a stock.
	/// [syncEventRepository] Cola de eventos sync.
	/// [syncOrchestrator] Orquestador de sincronizacion.
	/// [configRepository] Configuracion local del dispositivo.
	/// [tenantId] Tenant activo en licencia.
	/// [tiendaActivaId] Tienda local del dispositivo.
	/// [cajaId] Identificador del dispositivo caja.
	ServicioAdmin({
		required TiendaRepository tiendaRepository,
		required VentaRepository ventaRepository,
		required ProductoRepository productoRepository,
		required InventarioRepository inventarioRepository,
		required SyncEventRepository syncEventRepository,
		required SyncOrchestrator syncOrchestrator,
		required ConfigRepository configRepository,
		CategoriaRepository? categoriaRepository,
		ClienteRepository? clienteRepository,
		DescuentoClienteRepository? descuentoClienteRepository,
		VendedorRepository? vendedorRepository,
		UsuarioRepository? usuarioRepository,
		ProveedorRepository? proveedorRepository,
		PrecioRepository? precioRepository,
		MovimientoInventarioRepository? movimientoRepository,
		TraspasoRepository? traspasoRepository,
		VarianteRepository? varianteRepository,
		ServicioCorteCaja? servicioCorteCaja,
		required String tenantId,
		required String tiendaActivaId,
		required String cajaId,
	}) : _tiendaRepository = tiendaRepository,
	     _ventaRepository = ventaRepository,
	     _productoRepository = productoRepository,
	     _inventarioRepository = inventarioRepository,
	     _syncEventRepository = syncEventRepository,
	     _syncOrchestrator = syncOrchestrator,
	     _configRepository = configRepository,
	     _categoriaRepository = categoriaRepository,
	     _clienteRepository = clienteRepository,
	     _descuentoClienteRepository = descuentoClienteRepository,
	     _vendedorRepository = vendedorRepository,
	     _usuarioRepository = usuarioRepository,
	     _proveedorRepository = proveedorRepository,
	     _precioRepository = precioRepository,
	     _movimientoRepository = movimientoRepository,
	     _traspasoRepository = traspasoRepository,
	     _varianteRepository = varianteRepository,
	     _servicioCorteCaja = servicioCorteCaja,
	     _tenantId = tenantId,
	     _tiendaActivaId = tiendaActivaId,
	     _cajaId = cajaId;

	final TiendaRepository _tiendaRepository;
	final VentaRepository _ventaRepository;
	final ProductoRepository _productoRepository;
	final InventarioRepository _inventarioRepository;
	final SyncEventRepository _syncEventRepository;
	final SyncOrchestrator _syncOrchestrator;
	final ConfigRepository _configRepository;
	final CategoriaRepository? _categoriaRepository;
	final ClienteRepository? _clienteRepository;
	final DescuentoClienteRepository? _descuentoClienteRepository;
	final VendedorRepository? _vendedorRepository;
	final UsuarioRepository? _usuarioRepository;
	final ProveedorRepository? _proveedorRepository;
	final PrecioRepository? _precioRepository;
	final MovimientoInventarioRepository? _movimientoRepository;
	final TraspasoRepository? _traspasoRepository;
	final VarianteRepository? _varianteRepository;
	final ServicioCorteCaja? _servicioCorteCaja;
	final String _tenantId;
	final String _tiendaActivaId;
	final String _cajaId;
	final Uuid _generadorId = const Uuid();

	/// Identificador de la tienda activa en este dispositivo.
	String get tiendaActivaId => _tiendaActivaId;

	/// Identificador de caja del dispositivo.
	String get cajaId => _cajaId;

	/// Obtiene resumen de ventas del dia para todas las tiendas.
	///
	/// Retorna lista de resumenes por sucursal activa.
	Future<List<ResumenVentasDia>> obtenerResumenVentasDelDia() async {
		return obtenerResumenVentasPeriodo(dias: 1);
	}

	/// Obtiene resumen de ventas por periodo para todas las tiendas activas.
	///
	/// [dias] Dias hacia atras desde hoy (1 = solo hoy).
	Future<List<ResumenVentasDia>> obtenerResumenVentasPeriodo({required int dias}) async {
		final tiendas = await _tiendaRepository.listarActivas();
		final resumenes = <ResumenVentasDia>[];
		for (final tienda in tiendas) {
			final ventas = await listarVentasTiendaPeriodo(tienda.id, dias: dias);
			var total = 0.0;
			for (final venta in ventas) {
				total = total + venta.total;
			}
			resumenes.add(
				ResumenVentasDia(
					tiendaId: tienda.id,
					nombreTienda: tienda.nombre,
					totalVendido: redondearMonto(total),
					cantidadVentas: ventas.length,
				),
			);
		}
		return resumenes;
	}

	/// Lista ventas del dia de la tienda activa del dispositivo.
	///
	/// Retorna ventas ordenadas por hora descendente.
	Future<List<Venta>> listarVentasTiendaActiva() async {
		return _ventaRepository.listarVentasDelDia(_tiendaActivaId);
	}

	/// Lista productos activos de la tienda local.
	///
	/// Retorna catalogo para administracion.
	Future<List<Producto>> listarProductos() async {
		return _productoRepository.listarActivosPorTienda(_tiendaActivaId);
	}

	Future<List<Producto>> listarProductosActivosPorTienda(String tiendaId) async {
		return _productoRepository.listarActivosPorTienda(tiendaId);
	}

	/// Lista catalogo completo incluyendo inactivos (admin).
	Future<List<Producto>> listarProductosCatalogo() async {
		return _productoRepository.listarTodosPorTienda(_tiendaActivaId);
	}

	Future<Producto?> obtenerProducto(String productoId) async {
		return _productoRepository.obtenerPorId(productoId);
	}

	Future<List<EscalaMayoreo>> listarEscalasMayoreo(String productoId) async {
		return _precioRepository?.obtenerEscalasMayoreo(productoId) ?? [];
	}

	ModuloVertical _derivarModuloVertical(String categoriaId, UnidadMedida unidad) {
		if (categoriaId == ID_CAT_CARNICERIA) {
			return ModuloVertical.carniceria;
		}
		if (categoriaId == ID_CAT_FARMACIA) {
			return ModuloVertical.farmacia;
		}
		return ModuloVertical.general;
	}

	UnidadMedida _unidadPorCategoria(String categoriaId, UnidadMedida solicitada) {
		if (categoriaId == ID_CAT_CARNICERIA && solicitada == UnidadMedida.pieza) {
			return UnidadMedida.kilogramo;
		}
		return solicitada;
	}

	Future<Producto> registrarProductoCompleto(AltaProductoRequest req) async {
		if (req.categoriaId.isEmpty) {
			throw StateError('La categoria es obligatoria');
		}
		final unidad = _unidadPorCategoria(req.categoriaId, req.unidadMedida);
		final producto = Producto(
			id: _generadorId.v4(),
			nombre: req.nombre.trim(),
			codigoBarras: req.codigoBarras.trim(),
			precioBase: redondearMonto(req.precioBase),
			unidadMedida: unidad,
			rutaImagen: '',
			activo: req.activo,
			tiendaId: _tiendaActivaId,
			moduloVertical: _derivarModuloVertical(req.categoriaId, unidad),
			categoriaId: req.categoriaId,
			piezasPorCaja: req.piezasPorCaja,
			unidadesPorBulto: req.unidadesPorBulto,
			proveedorId: req.proveedorId,
			notas: req.notas.trim(),
			costoUnitario: redondearMonto(req.costoUnitario),
		);
		await _productoRepository.guardar(producto);
		final ahora = DateTime.now().toUtc();
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: producto.id,
				tiendaId: _tiendaActivaId,
				cantidad: req.stockInicial,
				actualizadoEn: ahora,
				stockMinimo: req.stockMinimo,
			),
		);
		if (req.escalasMayoreo.isNotEmpty && _precioRepository != null) {
			final escalas = req.escalasMayoreo
				.map(
					(e) => EscalaMayoreo(
						productoId: producto.id,
						cantidadMinima: e.cantidadMinima,
						precioUnitario: e.precioUnitario,
					),
				)
				.toList();
			await _precioRepository.reemplazarEscalasMayoreo(producto.id, escalas);
		}
		await _registrarEventoProducto(producto);
		return producto;
	}

	Future<Producto> actualizarProducto(
		Producto producto, {
		List<EscalaMayoreo>? escalasMayoreo,
	}) async {
		if (producto.categoriaId == null || producto.categoriaId!.isEmpty) {
			throw StateError('La categoria es obligatoria');
		}
		final unidad = _unidadPorCategoria(producto.categoriaId!, producto.unidadMedida);
		final actualizado = producto.copiarCon(
			moduloVertical: _derivarModuloVertical(producto.categoriaId!, unidad),
			unidadMedida: unidad,
			precioBase: redondearMonto(producto.precioBase),
		);
		await _productoRepository.guardar(actualizado);
		if (escalasMayoreo != null && _precioRepository != null) {
			await _precioRepository.reemplazarEscalasMayoreo(
				actualizado.id,
				escalasMayoreo
					.map(
						(e) => EscalaMayoreo(
							productoId: actualizado.id,
							cantidadMinima: e.cantidadMinima,
							precioUnitario: e.precioUnitario,
						),
					)
					.toList(),
			);
		}
		await _registrarEventoProducto(actualizado);
		return actualizado;
	}

	Future<bool> eliminarProducto(String productoId) async {
		if (await _productoTieneStock(productoId)) {
			return false;
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		await _productoRepository.guardar(producto.copiarCon(activo: false));
		await _registrarEventoProducto(producto.copiarCon(activo: false));
		return true;
	}

	Future<bool> reactivarProducto(String productoId) async {
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		final reactivado = producto.copiarCon(activo: true);
		await _productoRepository.guardar(reactivado);
		await _registrarEventoProducto(reactivado);
		return true;
	}

	Future<bool> eliminarProductoPermanente(String productoId) async {
		if (await _productoTieneStock(productoId)) {
			return false;
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		await _precioRepository?.eliminarEscalasPorProducto(productoId);
		await _precioRepository?.eliminarPreciosPorProducto(productoId);
		await _varianteRepository?.eliminarPorProductoPadre(productoId);
		await _inventarioRepository.eliminarStockPorProducto(productoId);
		await _productoRepository.eliminar(productoId);
		return true;
	}

	Future<bool> _productoTieneStock(String productoId) async {
		final tiendas = await _tiendaRepository.listarActivas();
		for (final tienda in tiendas) {
			final stock = await _inventarioRepository.obtenerStock(productoId, tienda.id);
			if ((stock?.cantidad ?? 0.0) > 0.0) {
				return true;
			}
		}
		return false;
	}

	Future<List<Producto>> listarProductosPorProveedor(String proveedorId) async {
		return _productoRepository.listarPorProveedor(_tiendaActivaId, proveedorId);
	}

	/// Registra producto nuevo en catalogo local (legacy simple).
	///
	/// [nombre] Nombre comercial del articulo.
	/// [codigoBarras] Codigo escaneable.
	/// [precioBase] Precio unitario en MXN.
	/// Retorna producto persistido.
	Future<Producto> registrarProducto({
		required String nombre,
		required String codigoBarras,
		required double precioBase,
	}) async {
		final producto = Producto(
			id: _generadorId.v4(),
			nombre: nombre,
			codigoBarras: codigoBarras,
			precioBase: redondearMonto(precioBase),
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: _tiendaActivaId,
		);
		await _productoRepository.guardar(producto);
		final ahora = DateTime.now().toUtc();
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: producto.id,
				tiendaId: _tiendaActivaId,
				cantidad: 0.0,
				actualizadoEn: ahora,
			),
		);
		await _registrarEventoProducto(producto);
		return producto;
	}

	/// Obtiene inventario consolidado de todas las tiendas activas.
	///
	/// Retorna lista de existencias por producto y sucursal.
	Future<List<StockPorTienda>> obtenerInventarioConsolidado() async {
		final tiendas = await _tiendaRepository.listarActivas();
		final productos = await _productoRepository.listarActivosPorTienda(_tiendaActivaId);
		final resultado = <StockPorTienda>[];
		for (final tienda in tiendas) {
			for (final producto in productos) {
				final stock = await _inventarioRepository.obtenerStock(
					producto.id,
					tienda.id,
				);
				resultado.add(
					StockPorTienda(
						productoId: producto.id,
						nombreProducto: producto.nombre,
						tiendaId: tienda.id,
						nombreTienda: tienda.nombre,
						cantidad: stock?.cantidad ?? 0.0,
						actualizadoEn: stock?.actualizadoEn ?? DateTime.fromMillisecondsSinceEpoch(0),
						stockMinimo: stock?.stockMinimo ?? 0.0,
					),
				);
			}
		}
		return resultado;
	}

	/// Agrupa existencias por producto con totales por tienda.
	Future<List<InventarioAgrupado>> obtenerInventarioAgrupado({
		String? tiendaReferenciaId,
	}) async {
		final tiendaRef = tiendaReferenciaId ?? _tiendaActivaId;
		final tiendas = await _tiendaRepository.listarActivas();
		final productosPorId = <String, Producto>{};
		for (final tienda in tiendas) {
			final productos = await _productoRepository.listarActivosPorTienda(tienda.id);
			for (final producto in productos) {
				productosPorId[producto.id] = producto;
			}
		}
		final agrupados = <InventarioAgrupado>[];
		for (final producto in productosPorId.values) {
			final porNombre = <String, double>{};
			final porTiendaId = <String, double>{};
			final minimosPorTiendaId = <String, double>{};
			for (final tienda in tiendas) {
				final stock = await _inventarioRepository.obtenerStock(
					producto.id,
					tienda.id,
				);
				porNombre[tienda.nombre] = stock?.cantidad ?? 0.0;
				porTiendaId[tienda.id] = stock?.cantidad ?? 0.0;
				minimosPorTiendaId[tienda.id] = stock?.stockMinimo ?? 0.0;
			}
			final referencia = await _inventarioRepository.obtenerStock(
				producto.id,
				tiendaRef,
			);
			agrupados.add(
				InventarioAgrupado(
					productoId: producto.id,
					nombreProducto: producto.nombre,
					existenciasPorTienda: porNombre,
					existenciasPorTiendaId: porTiendaId,
					stockMinimoPorTiendaId: minimosPorTiendaId,
					stockMinimoLocal: referencia?.stockMinimo ?? 0.0,
					cantidadLocal: referencia?.cantidad ?? 0.0,
				),
			);
		}
		agrupados.sort((a, b) => a.nombreProducto.compareTo(b.nombreProducto));
		return agrupados;
	}

	/// Obtiene estado actual de la cola de sincronizacion.
	///
	/// Retorna metricas para panel admin.
	Future<EstadoSyncAdmin> obtenerEstadoSync() async {
		final pendientes = await _syncEventRepository.obtenerPendientes();
		var conError = 0;
		for (final evento in pendientes) {
			if (evento.estado == EstadoSyncEvento.error) {
				conError = conError + 1;
			}
		}
		return EstadoSyncAdmin(
			eventosPendientes: pendientes.length,
			eventosConError: conError,
			hubConfigurado: _syncOrchestrator.tieneHubConfigurado(),
		);
	}

	/// Ejecuta ciclo completo de sincronizacion con el hub.
	///
	/// Retorna resultado con eventos enviados y recibidos.
	Future<ResultadoSync> sincronizarManual() async {
		return _syncOrchestrator.sincronizarCompleto();
	}

	/// Obtiene URL del hub configurada en el dispositivo.
	///
	/// Retorna URL activa o cadena vacia si no hay hub.
	Future<String> obtenerHubUrl() async {
		final url = await _configRepository.obtenerHubUrl();
		return url ?? '';
	}

	/// Guarda URL del hub central en configuracion local.
	///
	/// [url] URL base del API; vacia desactiva sync remoto.
	Future<void> guardarHubUrl(String url) async {
		await _configRepository.guardarHubUrl(url);
	}

	Future<String> obtenerHubApiKey() async {
		return await _configRepository.obtenerValor(CLAVE_CONFIG_HUB_API_KEY) ?? '';
	}

	Future<void> guardarHubApiKey(String clave) async {
		await _configRepository.guardarValor(CLAVE_CONFIG_HUB_API_KEY, clave.trim());
	}

	/// Verifica si el dispositivo ya paso por el asistente de instalacion tecnica.
	Future<bool> esInstalacionCompleta() async {
		if (await _configRepository.esInstalacionCompleta()) {
			return true;
		}
		final hub = await _configRepository.obtenerHubUrl();
		if (hub != null && hub.isNotEmpty) {
			await _configRepository.marcarInstalacionCompleta();
			return true;
		}
		return false;
	}

	/// Guarda hub y marca instalacion completada (el tenant se resuelve al login).
	Future<bool> completarInstalacionTecnico({
		String hubUrl = '',
		String hubApiKey = '',
		bool soloOffline = false,
	}) async {
		final usarHub = !soloOffline && hubUrl.trim().isNotEmpty;
		if (!usarHub) {
			await guardarHubUrl('');
			await guardarHubApiKey('');
		} else {
			await guardarHubUrl(hubUrl);
			await guardarHubApiKey(hubApiKey);
		}
		await _configRepository.marcarInstalacionCompleta();
		return usarHub;
	}

	/// Habilita de nuevo el asistente de instalacion (modo tecnico).
	Future<void> reiniciarInstalacionTecnica() async {
		await _configRepository.reiniciarInstalacion();
	}

	// --- Categorias ---

	Future<List<Categoria>> listarCategorias() async {
		return _categoriaRepository?.listarTodas() ?? [];
	}

	Future<Categoria> registrarCategoria({
		required String nombre,
		String icono = 'shopping_basket',
		String colorHex = '#4CAF50',
	}) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			throw StateError('Repositorio de categorias no configurado');
		}
		final existentes = await repo.listarTodas();
		final categoria = Categoria(
			id: _generadorId.v4(),
			nombre: nombre,
			icono: icono,
			colorHex: colorHex,
			orden: existentes.length,
			activa: true,
		);
		await repo.guardar(categoria);
		await _registrarEventoCategoria(categoria);
		return categoria;
	}

	Future<void> actualizarCategoria(Categoria categoria) async {
		await _categoriaRepository?.guardar(categoria);
		await _registrarEventoCategoria(categoria);
	}

	/// Reordena categorias segun lista de ids.
	Future<void> reordenarCategorias(List<String> idsOrdenados) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			return;
		}
		for (var i = 0; i < idsOrdenados.length; i++) {
			final todas = await repo.listarTodas();
			final categoria = todas.where((c) => c.id == idsOrdenados[i]).firstOrNull;
			if (categoria != null) {
				await repo.guardar(categoria.copiarCon(orden: i));
				await _registrarEventoCategoria(categoria.copiarCon(orden: i));
			}
		}
	}

	Future<void> eliminarCategoria(String categoriaId) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			throw StateError('Repositorio de categorias no configurado');
		}
		final todas = await repo.listarTodas();
		final categoria = todas.where((c) => c.id == categoriaId).firstOrNull;
		if (categoria == null) {
			return;
		}
		await repo.guardar(categoria.copiarCon(activa: false));
		await _registrarEventoCategoria(categoria.copiarCon(activa: false));
	}

	Future<Producto> asignarCategoriaProducto(
		Producto producto,
		String? categoriaId,
	) async {
		final actualizado = producto.copiarCon(categoriaId: categoriaId);
		await _productoRepository.guardar(actualizado);
		await _registrarEventoProducto(actualizado);
		return actualizado;
	}

	// --- Variantes ---

	Future<List<VarianteProducto>> listarVariantes(String productoPadreId) async {
		return _varianteRepository?.listarPorProductoPadre(productoPadreId) ?? [];
	}

	Future<VarianteProducto> registrarVariante({
		required String productoPadreId,
		required String nombre,
		required String sku,
		required String codigoBarras,
		required double precioBase,
	}) async {
		final repo = _varianteRepository;
		if (repo == null) {
			throw StateError('Repositorio de variantes no configurado');
		}
		final variante = VarianteProducto(
			id: _generadorId.v4(),
			productoPadreId: productoPadreId,
			nombre: nombre,
			sku: sku,
			codigoBarras: codigoBarras,
			precioBase: precioBase,
			activo: true,
		);
		await repo.guardar(variante);
		await _registrarEventoVariante(variante);
		return variante;
	}

	Future<void> actualizarVariante(VarianteProducto variante) async {
		await _varianteRepository?.guardar(variante);
		await _registrarEventoVariante(variante);
	}

	// --- Clientes ---

	Future<List<Cliente>> listarClientes() async {
		return _clienteRepository?.listarTodos() ?? [];
	}

	Future<Cliente> registrarCliente({
		required String nombre,
		bool creditoHabilitado = false,
	}) async {
		final repo = _clienteRepository;
		if (repo == null) {
			throw StateError('Repositorio de clientes no configurado');
		}
		final cliente = Cliente(
			id: _generadorId.v4(),
			nombre: nombre,
			listaPreciosId: null,
			creditoHabilitado: creditoHabilitado,
			activo: true,
		);
		await repo.guardar(cliente);
		await _registrarEventoCliente(cliente);
		return cliente;
	}

	Future<void> actualizarCliente(Cliente cliente) async {
		await _clienteRepository?.guardar(cliente);
		await _registrarEventoCliente(cliente);
	}

	Future<Cliente?> obtenerCliente(String clienteId) async {
		return _clienteRepository?.obtenerPorId(clienteId);
	}

	Future<List<Venta>> listarVentasCliente(String clienteId, {int dias = 90}) async {
		final hasta = DateTime.now().toUtc();
		final desde = hasta.subtract(Duration(days: dias));
		return _ventaRepository.listarConFiltro(
			FiltroVentas(
				tiendaId: _tiendaActivaId,
				desde: desde,
				hasta: hasta,
				clienteId: clienteId,
			),
		);
	}

	Future<ResumenCliente> obtenerResumenCliente(String clienteId) async {
		final ventas = await listarVentasCliente(clienteId, dias: 365);
		var total = 0.0;
		var cantidad = 0;
		DateTime? ultima;
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			cantidad = cantidad + 1;
			total = total + venta.total;
			if (ultima == null || venta.creadaEn.isAfter(ultima)) {
				ultima = venta.creadaEn;
			}
		}
		return ResumenCliente(
			clienteId: clienteId,
			cantidadVentas: cantidad,
			totalComprado: redondearMonto(total),
			ultimaCompraEn: ultima,
		);
	}

	// --- Descuentos de cliente ---

	Future<List<DescuentoCliente>> listarDescuentosCliente(String clienteId) async {
		return _descuentoClienteRepository?.listarPorCliente(clienteId) ?? [];
	}

	Future<DescuentoCliente> registrarDescuentoCliente({
		required String clienteId,
		required TipoDescuentoCliente tipo,
		required double valor,
		required CondicionDescuentoCliente condicion,
		String? productoId,
		double? umbral,
		String descripcion = '',
	}) async {
		final repo = _descuentoClienteRepository;
		if (repo == null) {
			throw StateError('Repositorio de descuentos no configurado');
		}
		_validarDescuentoCliente(
			tipo: tipo,
			valor: valor,
			condicion: condicion,
			productoId: productoId,
			umbral: umbral,
		);
		final descuento = DescuentoCliente(
			id: _generadorId.v4(),
			clienteId: clienteId,
			tipo: tipo,
			valor: valor,
			condicion: condicion,
			productoId: productoId,
			umbral: umbral,
			activo: true,
			descripcion: descripcion.trim(),
		);
		await repo.guardar(descuento);
		return descuento;
	}

	Future<void> actualizarDescuentoCliente(DescuentoCliente descuento) async {
		final repo = _descuentoClienteRepository;
		if (repo == null) {
			return;
		}
		_validarDescuentoCliente(
			tipo: descuento.tipo,
			valor: descuento.valor,
			condicion: descuento.condicion,
			productoId: descuento.productoId,
			umbral: descuento.umbral,
		);
		await repo.guardar(descuento);
	}

	Future<void> eliminarDescuentoCliente(String descuentoId) async {
		await _descuentoClienteRepository?.eliminar(descuentoId);
	}

	Future<List<PrecioClienteProducto>> listarPreciosEspecialesCliente(
		String clienteId,
	) async {
		return _precioRepository?.listarPreciosPorCliente(clienteId) ?? [];
	}

	Future<void> guardarPrecioEspecialCliente({
		required String clienteId,
		required String productoId,
		required double precioUnitario,
	}) async {
		final repo = _precioRepository;
		if (repo == null) {
			throw StateError('Repositorio de precios no configurado');
		}
		if (precioUnitario <= 0) {
			throw StateError('El precio debe ser mayor a cero');
		}
		await repo.guardarPrecioClienteProducto(
			PrecioClienteProducto(
				clienteId: clienteId,
				productoId: productoId,
				precioUnitario: precioUnitario,
			),
		);
	}

	Future<void> eliminarPrecioEspecialCliente(String clienteId, String productoId) async {
		await _precioRepository?.eliminarPrecioClienteProducto(clienteId, productoId);
	}

	void _validarDescuentoCliente({
		required TipoDescuentoCliente tipo,
		required double valor,
		required CondicionDescuentoCliente condicion,
		String? productoId,
		double? umbral,
	}) {
		if (valor <= 0) {
			throw StateError('El valor del descuento debe ser mayor a cero');
		}
		if ((tipo == TipoDescuentoCliente.porcentajeGeneral ||
				tipo == TipoDescuentoCliente.porcentajeProducto) &&
			valor > 100) {
			throw StateError('El porcentaje no puede superar 100');
		}
		if (tipo.esPorProducto && productoId == null) {
			throw StateError('Seleccione un producto');
		}
		if (condicion != CondicionDescuentoCliente.siempre && (umbral == null || umbral <= 0)) {
			throw StateError('Indique el umbral de la regla');
		}
		if (condicion == CondicionDescuentoCliente.cantidadMinima && tipo.esGeneral) {
			throw StateError('La cantidad minima aplica solo a descuentos por producto');
		}
		if (condicion == CondicionDescuentoCliente.montoTicketMinimo && tipo.esPorProducto) {
			throw StateError('El monto minimo aplica solo a descuentos generales');
		}
	}

	// --- Vendedores ---

	Future<List<Vendedor>> listarVendedores({Usuario? operador}) async {
		final repo = _vendedorRepository;
		if (repo == null) {
			return [];
		}
		if (operador == null || PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			return repo.listarTodos();
		}
		return repo.listarTodos(tiendaId: operador.tiendaId);
	}

	Future<Vendedor> registrarVendedor({
		required String nombre,
		String? tiendaId,
		Usuario? operador,
	}) async {
		final repo = _vendedorRepository;
		if (repo == null) {
			throw StateError('Repositorio de vendedores no configurado');
		}
		final tiendaDestino = _resolverTiendaOperacion(operador, tiendaId ?? operador?.tiendaId);
		final nombreLimpio = nombre.trim();
		if (nombreLimpio.isEmpty) {
			throw StateError('El nombre del vendedor es obligatorio');
		}
		final codigo = await repo.generarSiguienteCodigo();
		final vendedor = Vendedor(
			id: _generadorId.v4(),
			nombre: nombreLimpio,
			codigo: codigo,
			activo: true,
			tiendaId: tiendaDestino,
		);
		await repo.guardar(vendedor);
		return vendedor;
	}

	Future<void> actualizarVendedor(Vendedor vendedor, {Usuario? operador}) async {
		final repo = _vendedorRepository;
		if (repo == null) {
			return;
		}
		final existente = await repo.obtenerPorId(vendedor.id);
		if (existente == null) {
			return;
		}
		if (operador != null &&
			!PermisosUsuario.puedeGestionarTodasLasTiendas(operador) &&
			existente.tiendaId != operador.tiendaId) {
			throw StateError('Sin permiso para editar este vendedor');
		}
		await repo.guardar(
			vendedor.copiarCon(
				nombre: vendedor.nombre.trim(),
				codigo: existente.codigo,
				tiendaId: existente.tiendaId,
			),
		);
	}

	// --- Usuarios ---

	Future<Usuario?> autenticarUsuario(String codigo, String pin) async {
		return _usuarioRepository?.autenticar(codigo, pin);
	}

	/// Busca cuenta por codigo sin validar contrasena (paso previo al PIN).
	Future<Usuario?> buscarUsuarioPorCodigo(String codigo) async {
		return _usuarioRepository?.obtenerPorCodigo(codigo.trim());
	}

	/// Aplica tenant resuelto en login, tienda del usuario y sync inicial.
	Future<void> activarSesionTrasLogin(Usuario usuario, String tenantId) async {
		final tenantLimpio = tenantId.trim();
		if (tenantLimpio.isEmpty) {
			throw StateError('Tenant invalido');
		}
		await PosiaLocalDatabase.obtenerInstancia().establecerTenant(tenantLimpio);
		final config = await _configRepository.obtenerConfigDispositivo();
		if (config.tenantId != tenantLimpio) {
			await _configRepository.guardarConfigDispositivo(
				ConfigDispositivo(
					tenantId: tenantLimpio,
					tiendaId: config.tiendaId,
					cajaId: config.cajaId,
					nombreCaja: config.nombreCaja,
				),
			);
		}
		if (usuario.rol != RolUsuario.administrador) {
			final tiendaId = usuario.tiendaId;
			if (tiendaId == null || tiendaId.isEmpty) {
				throw StateError('Usuario sin tienda asignada');
			}
			await cambiarTiendaActiva(tiendaId);
		}
		final hub = await _configRepository.obtenerHubUrl();
		if (hub != null && hub.isNotEmpty) {
			await sincronizarManual();
		}
	}

	Future<Usuario?> autenticarUsuarioPorPin(String pin) async {
		return _usuarioRepository?.autenticarPorPin(pin);
	}

	Future<Usuario?> autenticarUsuarioPorPinYRol(String pin, RolUsuario rol) async {
		return _usuarioRepository?.autenticarPorPinYRol(pin, rol);
	}

	Future<List<Usuario>> listarUsuarios({Usuario? operador}) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			return [];
		}
		if (operador == null || PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			return repo.listarTodos();
		}
		final todos = await repo.listarTodos();
		return todos
			.where((u) => PermisosUsuario.puedeGestionarUsuario(operador, u))
			.toList();
	}

	Future<List<Tienda>> obtenerTiendasPermitidas({Usuario? operador}) async {
		final tiendas = await _tiendaRepository.listarActivas();
		if (operador == null || PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			return tiendas;
		}
		final asignada = operador.tiendaId;
		if (asignada == null) {
			return [];
		}
		return tiendas.where((t) => t.id == asignada).toList();
	}

	Future<Usuario> registrarUsuario({
		required String nombre,
		required RolUsuario rol,
		required String pin,
		String? tiendaId,
		Usuario? operador,
	}) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			throw StateError('Repositorio de usuarios no configurado');
		}
		if (operador != null && !PermisosUsuario.puedeGestionarUsuarios(operador)) {
			throw StateError('Sin permiso para crear usuarios');
		}
		final nombreLimpio = nombre.trim();
		if (nombreLimpio.isEmpty) {
			throw StateError('El nombre es obligatorio');
		}
		if (pin.trim().length != LONGITUD_PIN_ADMIN) {
			throw StateError('El PIN debe tener $LONGITUD_PIN_ADMIN digitos');
		}
		final tiendaDestino = _resolverTiendaOperacion(operador, tiendaId);
		if (rol != RolUsuario.administrador && tiendaDestino == null) {
			throw StateError('Debe asignar una tienda');
		}
		if (rol == RolUsuario.administrador && operador?.rol == RolUsuario.supervisor) {
			throw StateError('Sin permiso para crear administradores');
		}
		if (operador?.rol == RolUsuario.supervisor && rol != RolUsuario.empleado) {
			throw StateError('Los supervisores solo pueden crear empleados');
		}
		final activos = await repo.contarActivos();
		if (activos >= LIMITE_MAX_USUARIOS) {
			throw StateError('Limite de $LIMITE_MAX_USUARIOS cuentas activas alcanzado');
		}
		final codigo = await repo.generarSiguienteCodigo(rol);
		final usuario = Usuario(
			id: _generadorId.v4(),
			nombre: nombreLimpio,
			codigo: codigo,
			pin: pin.trim(),
			rol: rol,
			tiendaId: rol == RolUsuario.administrador ? null : tiendaDestino,
			activo: true,
		);
		if (operador != null && !PermisosUsuario.puedeGestionarUsuario(operador, usuario)) {
			throw StateError('Sin permiso para crear este usuario');
		}
		await repo.guardar(usuario);
		await _registrarEventoUsuario(usuario);
		return usuario;
	}

	Future<Usuario> actualizarUsuario(
		Usuario usuario, {
		Usuario? operador,
		String? nuevoPin,
	}) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			throw StateError('Repositorio de usuarios no configurado');
		}
		final existente = await repo.obtenerPorId(usuario.id);
		if (existente == null) {
			throw StateError('Usuario no encontrado');
		}
		if (operador != null && !PermisosUsuario.puedeGestionarUsuario(operador, existente)) {
			throw StateError('Sin permiso para editar este usuario');
		}
		final esPropiaCuenta = operador?.id == usuario.id;
		if (!esPropiaCuenta && operador?.rol == RolUsuario.empleado) {
			throw StateError('Sin permiso para editar otros usuarios');
		}
		if (operador?.id == usuario.id && !usuario.activo) {
			throw StateError('No puede desactivar su propia cuenta');
		}
		final nombreLimpio = usuario.nombre.trim();
		if (nombreLimpio.isEmpty) {
			throw StateError('El nombre es obligatorio');
		}

		var rolFinal = usuario.rol;
		var codigoFinal = existente.codigo;
		String? tiendaFinal;
		var limpiarTiendaId = false;

		if (esPropiaCuenta && operador?.rol == RolUsuario.empleado) {
			rolFinal = existente.rol;
			tiendaFinal = existente.tiendaId;
		} else {
			if (rolFinal != existente.rol) {
				_validarAsignacionRol(
					operador: operador,
					rolNuevo: rolFinal,
					rolAnterior: existente.rol,
				);
			}
			if (rolFinal != existente.rol) {
				codigoFinal = await repo.generarSiguienteCodigo(rolFinal);
			}
			if (rolFinal == RolUsuario.administrador) {
				tiendaFinal = null;
				limpiarTiendaId = true;
			} else {
				tiendaFinal = _resolverTiendaOperacion(operador, usuario.tiendaId);
				if (tiendaFinal == null) {
					throw StateError('Debe asignar una tienda');
				}
			}
		}

		final pinFinal = _resolverPinEnActualizacion(
			existente: existente,
			nuevoPin: nuevoPin,
			esPropiaCuenta: esPropiaCuenta,
		);

		final actualizado = existente.copiarCon(
			nombre: nombreLimpio,
			codigo: codigoFinal,
			pin: pinFinal,
			rol: rolFinal,
			activo: usuario.activo,
			tiendaId: tiendaFinal,
			limpiarTiendaId: limpiarTiendaId,
		);
		await repo.guardar(actualizado);
		await _registrarEventoUsuario(actualizado);
		return actualizado;
	}

	void _validarAsignacionRol({
		Usuario? operador,
		required RolUsuario rolNuevo,
		required RolUsuario rolAnterior,
	}) {
		if (operador?.rol != RolUsuario.supervisor) {
			return;
		}
		if (rolNuevo == RolUsuario.administrador || rolAnterior == RolUsuario.administrador) {
			throw StateError('Sin permiso para gestionar administradores');
		}
		if (rolNuevo != RolUsuario.empleado) {
			throw StateError('Los supervisores solo pueden asignar empleados');
		}
	}

	String? _resolverPinEnActualizacion({
		required Usuario existente,
		String? nuevoPin,
		required bool esPropiaCuenta,
	}) {
		if (nuevoPin == null || nuevoPin.trim().isEmpty) {
			return null;
		}
		if (nuevoPin.trim().length != LONGITUD_PIN_ADMIN) {
			throw StateError('El PIN debe tener $LONGITUD_PIN_ADMIN digitos');
		}
		if (esPropiaCuenta) {
			throw StateError('Use Mi cuenta para cambiar su PIN');
		}
		return nuevoPin.trim();
	}

	Future<void> cambiarPinUsuario({
		required String usuarioId,
		required String pinActual,
		required String pinNuevo,
		Usuario? operador,
	}) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			throw StateError('Repositorio de usuarios no configurado');
		}
		final existente = await repo.obtenerPorId(usuarioId);
		if (existente == null) {
			throw StateError('Usuario no encontrado');
		}
		final esPropiaCuenta = operador?.id == usuarioId;
		if (operador != null &&
			!esPropiaCuenta &&
			!PermisosUsuario.puedeGestionarUsuario(operador, existente)) {
			throw StateError('Sin permiso para cambiar el PIN');
		}
		if (esPropiaCuenta && !await repo.verificarPin(usuarioId, pinActual.trim())) {
			throw StateError('PIN actual incorrecto');
		}
		if (pinNuevo.trim().length != LONGITUD_PIN_ADMIN) {
			throw StateError('El PIN debe tener $LONGITUD_PIN_ADMIN digitos');
		}
		await repo.guardar(existente.copiarCon(pin: pinNuevo.trim()));
		await _registrarEventoUsuario(existente);
	}

	String? _resolverTiendaOperacion(Usuario? operador, String? tiendaId) {
		if (operador != null && !PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
			final asignada = operador.tiendaId;
			if (asignada == null) {
				throw StateError('Usuario sin tienda asignada');
			}
			if (tiendaId != null && tiendaId != asignada) {
				throw StateError('Sin permiso para esta tienda');
			}
			return asignada;
		}
		return tiendaId;
	}

	void _validarPermisoTienda(Usuario? operador, String tiendaId) {
		if (operador == null) {
			return;
		}
		if (!PermisosUsuario.puedeGestionarTienda(operador, tiendaId)) {
			throw StateError('Sin permiso para gestionar esta tienda');
		}
	}

	// --- Proveedores ---

	Future<List<Proveedor>> listarProveedores() async {
		return _proveedorRepository?.listarTodos() ?? [];
	}

	Future<Proveedor> registrarProveedor({
		required String nombre,
		String contacto = '',
		String telefono = '',
	}) async {
		final repo = _proveedorRepository;
		if (repo == null) {
			throw StateError('Repositorio de proveedores no configurado');
		}
		final proveedor = Proveedor(
			id: _generadorId.v4(),
			nombre: nombre,
			contacto: contacto,
			telefono: telefono,
			activo: true,
		);
		await repo.guardar(proveedor);
		return proveedor;
	}

	Future<void> actualizarProveedor(Proveedor proveedor) async {
		await _proveedorRepository?.guardar(proveedor);
	}

	Future<Proveedor?> obtenerProveedor(String proveedorId) async {
		return _proveedorRepository?.obtenerPorId(proveedorId);
	}

	Future<void> vincularProductoProveedor(String productoId, String? proveedorId) async {
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			throw StateError('Producto no encontrado');
		}
		await actualizarProducto(producto.copiarCon(proveedorId: proveedorId));
	}

	// --- Configuracion ---

	Future<String> obtenerPinAdmin() async {
		return await _configRepository.obtenerValor(CLAVE_CONFIG_PIN_ADMIN) ?? '';
	}

	Future<void> guardarPinAdmin(String pin) async {
		await _configRepository.guardarValor(CLAVE_CONFIG_PIN_ADMIN, pin);
	}

	Future<ConfigDispositivo> obtenerConfigDispositivo() async {
		return _configRepository.obtenerConfigDispositivo();
	}

	Future<void> guardarConfigDispositivo({
		required String tiendaId,
		String? nombreCaja,
		String? tenantId,
	}) async {
		final actual = await _configRepository.obtenerConfigDispositivo();
		await _configRepository.guardarConfigDispositivo(
			ConfigDispositivo(
				tenantId: tenantId ?? actual.tenantId,
				tiendaId: tiendaId,
				cajaId: actual.cajaId,
				nombreCaja: nombreCaja ?? actual.nombreCaja,
			),
		);
	}

	Future<ConfigImpresora> obtenerConfigImpresora() async {
		return _configRepository.obtenerConfigImpresora();
	}

	Future<void> guardarConfigImpresora(ConfigImpresora config) async {
		await _configRepository.guardarConfigImpresora(config);
	}

	Future<Tienda?> obtenerTiendaActiva() async {
		return _tiendaRepository.obtenerPorId(_tiendaActivaId);
	}

	FiltroVentas filtroVentasPeriodo({required int dias}) {
		return filtroVentasPeriodoTienda(_tiendaActivaId, dias: dias);
	}

	/// Filtro de ventas para reportes; [tiendaId] null = todas las tiendas.
	FiltroVentas filtroVentasReporte({required int dias, String? tiendaId}) {
		final hasta = DateTime.now().toUtc();
		final desde = hasta.subtract(Duration(days: dias));
		return FiltroVentas(
			tiendaId: tiendaId,
			desde: desde,
			hasta: hasta,
		);
	}

	/// Filtro de ventas para una tienda y periodo dados.
	FiltroVentas filtroVentasPeriodoTienda(String tiendaId, {required int dias}) {
		final hasta = DateTime.now().toUtc();
		final desde = hasta.subtract(Duration(days: dias));
		return FiltroVentas(
			tiendaId: tiendaId,
			desde: desde,
			hasta: hasta,
		);
	}

	// --- Historial y cancelaciones ---

	Future<List<Venta>> listarHistorialVentas(FiltroVentas filtro) async {
		return _ventaRepository.listarConFiltro(filtro);
	}

	Future<Venta?> obtenerVenta(String ventaId) async {
		return _ventaRepository.obtenerPorId(ventaId);
	}

	Future<bool> devolverLineasVenta(
		String ventaId,
		Map<String, double> cantidadesPorProducto,
	) async {
		final venta = await _ventaRepository.obtenerPorId(ventaId);
		if (venta == null || !venta.puedeDevolverseParcial()) {
			return false;
		}
		final ahora = DateTime.now().toUtc();
		var montoDevuelto = 0.0;
		final lineasDevueltas = <Map<String, Object?>>[];
		final lineasActualizadas = <LineaVenta>[];
		for (final linea in venta.lineas) {
			final devolver = cantidadesPorProducto[linea.productoId] ?? 0.0;
			if (devolver <= 0.0) {
				lineasActualizadas.add(linea);
				continue;
			}
			if (devolver > linea.cantidad) {
				return false;
			}
			montoDevuelto = montoDevuelto + (devolver * linea.precioUnitario);
			lineasDevueltas.add({
				'productoId': linea.productoId,
				'cantidadDevuelta': devolver,
			});
			final stock = await _inventarioRepository.obtenerStock(
				linea.productoId,
				venta.tiendaId,
			);
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: linea.productoId,
					tiendaId: venta.tiendaId,
					cantidad: (stock?.cantidad ?? 0.0) + devolver,
					actualizadoEn: ahora,
					stockMinimo: stock?.stockMinimo ?? 0.0,
				),
			);
			final restante = linea.cantidad - devolver;
			if (restante > 0.0) {
				lineasActualizadas.add(
					LineaVenta(
						productoId: linea.productoId,
						nombreProducto: linea.nombreProducto,
						cantidad: restante,
						precioUnitario: linea.precioUnitario,
						reglaPrecio: linea.reglaPrecio,
						loteId: linea.loteId,
						etiquetaLote: linea.etiquetaLote,
					),
				);
			}
		}
		if (lineasDevueltas.isEmpty) {
			return false;
		}
		final nuevoTotal = Venta.calcularTotalDesdeLineas(lineasActualizadas);
		final ventaActualizada = venta.copiarCon(
			lineas: lineasActualizadas,
			total: nuevoTotal,
			estado: lineasActualizadas.isEmpty
				? EstadoVenta.devuelta
				: EstadoVenta.completada,
		);
		await _ventaRepository.actualizarVenta(ventaActualizada);
		await _servicioCorteCaja?.registrarDevolucion(venta, montoDevuelto);
		await _registrarEventoDevolucionParcial(venta, lineasDevueltas, montoDevuelto);
		return true;
	}

	Future<bool> anularVenta(String ventaId) async {
		final venta = await _ventaRepository.obtenerPorId(ventaId);
		if (venta == null || !venta.puedeAnularse()) {
			return false;
		}
		final ahora = DateTime.now().toUtc();
		for (final linea in venta.lineas) {
			final stock = await _inventarioRepository.obtenerStock(
				linea.productoId,
				venta.tiendaId,
			);
			final cantidadNueva = (stock?.cantidad ?? 0.0) + linea.cantidad;
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: linea.productoId,
					tiendaId: venta.tiendaId,
					cantidad: cantidadNueva,
					actualizadoEn: ahora,
					stockMinimo: stock?.stockMinimo ?? 0.0,
				),
			);
		}
		await _ventaRepository.actualizarEstado(ventaId, EstadoVenta.cancelada);
		await _servicioCorteCaja?.registrarAnulacion(venta);
		await _registrarEventoAnulacion(venta);
		return true;
	}

	// --- Traspasos ---

	Future<List<Traspaso>> listarTraspasos() async {
		return _traspasoRepository?.listarTodos() ?? [];
	}

	Future<List<Tienda>> listarTiendasActivas() async {
		return _tiendaRepository.listarActivas();
	}

	Future<List<Tienda>> listarTodasLasTiendas() async {
		return _tiendaRepository.listarTodas();
	}

	/// Registra tienda nueva respetando limite de licencia.
	Future<Tienda> registrarTienda({
		required String nombre,
		required String direccion,
	}) async {
		final activas = await _tiendaRepository.contarActivas();
		if (activas >= LIMITE_MAX_TIENDAS) {
			throw StateError('Limite de $LIMITE_MAX_TIENDAS tiendas activas alcanzado');
		}
		final tienda = Tienda(
			id: _generadorId.v4(),
			nombre: nombre.trim(),
			direccion: direccion.trim(),
			activa: true,
		);
		await _tiendaRepository.guardar(tienda);
		await _registrarEventoTienda(tienda);
		return tienda;
	}

	Future<void> actualizarTienda(Tienda tienda) async {
		await _tiendaRepository.guardar(tienda);
		await _registrarEventoTienda(tienda);
	}

	Future<void> desactivarTienda(String tiendaId) async {
		final tienda = await _tiendaRepository.obtenerPorId(tiendaId);
		if (tienda == null) {
			return;
		}
		final inactiva = Tienda(
			id: tienda.id,
			nombre: tienda.nombre,
			direccion: tienda.direccion,
			activa: false,
		);
		await _tiendaRepository.guardar(inactiva);
		await _registrarEventoTienda(inactiva);
	}

	Future<bool> eliminarTienda(String tiendaId) async {
		if (tiendaId == _tiendaActivaId) {
			return false;
		}
		final ventas = await _ventaRepository.listarVentasDelDia(tiendaId);
		if (ventas.isNotEmpty) {
			return false;
		}
		await _tiendaRepository.eliminar(tiendaId);
		return true;
	}

	Future<List<Venta>> listarVentasDelDiaTienda(String tiendaId) async {
		return listarVentasTiendaPeriodo(tiendaId, dias: 1);
	}

	/// Lista ventas de una tienda en los ultimos [dias] dias.
	Future<List<Venta>> listarVentasTiendaPeriodo(String tiendaId, {required int dias}) async {
		return _ventaRepository.listarConFiltro(filtroVentasPeriodoTienda(tiendaId, dias: dias));
	}

	Future<bool> eliminarVenta(String ventaId) async {
		final venta = await _ventaRepository.obtenerPorId(ventaId);
		if (venta == null) {
			return false;
		}
		if (venta.estado == EstadoVenta.completada) {
			final ahora = DateTime.now().toUtc();
			for (final linea in venta.lineas) {
				final stock = await _inventarioRepository.obtenerStock(
					linea.productoId,
					venta.tiendaId,
				);
				await _inventarioRepository.guardarStock(
					StockNivel(
						productoId: linea.productoId,
						tiendaId: venta.tiendaId,
						cantidad: (stock?.cantidad ?? 0.0) + linea.cantidad,
						actualizadoEn: ahora,
						stockMinimo: stock?.stockMinimo ?? 0.0,
					),
				);
			}
			await _servicioCorteCaja?.registrarAnulacion(venta);
		}
		await _ventaRepository.eliminar(ventaId);
		return true;
	}

	Future<void> cambiarTiendaActiva(String tiendaId) async {
		final config = await _configRepository.obtenerConfigDispositivo();
		await _configRepository.guardarConfigDispositivo(
			ConfigDispositivo(
				tenantId: config.tenantId,
				tiendaId: tiendaId,
				cajaId: config.cajaId,
				nombreCaja: config.nombreCaja,
			),
		);
	}

	Future<Traspaso> realizarTraspaso({
		required String tiendaOrigenId,
		required String tiendaDestinoId,
		required String productoId,
		required double cantidad,
		String notas = '',
		Usuario? operador,
	}) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			throw StateError('Repositorio de traspasos no configurado');
		}
		if (tiendaOrigenId == tiendaDestinoId) {
			throw StateError('Origen y destino deben ser tiendas distintas');
		}
		if (cantidad <= 0) {
			throw StateError('La cantidad debe ser mayor a cero');
		}
		_validarPermisoTienda(operador, tiendaOrigenId);
		_validarPermisoTienda(operador, tiendaDestinoId);

		final producto = await _productoRepository.obtenerPorId(productoId) ??
			(await _productoRepository.listarActivosPorTienda(tiendaOrigenId))
				.where((p) => p.id == productoId)
				.firstOrNull;
		if (producto == null) {
			throw StateError('Producto no encontrado');
		}

		final stockOrigen = await _inventarioRepository.obtenerStock(productoId, tiendaOrigenId);
		final anteriorOrigen = stockOrigen?.cantidad ?? 0.0;
		if (anteriorOrigen < cantidad) {
			throw StateError('Stock insuficiente en tienda origen');
		}

		final ahora = DateTime.now().toUtc();
		final nuevoOrigen = anteriorOrigen - cantidad;
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaOrigenId,
				cantidad: nuevoOrigen,
				actualizadoEn: ahora,
				stockMinimo: stockOrigen?.stockMinimo ?? 0.0,
			),
		);

		final stockDestino = await _inventarioRepository.obtenerStock(productoId, tiendaDestinoId);
		final anteriorDestino = stockDestino?.cantidad ?? 0.0;
		final nuevoDestino = anteriorDestino + cantidad;
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaDestinoId,
				cantidad: nuevoDestino,
				actualizadoEn: ahora,
				stockMinimo: stockDestino?.stockMinimo ?? 0.0,
			),
		);

		await _registrarAuditoriaInventario(
			productoId: productoId,
			tiendaId: tiendaOrigenId,
			tipo: TipoMovimientoInventario.traspasoSalida,
			cantidad: cantidad,
			cantidadAnterior: anteriorOrigen,
			cantidadNueva: nuevoOrigen,
			motivo: 'Traspaso enviado',
			operadorId: operador?.id,
			creadoEn: ahora,
		);
		await _registrarAuditoriaInventario(
			productoId: productoId,
			tiendaId: tiendaDestinoId,
			tipo: TipoMovimientoInventario.traspasoEntrada,
			cantidad: cantidad,
			cantidadAnterior: anteriorDestino,
			cantidadNueva: nuevoDestino,
			motivo: 'Traspaso recibido',
			operadorId: operador?.id,
			creadoEn: ahora,
		);

		final traspaso = Traspaso(
			id: _generadorId.v4(),
			tiendaOrigenId: tiendaOrigenId,
			tiendaDestinoId: tiendaDestinoId,
			estado: EstadoTraspaso.completado,
			solicitadoEn: ahora,
			completadoEn: ahora,
			notas: notas,
			lineas: [
				LineaTraspaso(
					productoId: productoId,
					nombreProducto: producto.nombre,
					cantidadSolicitada: cantidad,
					cantidadRecibida: cantidad,
				),
			],
		);
		await repo.guardar(traspaso);
		await _registrarEventoTraspaso(traspaso, TipoSyncEvento.transferCompleted);
		return traspaso;
	}

	/// Compatibilidad: delega en [realizarTraspaso] usando la tienda activa del dispositivo.
	Future<Traspaso> solicitarTraspaso({
		required String tiendaDestinoId,
		required String productoId,
		required double cantidad,
		String notas = '',
	}) {
		return realizarTraspaso(
			tiendaOrigenId: _tiendaActivaId,
			tiendaDestinoId: tiendaDestinoId,
			productoId: productoId,
			cantidad: cantidad,
			notas: notas,
		);
	}

	/// Completa traspasos antiguos en transito (flujo de dos pasos).
	Future<bool> recibirTraspaso(String traspasoId) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return false;
		}
		final traspaso = await repo.obtenerPorId(traspasoId);
		if (traspaso == null || traspaso.estado == EstadoTraspaso.completado) {
			return false;
		}
		if (traspaso.estado != EstadoTraspaso.enTransito) {
			return false;
		}
		if (traspaso.tiendaDestinoId != _tiendaActivaId) {
			return false;
		}
		final ahora = DateTime.now().toUtc();
		final lineasRecibidas = <LineaTraspaso>[];
		for (final linea in traspaso.lineas) {
			final stock = await _inventarioRepository.obtenerStock(
				linea.productoId,
				_tiendaActivaId,
			);
			final anterior = stock?.cantidad ?? 0.0;
			final cantidadNueva = anterior + linea.cantidadSolicitada;
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: linea.productoId,
					tiendaId: _tiendaActivaId,
					cantidad: cantidadNueva,
					actualizadoEn: ahora,
					stockMinimo: stock?.stockMinimo ?? 0.0,
				),
			);
			await _registrarAuditoriaInventario(
				productoId: linea.productoId,
				tiendaId: _tiendaActivaId,
				tipo: TipoMovimientoInventario.traspasoEntrada,
				cantidad: linea.cantidadSolicitada,
				cantidadAnterior: anterior,
				cantidadNueva: cantidadNueva,
				motivo: 'Traspaso recibido',
				creadoEn: ahora,
			);
			lineasRecibidas.add(
				LineaTraspaso(
					productoId: linea.productoId,
					nombreProducto: linea.nombreProducto,
					cantidadSolicitada: linea.cantidadSolicitada,
					cantidadRecibida: linea.cantidadSolicitada,
				),
			);
		}
		final completado = Traspaso(
			id: traspaso.id,
			tiendaOrigenId: traspaso.tiendaOrigenId,
			tiendaDestinoId: traspaso.tiendaDestinoId,
			estado: EstadoTraspaso.completado,
			solicitadoEn: traspaso.solicitadoEn,
			completadoEn: ahora,
			notas: traspaso.notas,
			lineas: lineasRecibidas,
		);
		await repo.guardar(completado);
		await _registrarEventoTraspaso(completado, TipoSyncEvento.transferCompleted);
		return true;
	}

	Future<void> _registrarAuditoriaInventario({
		required String productoId,
		required String tiendaId,
		required TipoMovimientoInventario tipo,
		required double cantidad,
		required double cantidadAnterior,
		required double cantidadNueva,
		required String motivo,
		required DateTime creadoEn,
		String? operadorId,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			return;
		}
		await repo.guardar(
			MovimientoInventario(
				id: _generadorId.v4(),
				productoId: productoId,
				tiendaId: tiendaId,
				tipo: tipo,
				cantidad: cantidad,
				cantidadAnterior: cantidadAnterior,
				cantidadNueva: cantidadNueva,
				motivo: motivo,
				referenciaId: null,
				proveedorId: null,
				creadoEn: creadoEn,
				creadoPor: operadorId,
			),
		);
	}

	// --- Corte de caja ---

	ServicioCorteCaja? obtenerServicioCorteCaja() => _servicioCorteCaja;

	// --- Inventario: movimientos y alertas ---

	Future<void> registrarMovimientoInventario({
		required String productoId,
		required TipoMovimientoInventario tipo,
		required double cantidad,
		required String motivo,
		String? proveedorId,
		String? tiendaId,
		Usuario? operador,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			throw StateError('Repositorio de movimientos no configurado');
		}
		final tiendaDestino = tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, tiendaDestino);
		final motivoLimpio = motivo.trim();
		if (!esMotivoInventarioValido(tipo, motivoLimpio)) {
			throw StateError('Seleccione un motivo válido del catálogo');
		}
		final stockActual = await _inventarioRepository.obtenerStock(
			productoId,
			tiendaDestino,
		);
		final anterior = stockActual?.cantidad ?? 0.0;
		double nuevo;
		double delta;
		if (tipo == TipoMovimientoInventario.ajuste) {
			nuevo = cantidad;
			delta = nuevo - anterior;
		} else if (tipo == TipoMovimientoInventario.salida) {
			if (anterior < cantidad) {
				throw StateError('Stock insuficiente');
			}
			nuevo = anterior - cantidad;
			delta = -cantidad;
		} else {
			nuevo = anterior + cantidad;
			delta = cantidad;
		}
		final ahora = DateTime.now().toUtc();
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaDestino,
				cantidad: nuevo,
				actualizadoEn: ahora,
				stockMinimo: stockActual?.stockMinimo ?? 0.0,
			),
		);
		await _registrarEventoAjusteStock(productoId, delta, motivoLimpio);
		await repo.guardar(
			MovimientoInventario(
				id: _generadorId.v4(),
				productoId: productoId,
				tiendaId: tiendaDestino,
				tipo: tipo,
				cantidad: cantidad,
				cantidadAnterior: anterior,
				cantidadNueva: nuevo,
				motivo: motivoLimpio,
				referenciaId: null,
				proveedorId: proveedorId,
				creadoEn: ahora,
				creadoPor: operador?.id,
			),
		);
	}

	Future<List<MovimientoInventario>> listarMovimientosInventario({
		String? tiendaId,
		Usuario? operador,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			return [];
		}
		final tiendaDestino = tiendaId ?? operador?.tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, tiendaDestino);
		return repo.listarPorTienda(tiendaDestino);
	}

	Future<void> configurarStockMinimo(
		String productoId,
		double stockMinimo, {
		String? tiendaId,
		Usuario? operador,
	}) async {
		final tiendaDestino = tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, tiendaDestino);
		final stock = await _inventarioRepository.obtenerStock(
			productoId,
			tiendaDestino,
		);
		if (stock == null) {
			final ahora = DateTime.now().toUtc();
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: productoId,
					tiendaId: tiendaDestino,
					cantidad: 0.0,
					actualizadoEn: ahora,
					stockMinimo: stockMinimo,
				),
			);
			return;
		}
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaDestino,
				cantidad: stock.cantidad,
				actualizadoEn: stock.actualizadoEn,
				stockMinimo: stockMinimo,
			),
		);
	}

	Future<List<AlertaFaltante>> obtenerAlertasFaltantes({String? tiendaId}) async {
		final tiendas = await _tiendaRepository.listarActivas();
		final ids = tiendaId != null
			? [tiendaId]
			: tiendas.map((t) => t.id).toList();
		final alertas = <AlertaFaltante>[];
		for (final id in ids) {
			final bajoMinimo = await _inventarioRepository.listarBajoMinimo(id);
			final productos = await _productoRepository.listarActivosPorTienda(id);
			final nombres = {for (final p in productos) p.id: p.nombre};
			alertas.addAll(
				bajoMinimo.map(
					(stock) => AlertaFaltante(
						productoId: stock.productoId,
						nombreProducto: nombres[stock.productoId] ?? stock.productoId,
						cantidadActual: stock.cantidad,
						stockMinimo: stock.stockMinimo,
						tiendaId: stock.tiendaId,
					),
				),
			);
		}
		alertas.sort((a, b) => a.cantidadActual.compareTo(b.cantidadActual));
		return alertas;
	}

	// --- Reportes ---

	Future<List<ResumenVendedor>> obtenerResumenPorVendedor(
		FiltroVentas filtro,
	) async {
		final ventas = await _ventaRepository.listarConFiltro(filtro);
		final vendedores = await listarVendedores();
		final nombres = {for (final v in vendedores) v.id: v.nombre};
		final acumulado = <String, ResumenVendedor>{};
		for (final venta in ventas) {
			if (venta.estado != EstadoVenta.completada) {
				continue;
			}
			final vendedorId = venta.vendedorId ?? 'sin-vendedor';
			final previo = acumulado[vendedorId];
			acumulado[vendedorId] = ResumenVendedor(
				vendedorId: vendedorId,
				nombreVendedor: nombres[vendedorId] ?? 'Sin vendedor',
				cantidadVentas: (previo?.cantidadVentas ?? 0) + 1,
				totalVendido: redondearMonto((previo?.totalVendido ?? 0.0) + venta.total),
			);
		}
		final lista = acumulado.values.toList()
			..sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
		return lista;
	}

	Future<List<ResumenProductoVenta>> obtenerResumenPorProducto(
		FiltroVentas filtro,
	) async {
		return _ventaRepository.resumenPorProducto(filtro);
	}

	Future<List<ResumenVentasHora>> obtenerResumenPorHora(FiltroVentas filtro) async {
		return _ventaRepository.resumenPorHora(filtro);
	}

	Future<Map<MetodoPago, double>> obtenerTotalesPorMetodoPago(
		FiltroVentas filtro,
	) async {
		return _ventaRepository.totalesPorMetodoPago(filtro);
	}

	Future<List<ListaPrecios>> listarListasPrecios() async {
		return _precioRepository?.listarTodasListas() ?? [];
	}

	Future<ListaPrecios> registrarListaPrecios(String nombre) async {
		final repo = _precioRepository;
		if (repo == null) {
			throw StateError('Repositorio de precios no disponible');
		}
		final lista = ListaPrecios(
			id: _generadorId.v4(),
			nombre: nombre.trim(),
		);
		await repo.guardarLista(lista);
		return lista;
	}

	Future<void> guardarPrecioLista(
		String listaId,
		String productoId,
		double precio,
	) async {
		await _precioRepository?.guardarPrecioLista(listaId, productoId, precio);
	}

	Future<void> eliminarListaPrecios(String listaId) async {
		await _precioRepository?.eliminarLista(listaId);
	}

	Future<void> establecerFavoritoProducto(String productoId, bool favorito) async {
		await _productoRepository.establecerFavoritoCaja(productoId, favorito);
	}

	Future<void> _registrarEventoCategoria(Categoria categoria) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
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
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoCliente(Cliente cliente) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
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
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoAnulacion(Venta venta) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
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
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoTraspaso(Traspaso traspaso, TipoSyncEvento tipo) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
			tiendaId: _tiendaActivaId,
			dispositivoId: _cajaId,
			tipo: tipo,
			payload: {
				'traspasoId': traspaso.id,
				'tiendaOrigenId': traspaso.tiendaOrigenId,
				'tiendaDestinoId': traspaso.tiendaDestinoId,
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
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoVariante(VarianteProducto variante) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
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
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoAjusteStock(
		String productoId,
		double delta,
		String motivo,
	) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
			tiendaId: _tiendaActivaId,
			dispositivoId: _cajaId,
			tipo: TipoSyncEvento.stockAdjusted,
			payload: {
				'productoId': productoId,
				'delta': delta,
				'motivo': motivo,
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoDevolucionParcial(
		Venta venta,
		List<Map<String, Object?>> lineas,
		double montoDevuelto,
	) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
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
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoTienda(Tienda tienda) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
			tiendaId: _tiendaActivaId,
			dispositivoId: _cajaId,
			tipo: TipoSyncEvento.storeUpserted,
			payload: {
				'id': tienda.id,
				'nombre': tienda.nombre,
				'direccion': tienda.direccion,
				'activa': tienda.activa,
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	Future<void> _registrarEventoUsuario(Usuario usuario) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			return;
		}
		final snapshot = await repo.obtenerSnapshotSync(usuario.id);
		if (snapshot == null) {
			return;
		}
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
			tiendaId: _tiendaActivaId,
			dispositivoId: _cajaId,
			tipo: TipoSyncEvento.userUpserted,
			payload: {
				'id': usuario.id,
				'nombre': usuario.nombre,
				'codigo': usuario.codigo,
				'rol': usuario.rol.name,
				'tiendaId': usuario.tiendaId,
				'activo': usuario.activo,
				'pinHash': snapshot.pinHash,
				'pinSalt': snapshot.pinSalt,
				'creadoEn': snapshot.creadoEn,
				'actualizadoEn': snapshot.actualizadoEn,
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _syncOrchestrator.registrarEvento(evento);
	}

	/// Encola evento productUpserted para replicar catalogo.
	///
	/// [producto] Producto recien guardado.
	Future<void> _registrarEventoProducto(Producto producto) async {
		final evento = SyncEvent(
			id: _generadorId.v4(),
			tenantId: _tenantId,
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
			},
			creadoEn: DateTime.now().toUtc(),
			estado: EstadoSyncEvento.pendiente,
		);
		await _syncOrchestrator.registrarEvento(evento);
	}
}
