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
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/sync_event_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
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
		VendedorRepository? vendedorRepository,
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
	     _vendedorRepository = vendedorRepository,
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
	final VendedorRepository? _vendedorRepository;
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
		final tiendas = await _tiendaRepository.listarActivas();
		final resumenes = <ResumenVentasDia>[];
		for (final tienda in tiendas) {
			final ventas = await _ventaRepository.listarVentasDelDia(tienda.id);
			final total = await _ventaRepository.calcularTotalDelDia(tienda.id);
			resumenes.add(
				ResumenVentasDia(
					tiendaId: tienda.id,
					nombreTienda: tienda.nombre,
					totalVendido: total,
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
		final tiendas = await _tiendaRepository.listarActivas();
		for (final tienda in tiendas) {
			final stock = await _inventarioRepository.obtenerStock(productoId, tienda.id);
			if ((stock?.cantidad ?? 0.0) > 0.0) {
				return false;
			}
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		await _productoRepository.guardar(producto.copiarCon(activo: false));
		await _registrarEventoProducto(producto.copiarCon(activo: false));
		return true;
	}

	Future<bool> eliminarProductoPermanente(String productoId) async {
		final tiendas = await _tiendaRepository.listarActivas();
		for (final tienda in tiendas) {
			final stock = await _inventarioRepository.obtenerStock(productoId, tienda.id);
			if ((stock?.cantidad ?? 0.0) > 0.0) {
				return false;
			}
		}
		await _precioRepository?.eliminarEscalasPorProducto(productoId);
		await _productoRepository.eliminar(productoId);
		return true;
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
	Future<List<InventarioAgrupado>> obtenerInventarioAgrupado() async {
		final tiendas = await _tiendaRepository.listarActivas();
		final productos = await _productoRepository.listarActivosPorTienda(_tiendaActivaId);
		final agrupados = <InventarioAgrupado>[];
		for (final producto in productos) {
			final porTienda = <String, double>{};
			for (final tienda in tiendas) {
				final stock = await _inventarioRepository.obtenerStock(
					producto.id,
					tienda.id,
				);
				porTienda[tienda.nombre] = stock?.cantidad ?? 0.0;
			}
			final local = await _inventarioRepository.obtenerStock(
				producto.id,
				_tiendaActivaId,
			);
			agrupados.add(
				InventarioAgrupado(
					productoId: producto.id,
					nombreProducto: producto.nombre,
					existenciasPorTienda: porTienda,
					stockMinimoLocal: local?.stockMinimo ?? 0.0,
					cantidadLocal: local?.cantidad ?? 0.0,
				),
			);
		}
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

	// --- Vendedores ---

	Future<List<Vendedor>> listarVendedores() async {
		return _vendedorRepository?.listarTodos() ?? [];
	}

	Future<Vendedor> registrarVendedor({
		required String nombre,
		required String codigo,
	}) async {
		final repo = _vendedorRepository;
		if (repo == null) {
			throw StateError('Repositorio de vendedores no configurado');
		}
		final vendedor = Vendedor(
			id: _generadorId.v4(),
			nombre: nombre,
			codigo: codigo,
			activo: true,
		);
		await repo.guardar(vendedor);
		return vendedor;
	}

	Future<void> actualizarVendedor(Vendedor vendedor) async {
		await _vendedorRepository?.guardar(vendedor);
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
		final pin = await _configRepository.obtenerValor(CLAVE_CONFIG_PIN_ADMIN);
		if (pin == null || pin.isEmpty) {
			return PIN_ADMIN_DEMO;
		}
		return pin;
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
		final hasta = DateTime.now().toUtc();
		final desde = hasta.subtract(Duration(days: dias));
		return FiltroVentas(
			tiendaId: _tiendaActivaId,
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
		return tienda;
	}

	Future<void> actualizarTienda(Tienda tienda) async {
		await _tiendaRepository.guardar(tienda);
	}

	Future<void> desactivarTienda(String tiendaId) async {
		final tienda = await _tiendaRepository.obtenerPorId(tiendaId);
		if (tienda == null) {
			return;
		}
		await _tiendaRepository.guardar(
			Tienda(
				id: tienda.id,
				nombre: tienda.nombre,
				direccion: tienda.direccion,
				activa: false,
			),
		);
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
		return _ventaRepository.listarVentasDelDia(tiendaId);
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

	Future<Traspaso> solicitarTraspaso({
		required String tiendaDestinoId,
		required String productoId,
		required double cantidad,
		String notas = '',
	}) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			throw StateError('Repositorio de traspasos no configurado');
		}
		final producto = (await _productoRepository.listarActivosPorTienda(_tiendaActivaId))
			.where((p) => p.id == productoId)
			.firstOrNull;
		if (producto == null) {
			throw StateError('Producto no encontrado');
		}
		final stock = await _inventarioRepository.obtenerStock(productoId, _tiendaActivaId);
		if ((stock?.cantidad ?? 0.0) < cantidad) {
			throw StateError('Stock insuficiente en tienda origen');
		}
		final ahora = DateTime.now().toUtc();
		final cantidadNueva = (stock?.cantidad ?? 0.0) - cantidad;
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: _tiendaActivaId,
				cantidad: cantidadNueva,
				actualizadoEn: ahora,
				stockMinimo: stock?.stockMinimo ?? 0.0,
			),
		);
		final traspaso = Traspaso(
			id: _generadorId.v4(),
			tiendaOrigenId: _tiendaActivaId,
			tiendaDestinoId: tiendaDestinoId,
			estado: EstadoTraspaso.enTransito,
			solicitadoEn: ahora,
			completadoEn: null,
			notas: notas,
			lineas: [
				LineaTraspaso(
					productoId: productoId,
					nombreProducto: producto.nombre,
					cantidadSolicitada: cantidad,
				),
			],
		);
		await repo.guardar(traspaso);
		await _registrarEventoTraspaso(traspaso, TipoSyncEvento.transferRequested);
		return traspaso;
	}

	Future<bool> recibirTraspaso(String traspasoId) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return false;
		}
		final traspaso = await repo.obtenerPorId(traspasoId);
		if (traspaso == null || traspaso.estado == EstadoTraspaso.completado) {
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
			final cantidadNueva = (stock?.cantidad ?? 0.0) + linea.cantidadSolicitada;
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: linea.productoId,
					tiendaId: _tiendaActivaId,
					cantidad: cantidadNueva,
					actualizadoEn: ahora,
					stockMinimo: stock?.stockMinimo ?? 0.0,
				),
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

	// --- Corte de caja ---

	ServicioCorteCaja? obtenerServicioCorteCaja() => _servicioCorteCaja;

	// --- Inventario: movimientos y alertas ---

	Future<void> registrarMovimientoInventario({
		required String productoId,
		required TipoMovimientoInventario tipo,
		required double cantidad,
		required String motivo,
		String? proveedorId,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			throw StateError('Repositorio de movimientos no configurado');
		}
		final stockActual = await _inventarioRepository.obtenerStock(
			productoId,
			_tiendaActivaId,
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
				tiendaId: _tiendaActivaId,
				cantidad: nuevo,
				actualizadoEn: ahora,
				stockMinimo: stockActual?.stockMinimo ?? 0.0,
			),
		);
		await _registrarEventoAjusteStock(productoId, delta, motivo);
		await repo.guardar(
			MovimientoInventario(
				id: _generadorId.v4(),
				productoId: productoId,
				tiendaId: _tiendaActivaId,
				tipo: tipo,
				cantidad: cantidad,
				cantidadAnterior: anterior,
				cantidadNueva: nuevo,
				motivo: motivo,
				referenciaId: null,
				proveedorId: proveedorId,
				creadoEn: ahora,
				creadoPor: null,
			),
		);
	}

	Future<List<MovimientoInventario>> listarMovimientosInventario() async {
		return _movimientoRepository?.listarPorTienda(_tiendaActivaId) ?? [];
	}

	Future<void> configurarStockMinimo(
		String productoId,
		double stockMinimo,
	) async {
		final stock = await _inventarioRepository.obtenerStock(
			productoId,
			_tiendaActivaId,
		);
		if (stock == null) {
			return;
		}
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: _tiendaActivaId,
				cantidad: stock.cantidad,
				actualizadoEn: stock.actualizadoEn,
				stockMinimo: stockMinimo,
			),
		);
	}

	Future<List<AlertaFaltante>> obtenerAlertasFaltantes() async {
		final bajoMinimo = await _inventarioRepository.listarBajoMinimo(_tiendaActivaId);
		final productos = await _productoRepository.listarActivosPorTienda(_tiendaActivaId);
		final nombres = {for (final p in productos) p.id: p.nombre};
		return bajoMinimo
			.map(
				(stock) => AlertaFaltante(
					productoId: stock.productoId,
					nombreProducto: nombres[stock.productoId] ?? stock.productoId,
					cantidadActual: stock.cantidad,
					stockMinimo: stock.stockMinimo,
					tiendaId: stock.tiendaId,
				),
			)
			.toList();
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
		return acumulado.values.toList();
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
