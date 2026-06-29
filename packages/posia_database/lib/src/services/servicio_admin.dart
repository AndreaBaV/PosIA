/// Servicio de administracion: reportes, catalogo e inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'dart:convert';

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/alta_producto_request.dart';
import '../models/alerta_faltante.dart';
import '../models/config_dispositivo.dart';
import '../models/config_impresora.dart';
import '../models/estado_sync_admin.dart';
import '../models/linea_compra_solicitud.dart';
import '../models/linea_pedido_solicitud.dart';
import '../models/linea_traspaso_solicitud.dart';
import '../models/item_lista_precios.dart';
import '../models/resumen_precios_producto.dart';
import '../models/resumen_vendedor.dart';
import '../models/resumen_ventas_dia.dart';
import '../models/stock_por_tienda.dart';
import '../models/stock_por_almacen.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/compra_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/pedido_repository.dart';
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
import '../repositories/almacen_repository.dart';
import '../repositories/presentacion_repository.dart';
import '../repositories/sync_state_repository.dart';
import '../utils/limpiador_base_local.dart';
import '../utils/sincronizador_vendedor_usuario.dart';
import '../models/resultado_reconciliacion_hub.dart';
import '../services/servicio_reconciliacion_hub.dart';
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
		CompraRepository? compraRepository,
		PedidoRepository? pedidoRepository,
		CotizacionRepository? cotizacionRepository,
		PrecioRepository? precioRepository,
    MovimientoInventarioRepository? movimientoRepository,
    TraspasoRepository? traspasoRepository,
    VarianteRepository? varianteRepository,
    AlmacenRepository? almacenRepository,
    PresentacionRepository? presentacionRepository,
    ServicioCorteCaja? servicioCorteCaja,
    required Database baseDatos,
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
	     _compraRepository = compraRepository,
	     _pedidoRepository = pedidoRepository,
	     _cotizacionRepository = cotizacionRepository,
	     _precioRepository = precioRepository,
       _movimientoRepository = movimientoRepository,
       _traspasoRepository = traspasoRepository,
       _varianteRepository = varianteRepository,
       _almacenRepository = almacenRepository,
       _presentacionRepository = presentacionRepository,
       _servicioCorteCaja = servicioCorteCaja,
       _baseDatos = baseDatos,
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
	final CompraRepository? _compraRepository;
	final PedidoRepository? _pedidoRepository;
	final CotizacionRepository? _cotizacionRepository;
	final PrecioRepository? _precioRepository;
  final MovimientoInventarioRepository? _movimientoRepository;
  final TraspasoRepository? _traspasoRepository;
  final VarianteRepository? _varianteRepository;
  final AlmacenRepository? _almacenRepository;
  final PresentacionRepository? _presentacionRepository;
  final ServicioCorteCaja? _servicioCorteCaja;
  final Database _baseDatos;
  final String _tiendaActivaId;
  final String _cajaId;
  final Uuid _generadorId = const Uuid();

  Future<T> _enTransaccion<T>(Future<T> Function(Transaction tx) accion) {
    return _baseDatos.transaction(accion);
  }

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
  Future<List<ResumenVentasDia>> obtenerResumenVentasPeriodo({
    required int dias,
  }) async {
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

  Future<List<Producto>> listarProductosActivosPorTienda(
    String tiendaId,
  ) async {
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

  ModuloVertical _derivarModuloVertical(
    String categoriaId,
    UnidadMedida unidad,
  ) {
    if (categoriaId == ID_CAT_CARNICERIA) {
      return ModuloVertical.carniceria;
    }
    if (categoriaId == ID_CAT_FARMACIA) {
      return ModuloVertical.farmacia;
    }
    return ModuloVertical.general;
  }

  UnidadMedida _unidadPorCategoria(
    String categoriaId,
    UnidadMedida solicitada,
  ) {
    if (categoriaId == ID_CAT_CARNICERIA && solicitada == UnidadMedida.pieza) {
      return UnidadMedida.kilogramo;
    }
    return solicitada;
  }

  Future<Producto> registrarProductoCompleto(AltaProductoRequest req) async {
    if (req.categoriaId.isEmpty) {
      throw StateError('La categoria es obligatoria');
    }
    _validarPrecioVenta(req.precioBase, req.costoUnitario);
    for (final escala in req.escalasMayoreo) {
      _validarPrecioVenta(escala.precioUnitario, req.costoUnitario);
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
      permiteStockNegativo: req.permiteStockNegativo,
    );
    await _enTransaccion((tx) async {
      await _productoRepository.guardar(producto, db: tx);
      final ahora = DateTime.now().toUtc();
      await _inventarioRepository.guardarStock(
        StockNivel(
          productoId: producto.id,
          tiendaId: _tiendaActivaId,
          cantidad: req.stockInicial,
          actualizadoEn: ahora,
          stockMinimo: req.stockMinimo,
        ),
        db: tx,
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
        await _precioRepository.reemplazarEscalasMayoreo(
          producto.id,
          escalas,
          db: tx,
        );
      }
      await asegurarPresentacionBase(producto, db: tx);
    });
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
    _validarPrecioVenta(producto.precioBase, producto.costoUnitario);
    if (escalasMayoreo != null) {
      for (final escala in escalasMayoreo) {
        _validarPrecioVenta(escala.precioUnitario, producto.costoUnitario);
      }
    }
    final unidad = _unidadPorCategoria(
      producto.categoriaId!,
      producto.unidadMedida,
    );
    final actualizado = producto.copiarCon(
      moduloVertical: _derivarModuloVertical(producto.categoriaId!, unidad),
      unidadMedida: unidad,
      precioBase: redondearMonto(producto.precioBase),
    );
    await _enTransaccion((tx) async {
      await _productoRepository.guardar(actualizado, db: tx);
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
          db: tx,
        );
      }
    });
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
    await _enTransaccion((tx) async {
      await _precioRepository?.eliminarEscalasPorProducto(productoId, db: tx);
      await _precioRepository?.eliminarPreciosPorProducto(productoId, db: tx);
      await _varianteRepository?.eliminarPorProductoPadre(productoId, db: tx);
      await _inventarioRepository.eliminarStockPorProducto(productoId, db: tx);
      await _productoRepository.eliminar(productoId, db: tx);
    });
    return true;
  }

  Future<bool> _productoTieneStock(String productoId) async {
    final tiendas = await _tiendaRepository.listarActivas();
    for (final tienda in tiendas) {
      final stock = await _inventarioRepository.obtenerStock(
        productoId,
        tienda.id,
      );
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
    await _enTransaccion((tx) async {
      await _productoRepository.guardar(producto, db: tx);
      final ahora = DateTime.now().toUtc();
      await _inventarioRepository.guardarStock(
        StockNivel(
          productoId: producto.id,
          tiendaId: _tiendaActivaId,
          cantidad: 0.0,
          actualizadoEn: ahora,
        ),
        db: tx,
      );
    });
    await _registrarEventoProducto(producto);
    return producto;
  }

  /// Obtiene inventario consolidado de todas las tiendas activas.
  ///
  /// Retorna lista de existencias por producto y sucursal.
  Future<List<StockPorTienda>> obtenerInventarioConsolidado() async {
    final tiendas = await _tiendaRepository.listarActivas();
    final productos = await _productoRepository.listarActivosPorTienda(
      _tiendaActivaId,
    );
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
            actualizadoEn:
                stock?.actualizadoEn ?? DateTime.fromMillisecondsSinceEpoch(0),
            stockMinimo: stock?.stockMinimo ?? 0.0,
          ),
        );
      }
    }
    return resultado;
  }

  /// Agrupa existencias por producto con totales por tienda y almacén.
  Future<List<InventarioAgrupado>> obtenerInventarioAgrupado({
    String? tiendaReferenciaId,
  }) async {
    final tiendaRef = tiendaReferenciaId ?? _tiendaActivaId;
    final tiendas = await _tiendaRepository.listarActivas();
    final almacenRepo = _almacenRepository;
    final almacenes = almacenRepo != null ? await almacenRepo.listarActivos() : <Almacen>[];
    final stockAlmacenPorProducto = <String, Map<String, StockAlmacen>>{};
    if (almacenRepo != null) {
      for (final stock in await almacenRepo.listarTodoStock()) {
        stockAlmacenPorProducto
            .putIfAbsent(stock.productoId, () => {})[stock.almacenId] = stock;
      }
    }
    final productosPorId = <String, Producto>{};
    for (final tienda in tiendas) {
      final productos = await _productoRepository.listarActivosPorTienda(
        tienda.id,
      );
      for (final producto in productos) {
        productosPorId[producto.id] = producto;
      }
    }
    for (final productoId in stockAlmacenPorProducto.keys) {
      if (productosPorId.containsKey(productoId)) {
        continue;
      }
      final producto = await _productoRepository.obtenerPorId(productoId);
      if (producto != null) {
        productosPorId[productoId] = producto;
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
      final porAlmacenNombre = <String, double>{};
      final porAlmacenId = <String, double>{};
      final minimosPorAlmacenId = <String, double>{};
      final stocksProducto = stockAlmacenPorProducto[producto.id] ?? {};
      for (final almacen in almacenes) {
        final stock = stocksProducto[almacen.id];
        porAlmacenNombre[almacen.nombre] = stock?.cantidad ?? 0.0;
        porAlmacenId[almacen.id] = stock?.cantidad ?? 0.0;
        minimosPorAlmacenId[almacen.id] = stock?.stockMinimo ?? 0.0;
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
          existenciasPorAlmacen: porAlmacenNombre,
          existenciasPorAlmacenId: porAlmacenId,
          stockMinimoPorAlmacenId: minimosPorAlmacenId,
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

  /// Limpia placeholders, compara con la nube y descarga datos si hace falta.
  Future<ResultadoReconciliacionHub> reconciliarConHub() async {
    final servicio = ServicioReconciliacionHub(
      baseDatos: _baseDatos,
      configRepository: _configRepository,
      syncOrchestrator: _syncOrchestrator,
      syncStateRepository: SyncStateRepository(baseDatos: _baseDatos),
      tiendaRepository: _tiendaRepository,
    );
    return servicio.reconciliar();
  }

  /// Empuja cambios locales y descarga usuarios del hub (reparacion).
  Future<ResultadoSync> repararSincronizacionUsuarios() async {
    final repo = _usuarioRepository;
    if (repo != null) {
      final activos = await repo.listarTodos();
      for (final usuario in activos) {
        await _registrarEventoUsuario(usuario);
      }
    }
    return sincronizarManual();
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
    return await _configRepository.obtenerValor(claveConfigHubApiKey) ?? '';
  }

  Future<void> guardarHubApiKey(String clave) async {
    await _configRepository.guardarValor(
      claveConfigHubApiKey,
      clave.trim(),
    );
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
    final padre = await _productoRepository.obtenerPorId(productoPadreId);
    if (padre != null) {
      _validarPrecioVenta(precioBase, padre.costoUnitario);
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
    final padre = await _productoRepository.obtenerPorId(variante.productoPadreId);
    if (padre != null) {
      _validarPrecioVenta(variante.precioBase, padre.costoUnitario);
    }
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

  /// Elimina un cliente sin historial de ventas, pedidos ni cotizaciones.
  ///
  /// Lanza [StateError] si el cliente tiene movimientos registrados.
  Future<void> eliminarCliente(String clienteId) async {
    final repo = _clienteRepository;
    if (repo == null) {
      throw StateError('Repositorio de clientes no configurado');
    }
    if (await _ventaRepository.contarPorCliente(clienteId) > 0) {
      throw StateError(
        'No se puede eliminar: el cliente tiene ventas registradas',
      );
    }
    if (await (_pedidoRepository?.contarPorCliente(clienteId) ?? Future.value(0)) > 0) {
      throw StateError(
        'No se puede eliminar: el cliente tiene pedidos registrados',
      );
    }
    if (await (_cotizacionRepository?.contarPorCliente(clienteId) ?? Future.value(0)) > 0) {
      throw StateError(
        'No se puede eliminar: el cliente tiene cotizaciones registradas',
      );
    }
    await repo.eliminar(clienteId);
  }

  Future<Cliente?> obtenerCliente(String clienteId) async {
    return _clienteRepository?.obtenerPorId(clienteId);
  }

  Future<Vendedor?> obtenerVendedor(String vendedorId) async {
    return _vendedorRepository?.obtenerPorId(vendedorId);
  }

  Future<List<Venta>> listarVentasCliente(
    String clienteId, {
    int dias = 90,
  }) async {
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

  Future<List<DescuentoCliente>> listarDescuentosCliente(
    String clienteId,
  ) async {
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
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }
    _validarPrecioVenta(precioUnitario, producto.costoUnitario);
    await repo.guardarPrecioClienteProducto(
      PrecioClienteProducto(
        clienteId: clienteId,
        productoId: productoId,
        precioUnitario: redondearMonto(precioUnitario),
      ),
    );
  }

  Future<void> eliminarPrecioEspecialCliente(
    String clienteId,
    String productoId,
  ) async {
    await _precioRepository?.eliminarPrecioClienteProducto(
      clienteId,
      productoId,
    );
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
    if (condicion != CondicionDescuentoCliente.siempre &&
        (umbral == null || umbral <= 0)) {
      throw StateError('Indique el umbral de la regla');
    }
    if (condicion == CondicionDescuentoCliente.cantidadMinima &&
        tipo.esGeneral) {
      throw StateError(
        'La cantidad minima aplica solo a descuentos por producto',
      );
    }
    if (condicion == CondicionDescuentoCliente.montoTicketMinimo &&
        tipo.esPorProducto) {
      throw StateError('El monto minimo aplica solo a descuentos generales');
    }
  }

  // --- Vendedores ---

  Future<List<Vendedor>> listarVendedores({Usuario? operador}) async {
    final repo = _vendedorRepository;
    if (repo == null) {
      return [];
    }
    if (operador == null ||
        PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
      return repo.listarTodos();
    }
    return repo.listarTodos(tiendaId: operador.tiendaId);
  }

  Future<Vendedor> registrarVendedor({
    required String nombre,
    String? tiendaId,
    Usuario? operador,
  }) async {
    throw StateError(
      'Use registrarUsuario para dar de alta personal. '
      'Cada cuenta crea automaticamente su vendedor al iniciar sesion.',
    );
  }

  Future<void> actualizarVendedor(
    Vendedor vendedor, {
    Usuario? operador,
  }) async {
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

  /// Aplica tienda del usuario y sync inicial tras login.
  Future<void> activarSesionTrasLogin(
    Usuario usuario, {
    List<Tienda> tiendasDesdeHub = const [],
  }) async {
    if (usuario.rol != RolUsuario.administrador) {
      final tiendaId = usuario.tiendaId;
      if (tiendaId == null || tiendaId.isEmpty) {
        throw StateError('Usuario sin tienda asignada');
      }
      await cambiarTiendaActiva(tiendaId);
    } else {
      await LimpiadorBaseLocal.eliminarDatosEjemplo(_baseDatos);
      await _asegurarTiendasAdministrador(tiendasIniciales: tiendasDesdeHub);
    }
  }

  Future<Usuario?> autenticarUsuarioPorPin(String pin) async {
    return _usuarioRepository?.autenticarPorPin(pin);
  }

  Future<Usuario?> autenticarUsuarioPorPinYRol(
    String pin,
    RolUsuario rol,
  ) async {
    return _usuarioRepository?.autenticarPorPinYRol(pin, rol);
  }

  Future<List<Usuario>> listarUsuarios({Usuario? operador}) async {
    final repo = _usuarioRepository;
    if (repo == null) {
      return [];
    }
    if (operador == null ||
        PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
      return repo.listarTodos();
    }
    final todos = await repo.listarTodos();
    return todos
        .where((u) => PermisosUsuario.puedeGestionarUsuario(operador, u))
        .toList();
  }

  Future<List<Tienda>> obtenerTiendasPermitidas({Usuario? operador}) async {
    if (operador != null &&
        PermisosUsuario.puedeGestionarTodasLasTiendas(operador) &&
        (await _tiendaRepository.listarActivasOperativas()).isEmpty) {
      await _sincronizarTiendasDesdeHub();
    }
    final tiendas = await _tiendaRepository.listarActivasOperativas();
    if (operador == null ||
        PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
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
    if (rol == RolUsuario.administrador &&
        operador?.rol == RolUsuario.supervisor) {
      throw StateError('Sin permiso para crear administradores');
    }
    if (operador?.rol == RolUsuario.supervisor && rol != RolUsuario.empleado) {
      throw StateError('Los supervisores solo pueden crear empleados');
    }
    final activos = await repo.contarActivos();
    if (activos >= LIMITE_MAX_USUARIOS) {
      throw StateError(
        'Limite de $LIMITE_MAX_USUARIOS cuentas activas alcanzado',
      );
    }
    final codigo = await _resolverCodigoUsuarioDisponible(repo, rol);
    final usuario = Usuario(
      id: IdPosia.usuario(codigo),
      nombre: nombreLimpio,
      codigo: codigo,
      pin: pin.trim(),
      rol: rol,
      tiendaId: rol == RolUsuario.administrador ? null : tiendaDestino,
      activo: true,
    );
    if (operador != null &&
        !PermisosUsuario.puedeGestionarUsuario(operador, usuario)) {
      throw StateError('Sin permiso para crear este usuario');
    }
    await repo.guardar(usuario);
    await _registrarEventoUsuario(usuario);
    await _sincronizarVendedorVinculado(usuario);
    await _sincronizarInmediatoConHub();
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
    if (operador != null &&
        !PermisosUsuario.puedeGestionarUsuario(operador, existente)) {
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
        codigoFinal = await _resolverCodigoUsuarioDisponible(repo, rolFinal);
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
    await _sincronizarVendedorVinculado(actualizado);
    await _sincronizarInmediatoConHub();
    return actualizado;
  }

  Future<void> _sincronizarVendedorVinculado(Usuario usuario) async {
    final repo = _vendedorRepository;
    if (repo == null) {
      return;
    }
    await SincronizadorVendedorUsuario.sincronizar(repo: repo, usuario: usuario);
  }

  void _validarAsignacionRol({
    Usuario? operador,
    required RolUsuario rolNuevo,
    required RolUsuario rolAnterior,
  }) {
    if (operador?.rol != RolUsuario.supervisor) {
      return;
    }
    if (rolNuevo == RolUsuario.administrador ||
        rolAnterior == RolUsuario.administrador) {
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
    if (esPropiaCuenta &&
        !await repo.verificarPin(usuarioId, pinActual.trim())) {
      throw StateError('PIN actual incorrecto');
    }
    if (pinNuevo.trim().length != LONGITUD_PIN_ADMIN) {
      throw StateError('El PIN debe tener $LONGITUD_PIN_ADMIN digitos');
    }
    await repo.guardar(existente.copiarCon(pin: pinNuevo.trim()));
    final actualizado = await repo.obtenerPorId(usuarioId);
    if (actualizado == null) {
      throw StateError('Usuario no encontrado');
    }
    await _registrarEventoUsuario(actualizado);
    await _sincronizarInmediatoConHub();
  }

  String? _resolverTiendaOperacion(Usuario? operador, String? tiendaId) {
    if (operador != null &&
        !PermisosUsuario.puedeGestionarTodasLasTiendas(operador)) {
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

  /// Elimina un proveedor sin compras registradas.
  ///
  /// Los productos vinculados quedan sin proveedor asignado.
  /// Lanza [StateError] si el proveedor tiene compras en el historial.
  Future<void> eliminarProveedor(String proveedorId) async {
    final repo = _proveedorRepository;
    if (repo == null) {
      throw StateError('Repositorio de proveedores no configurado');
    }
    if (await (_compraRepository?.contarPorProveedor(proveedorId) ?? Future.value(0)) > 0) {
      throw StateError(
        'No se puede eliminar: el proveedor tiene compras registradas',
      );
    }
    await repo.eliminar(proveedorId);
  }

  Future<Proveedor?> obtenerProveedor(String proveedorId) async {
    return _proveedorRepository?.obtenerPorId(proveedorId);
  }

  Future<void> vincularProductoProveedor(
    String productoId,
    String? proveedorId,
  ) async {
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }
    await actualizarProducto(producto.copiarCon(proveedorId: proveedorId));
  }

  // --- Compras ---

  Future<Compra> registrarCompra({
    required String proveedorId,
    required List<LineaCompraSolicitud> lineas,
    required DateTime fechaCompra,
    String notas = '',
    String? tiendaId,
    Usuario? operador,
  }) async {
    final repo = _compraRepository;
    if (repo == null) {
      throw StateError('Repositorio de compras no configurado');
    }
    if (lineas.isEmpty) {
      throw StateError('Seleccione al menos un producto');
    }
    final proveedor = await _proveedorRepository?.obtenerPorId(proveedorId);
    if (proveedor == null) {
      throw StateError('Proveedor no encontrado');
    }
    final tiendaDestino = tiendaId ?? _tiendaActivaId;
    _validarPermisoTienda(operador, tiendaDestino);
    final ahora = DateTime.now().toUtc();
    final compraId = _generadorId.v4();
    final lineasCompra = <LineaCompra>[];
    final productosActualizados = <Producto>[];
    final movimientosPendientes = <MovimientoInventario>[];
    var total = 0.0;

    for (final solicitud in lineas) {
      if (solicitud.cantidad <= 0) {
        throw StateError('La cantidad debe ser mayor a cero');
      }
      if (solicitud.costoUnitario < 0) {
        throw StateError('El costo no puede ser negativo');
      }
      final producto = await _productoRepository.obtenerPorId(
        solicitud.productoId,
      );
      if (producto == null) {
        throw StateError('Producto no encontrado');
      }
      final costo = redondearMonto(solicitud.costoUnitario);
      final subtotal = redondearMonto(solicitud.cantidad * costo);
      total = total + subtotal;

      final stockActual = await _inventarioRepository.obtenerStock(
        solicitud.productoId,
        tiendaDestino,
      );
      final anterior = stockActual?.cantidad ?? 0.0;
      final nuevo = anterior + solicitud.cantidad;

      final productoActualizado = producto.copiarCon(
        costoUnitario: costo,
        proveedorId: proveedorId,
      );
      productosActualizados.add(productoActualizado);

      if (_movimientoRepository != null) {
        movimientosPendientes.add(
          MovimientoInventario(
            id: _generadorId.v4(),
            productoId: solicitud.productoId,
            tiendaId: tiendaDestino,
            tipo: TipoMovimientoInventario.entrada,
            cantidad: solicitud.cantidad,
            cantidadAnterior: anterior,
            cantidadNueva: nuevo,
            motivo: 'Compra ${compraId.substring(0, 8).toUpperCase()}',
            referenciaId: compraId,
            proveedorId: proveedorId,
            creadoEn: ahora,
            creadoPor: operador?.id,
          ),
        );
      }

      lineasCompra.add(
        LineaCompra(
          productoId: solicitud.productoId,
          nombreProducto: producto.nombre,
          cantidad: solicitud.cantidad,
          costoUnitario: costo,
          subtotal: subtotal,
        ),
      );
    }

    final compra = Compra(
      id: compraId,
      tiendaId: tiendaDestino,
      proveedorId: proveedorId,
      fechaCompra: fechaCompra.toUtc(),
      notas: notas.trim(),
      total: redondearMonto(total),
      creadaEn: ahora,
      creadoPor: operador?.id,
      lineas: lineasCompra,
    );

    await _enTransaccion((tx) async {
      for (var i = 0; i < lineasCompra.length; i++) {
        final linea = lineasCompra[i];
        final movimiento = i < movimientosPendientes.length
            ? movimientosPendientes[i]
            : null;
        final stockActual = await _inventarioRepository.obtenerStock(
          linea.productoId,
          tiendaDestino,
          db: tx,
        );
        final anterior = stockActual?.cantidad ?? 0.0;
        await _inventarioRepository.guardarStock(
          StockNivel(
            productoId: linea.productoId,
            tiendaId: tiendaDestino,
            cantidad: anterior + linea.cantidad,
            actualizadoEn: ahora,
            stockMinimo: stockActual?.stockMinimo ?? 0.0,
          ),
          db: tx,
        );
        await _productoRepository.guardar(productosActualizados[i], db: tx);
        if (movimiento != null) {
          await _movimientoRepository!.guardar(movimiento, db: tx);
        }
      }
      await repo.guardar(compra, db: tx);
    });

    for (final producto in productosActualizados) {
      await _registrarEventoProducto(producto);
    }
    return compra;
  }

  Future<List<Compra>> listarCompras({
    String? tiendaId,
    Usuario? operador,
  }) async {
    final repo = _compraRepository;
    if (repo == null) {
      return [];
    }
    final tiendaDestino = tiendaId ?? operador?.tiendaId ?? _tiendaActivaId;
    _validarPermisoTienda(operador, tiendaDestino);
    return repo.listarPorTienda(tiendaDestino);
  }

  Future<Compra?> obtenerCompra(String compraId) async {
    return _compraRepository?.obtenerPorId(compraId);
  }

  // --- Pedidos ---

  void _validarGestionPedidos(Usuario? operador) {
    if (operador != null && !PermisosUsuario.puedeGestionarPedidos(operador)) {
      throw StateError('Sin permiso para gestionar pedidos');
    }
  }

  Future<List<Usuario>> listarEmpleadosParaAsignacion({Usuario? operador}) async {
    final usuarios = await listarUsuarios(operador: operador);
    return usuarios
        .where(
          (u) =>
              u.activo &&
              u.rol == RolUsuario.empleado &&
              (operador == null ||
                  PermisosUsuario.puedeGestionarTodasLasTiendas(operador) ||
                  u.tiendaId == operador.tiendaId),
        )
        .toList();
  }

  Future<List<Pedido>> listarPedidosRecibidos({
    String? tiendaId,
    Usuario? operador,
  }) async {
    _validarGestionPedidos(operador);
    final repo = _pedidoRepository;
    if (repo == null) {
      return [];
    }
    final destino = tiendaId ?? _tiendaActivaId;
    _validarPermisoTienda(operador, destino);
    return repo.listarPorTienda(destino, soloSinAsignar: true);
  }

  Future<List<Pedido>> listarPedidosTienda({
    String? tiendaId,
    Usuario? operador,
  }) async {
    _validarGestionPedidos(operador);
    final repo = _pedidoRepository;
    if (repo == null) {
      return [];
    }
    final destino = tiendaId ?? _tiendaActivaId;
    _validarPermisoTienda(operador, destino);
    return repo.listarPorTienda(destino);
  }

  Future<List<Pedido>> listarPedidosAsignadosA(Usuario empleado) async {
    final repo = _pedidoRepository;
    if (repo == null) {
      return [];
    }
    return repo.listarPorEmpleado(empleado.id);
  }

  Future<Pedido?> obtenerPedido(String pedidoId) async {
    return _pedidoRepository?.obtenerPorId(pedidoId);
  }

  // --- Cotizaciones ---

  Future<List<Cotizacion>> listarCotizaciones({int dias = 30}) async {
    final repo = _cotizacionRepository;
    if (repo == null) {
      return [];
    }
    final hasta = DateTime.now().toUtc();
    final desde = hasta.subtract(Duration(days: dias));
    return repo.listarPorTienda(_tiendaActivaId, desde: desde, hasta: hasta);
  }

  Future<Cotizacion?> obtenerCotizacion(String cotizacionId) async {
    return _cotizacionRepository?.obtenerPorId(cotizacionId);
  }

  /// Registra cotizacion desde administracion (sin carrito de caja).
  Future<Cotizacion> registrarCotizacion({
    required List<LineaCotizacion> lineas,
    String? clienteId,
    String notas = '',
    int vigenciaDias = VIGENCIA_COTIZACION_DIAS,
    String? vendedorId,
  }) async {
    final repo = _cotizacionRepository;
    if (repo == null) {
      throw StateError('Repositorio de cotizaciones no configurado');
    }
    if (lineas.isEmpty) {
      throw StateError('Agregue al menos un producto a la cotización');
    }
    if (vigenciaDias <= 0) {
      throw StateError('Indique días de vigencia válidos');
    }
    String? nombreCliente;
    if (clienteId != null) {
      final cliente = await _clienteRepository?.obtenerPorId(clienteId);
      nombreCliente = cliente?.nombre;
    }
    final cotizacion = Cotizacion(
      id: _generadorId.v4(),
      tiendaId: _tiendaActivaId,
      clienteId: clienteId,
      nombreCliente: nombreCliente,
      total: Cotizacion.calcularTotalDesdeLineas(lineas),
      notas: notas.trim(),
      vigenciaDias: vigenciaDias,
      creadaEn: DateTime.now().toUtc(),
      cajaId: _cajaId,
      vendedorId: vendedorId,
      lineas: lineas,
    );
    await repo.guardar(cotizacion);
    return cotizacion;
  }

  Future<Pedido> registrarPedido({
    required List<LineaPedidoSolicitud> lineas,
    required String nombreEntrega,
    required String telefonoEntrega,
    required String direccionEntrega,
    required MetodoPago metodoPago,
    String? clienteId,
    String notas = '',
    String? tiendaId,
    Usuario? operador,
  }) async {
    _validarGestionPedidos(operador);
    final repo = _pedidoRepository;
    if (repo == null) {
      throw StateError('Repositorio de pedidos no configurado');
    }
    if (lineas.isEmpty) {
      throw StateError('Agregue al menos un producto al pedido');
    }
    final nombre = nombreEntrega.trim();
    final telefono = telefonoEntrega.trim();
    final direccion = direccionEntrega.trim();
    if (nombre.isEmpty || telefono.isEmpty || direccion.isEmpty) {
      throw StateError('Nombre, telefono y direccion de entrega son obligatorios');
    }
    final destino = tiendaId ?? _tiendaActivaId;
    _validarPermisoTienda(operador, destino);
    final esCredito = metodoPago == MetodoPago.credito;
    int? creditoDias;
    DateTime? creditoVenceEn;
    if (esCredito) {
      Cliente? cliente;
      if (clienteId != null) {
        cliente = await _clienteRepository?.obtenerPorId(clienteId);
      }
      if (cliente != null) {
        final error = validarClienteParaCredito(cliente);
        if (error != null) {
          throw StateError(error);
        }
        creditoDias = cliente.diasCredito;
      } else {
        creditoDias = DIAS_CREDITO_PREDETERMINADO;
      }
      creditoVenceEn = calcularFechaVencimientoCredito(
        DateTime.now().toUtc(),
        creditoDias,
      );
    }
    final lineasPedido = <LineaPedido>[];
    for (final solicitud in lineas) {
      if (solicitud.cantidad <= 0) {
        throw StateError('Cantidad invalida en linea de pedido');
      }
      final producto = await _productoRepository.obtenerPorId(solicitud.productoId);
      if (producto == null) {
        throw StateError('Producto no encontrado');
      }
      lineasPedido.add(
        LineaPedido(
          productoId: producto.id,
          nombreProducto: producto.nombre,
          cantidad: solicitud.cantidad,
          precioUnitario: redondearMonto(solicitud.precioUnitario),
        ),
      );
    }
    final pedido = Pedido(
      id: _generadorId.v4(),
      tiendaId: destino,
      clienteId: clienteId,
      nombreEntrega: nombre,
      telefonoEntrega: telefono,
      direccionEntrega: direccion,
      esCredito: esCredito,
      creditoDias: creditoDias,
      creditoVenceEn: creditoVenceEn,
      metodoPago: metodoPago,
      total: Pedido.calcularTotalDesdeLineas(lineasPedido),
      notas: notas.trim(),
      estado: EstadoPedido.recibido,
      creadoEn: DateTime.now().toUtc(),
      creadoPorUsuarioId: operador?.id,
      lineas: lineasPedido,
    );
    await repo.guardar(pedido);
    return pedido;
  }

  Future<Pedido> asignarPedido({
    required String pedidoId,
    required String empleadoUsuarioId,
    Usuario? operador,
  }) async {
    _validarGestionPedidos(operador);
    final repo = _pedidoRepository;
    if (repo == null) {
      throw StateError('Repositorio de pedidos no configurado');
    }
    final pedido = await repo.obtenerPorId(pedidoId);
    if (pedido == null) {
      throw StateError('Pedido no encontrado');
    }
    _validarPermisoTienda(operador, pedido.tiendaId);
    if (!pedido.puedeAsignarse) {
      throw StateError('El pedido no puede asignarse en su estado actual');
    }
    final empleado = await _usuarioRepository?.obtenerPorId(empleadoUsuarioId);
    if (empleado == null || !empleado.activo) {
      throw StateError('Empleado no encontrado');
    }
    if (empleado.rol != RolUsuario.empleado) {
      throw StateError('Solo puede asignarse a empleados');
    }
    if (operador != null &&
        !PermisosUsuario.puedeGestionarTodasLasTiendas(operador) &&
        empleado.tiendaId != operador.tiendaId) {
      throw StateError('El empleado no pertenece a su tienda');
    }
    final actualizado = pedido.copiarCon(
      estado: EstadoPedido.asignado,
      asignadoAUsuarioId: empleado.id,
      asignadoAUsuarioNombre: empleado.nombre,
      asignadoEn: DateTime.now().toUtc(),
    );
    await repo.guardar(actualizado);
    return actualizado;
  }

  Future<Pedido> marcarPedidoEntregado({
    required String pedidoId,
    Usuario? operador,
  }) async {
    final repo = _pedidoRepository;
    if (repo == null) {
      throw StateError('Repositorio de pedidos no configurado');
    }
    final pedido = await repo.obtenerPorId(pedidoId);
    if (pedido == null) {
      throw StateError('Pedido no encontrado');
    }
    if (operador != null &&
        operador.rol == RolUsuario.empleado &&
        pedido.asignadoAUsuarioId != operador.id) {
      throw StateError('Este pedido no esta asignado a usted');
    }
    if (operador != null &&
        operador.rol != RolUsuario.empleado &&
        !PermisosUsuario.puedeGestionarPedidos(operador)) {
      throw StateError('Sin permiso');
    }
    if (!pedido.puedeMarcarseEntregado) {
      throw StateError('El pedido no puede marcarse como entregado');
    }
    final actualizado = pedido.copiarCon(estado: EstadoPedido.entregado);
    await repo.guardar(actualizado);
    return actualizado;
  }

  Future<Pedido> cancelarPedido({
    required String pedidoId,
    Usuario? operador,
  }) async {
    _validarGestionPedidos(operador);
    final repo = _pedidoRepository;
    if (repo == null) {
      throw StateError('Repositorio de pedidos no configurado');
    }
    final pedido = await repo.obtenerPorId(pedidoId);
    if (pedido == null) {
      throw StateError('Pedido no encontrado');
    }
    _validarPermisoTienda(operador, pedido.tiendaId);
    if (pedido.estado == EstadoPedido.entregado) {
      throw StateError('No se puede cancelar un pedido entregado');
    }
    final actualizado = pedido.copiarCon(estado: EstadoPedido.cancelado);
    await repo.guardar(actualizado);
    return actualizado;
  }

  // --- Configuracion ---

  Future<String> obtenerPinAdmin() async {
    return await _configRepository.obtenerValor(claveConfigPinAdmin) ?? '';
  }

  Future<void> guardarPinAdmin(String pin) async {
    await _configRepository.guardarValor(claveConfigPinAdmin, pin);
  }

  Future<String> obtenerTeclaCobrar() async {
    return await _configRepository.obtenerValor(claveConfigTeclaCobrar) ??
        teclaCobrarConfigPredeterminada;
  }

  Future<void> guardarTeclaCobrar(String tecla) async {
    await _configRepository.guardarValor(claveConfigTeclaCobrar, tecla.trim().toUpperCase());
  }

  /// Lee JSON de atajos de caja; si no existe, usa tecla cobrar legacy.
  Future<String> obtenerAtajosCajaJson() async {
    final raw = await _configRepository.obtenerValor(claveConfigAtajosCaja);
    if (raw != null && raw.trim().isNotEmpty) {
      return raw;
    }
    final cobrar = await obtenerTeclaCobrar();
    return jsonEncode({'cobrar': cobrar});
  }

  /// Persiste mapa JSON de atajos y sincroniza tecla cobrar legacy.
  Future<void> guardarAtajosCajaJson(String json) async {
    await _configRepository.guardarValor(claveConfigAtajosCaja, json);
    try {
      final decodificado = jsonDecode(json);
      if (decodificado is Map && decodificado['cobrar'] != null) {
        await guardarTeclaCobrar(decodificado['cobrar'].toString());
      }
    } catch (_) {
      // Ignorar parseo; el JSON ya quedo guardado.
    }
  }

  Future<double> obtenerEtiquetaAnchoMm() async {
    final raw = await _configRepository.obtenerValor(claveConfigEtiquetaAnchoMm);
    return double.tryParse(raw ?? '') ?? etiquetaAnchoMmPredeterminado;
  }

  Future<double> obtenerEtiquetaAltoMm() async {
    final raw = await _configRepository.obtenerValor(claveConfigEtiquetaAltoMm);
    return double.tryParse(raw ?? '') ?? etiquetaAltoMmPredeterminado;
  }

  Future<void> guardarTamanoEtiquetaMm({
    required double anchoMm,
    required double altoMm,
  }) async {
    await _configRepository.guardarValor(
      claveConfigEtiquetaAnchoMm,
      anchoMm.toStringAsFixed(1),
    );
    await _configRepository.guardarValor(
      claveConfigEtiquetaAltoMm,
      altoMm.toStringAsFixed(1),
    );
  }

  Future<String?> obtenerCarpetaEtiquetas() async {
    final raw = await _configRepository.obtenerValor(claveConfigEtiquetasCarpeta);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> guardarCarpetaEtiquetas(String ruta) async {
    await _configRepository.guardarValor(claveConfigEtiquetasCarpeta, ruta.trim());
  }

  Future<List<Venta>> listarCreditosPendientes() async {
    return _ventaRepository.listarCreditosPendientes(_tiendaActivaId);
  }

  /// Registra una venta a credito desde administracion (fiado al cliente).
  ///
  /// Valida datos del cliente, descuenta inventario y encola sincronizacion.
  Future<Venta> registrarVentaCredito({
    required String clienteId,
    required List<LineaPedidoSolicitud> lineas,
    int? diasCredito,
    Usuario? operador,
  }) async {
    final repoCliente = _clienteRepository;
    if (repoCliente == null) {
      throw StateError('Repositorio de clientes no configurado');
    }
    final cliente = await repoCliente.obtenerPorId(clienteId);
    if (cliente == null) {
      throw StateError('Cliente no encontrado');
    }
    final dias = diasCredito ?? cliente.diasCredito;
    final errorCliente = validarClienteParaCredito(cliente, diasCredito: dias);
    if (errorCliente != null) {
      throw StateError(errorCliente);
    }
    if (lineas.isEmpty) {
      throw StateError('Agregue al menos un producto');
    }

    final lineasVenta = <LineaVenta>[];
    for (final solicitud in lineas) {
      if (solicitud.cantidad <= 0) {
        throw StateError('Cantidad invalida en linea de credito');
      }
      if (solicitud.precioUnitario <= 0) {
        throw StateError('Precio invalido en linea de credito');
      }
      final producto = await _productoRepository.obtenerPorId(solicitud.productoId);
      if (producto == null) {
        throw StateError('Producto no encontrado');
      }
      final stock = await _inventarioRepository.obtenerStock(
        producto.id,
        _tiendaActivaId,
      );
      final disponible = stock?.cantidad ?? 0.0;
      if (disponible < solicitud.cantidad) {
        throw StateError(
          'Stock insuficiente para ${producto.nombre} '
          '(disponible ${disponible.toStringAsFixed(1)})',
        );
      }
      lineasVenta.add(
        LineaVenta(
          productoId: producto.id,
          nombreProducto: producto.nombre,
          cantidad: solicitud.cantidad,
          precioUnitario: redondearMonto(solicitud.precioUnitario),
          reglaPrecio: ReglaPrecio.precioBase,
        ),
      );
    }

    final creditoVenceEn = calcularFechaVencimientoCredito(
      DateTime.now().toUtc(),
      dias,
    );
    final total = Venta.calcularTotalDesdeLineas(lineasVenta);
    final turno = await _servicioCorteCaja?.obtenerTurnoAbierto();
    String? vendedorId;
    if (operador != null && _vendedorRepository != null) {
      await SincronizadorVendedorUsuario.sincronizar(
        repo: _vendedorRepository,
        usuario: operador,
      );
      vendedorId = 'vend-${operador.id}';
    }

    final venta = Venta(
      id: _generadorId.v4(),
      tiendaId: _tiendaActivaId,
      cajaId: _cajaId,
      clienteId: clienteId,
      lineas: lineasVenta,
      metodoPago: MetodoPago.credito,
      total: total,
      creadaEn: DateTime.now().toUtc(),
      vendedorId: vendedorId,
      turnoCajaId: turno?.id,
      creditoDias: dias,
      creditoVenceEn: creditoVenceEn,
    );

    await _enTransaccion((tx) async {
      await _ventaRepository.guardar(venta, db: tx);
      final ahora = DateTime.now().toUtc();
      for (final linea in lineasVenta) {
        final stock = await _inventarioRepository.obtenerStock(
          linea.productoId,
          _tiendaActivaId,
          db: tx,
        );
        await _inventarioRepository.guardarStock(
          StockNivel(
            productoId: linea.productoId,
            tiendaId: _tiendaActivaId,
            cantidad: (stock?.cantidad ?? 0.0) - linea.cantidad,
            actualizadoEn: ahora,
            stockMinimo: stock?.stockMinimo ?? 0.0,
          ),
          db: tx,
        );
      }
      if (turno != null && _servicioCorteCaja != null) {
        await _servicioCorteCaja.registrarVenta(turno, venta, db: tx);
      }
    });
    await _registrarEventoVentaCompletada(venta);
    return venta;
  }

  Future<Venta> liquidarCreditoVenta(String ventaId) async {
    final venta = await _ventaRepository.obtenerPorId(ventaId);
    if (venta == null) {
      throw StateError('Venta no encontrada');
    }
    if (venta.metodoPago != MetodoPago.credito) {
      throw StateError('La venta no es a credito');
    }
    if (venta.creditoLiquidado) {
      throw StateError('El credito ya fue liquidado');
    }
    final actualizada = venta.copiarCon(
      creditoLiquidado: true,
      creditoLiquidadoEn: DateTime.now().toUtc(),
    );
    await _ventaRepository.actualizarCreditoLiquidado(actualizada);
    return actualizada;
  }

  Future<ConfigDispositivo> obtenerConfigDispositivo() async {
    return _configRepository.obtenerConfigDispositivo();
  }

  Future<void> guardarConfigDispositivo({
    required String tiendaId,
    String? nombreCaja,
  }) async {
    final actual = await _configRepository.obtenerConfigDispositivo();
    await _configRepository.guardarConfigDispositivo(
      ConfigDispositivo(
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
    return FiltroVentas(tiendaId: tiendaId, desde: desde, hasta: hasta);
  }

  /// Filtro de ventas para una tienda y periodo dados.
  FiltroVentas filtroVentasPeriodoTienda(String tiendaId, {required int dias}) {
    final hasta = DateTime.now().toUtc();
    final desde = hasta.subtract(Duration(days: dias));
    return FiltroVentas(tiendaId: tiendaId, desde: desde, hasta: hasta);
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
    await _enTransaccion((tx) async {
      for (final linea in venta.lineas) {
        final devolver = cantidadesPorProducto[linea.productoId] ?? 0.0;
        if (devolver <= 0.0) {
          continue;
        }
        final stock = await _inventarioRepository.obtenerStock(
          linea.productoId,
          venta.tiendaId,
          db: tx,
        );
        await _inventarioRepository.guardarStock(
          StockNivel(
            productoId: linea.productoId,
            tiendaId: venta.tiendaId,
            cantidad: (stock?.cantidad ?? 0.0) + devolver,
            actualizadoEn: ahora,
            stockMinimo: stock?.stockMinimo ?? 0.0,
          ),
          db: tx,
        );
      }
      await _ventaRepository.actualizarVenta(ventaActualizada, db: tx);
      await _servicioCorteCaja?.registrarDevolucion(
        venta,
        montoDevuelto,
        db: tx,
      );
    });
    await _registrarEventoDevolucionParcial(
      venta,
      lineasDevueltas,
      montoDevuelto,
    );
    return true;
  }

  Future<bool> anularVenta(String ventaId) async {
    final venta = await _ventaRepository.obtenerPorId(ventaId);
    if (venta == null || !venta.puedeAnularse()) {
      return false;
    }
    final ahora = DateTime.now().toUtc();
    await _enTransaccion((tx) async {
      for (final linea in venta.lineas) {
        final stock = await _inventarioRepository.obtenerStock(
          linea.productoId,
          venta.tiendaId,
          db: tx,
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
          db: tx,
        );
      }
      await _ventaRepository.actualizarEstado(
        ventaId,
        EstadoVenta.cancelada,
        db: tx,
      );
      await _servicioCorteCaja?.registrarAnulacion(venta, db: tx);
    });
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

  /// Replica en SQLite local las tiendas activas del tenant (login hub).
  Future<void> importarTiendasDesdeHub(List<Tienda> tiendas) async {
    for (final tienda in tiendas) {
      if (!tienda.activa) {
        continue;
      }
      await _tiendaRepository.guardar(tienda);
    }
  }

  Future<void> _asegurarTiendasAdministrador({
    List<Tienda> tiendasIniciales = const [],
  }) async {
    if (tiendasIniciales.isNotEmpty) {
      await importarTiendasDesdeHub(tiendasIniciales);
    }
    if ((await _tiendaRepository.listarActivasOperativas()).isEmpty) {
      await _sincronizarTiendasDesdeHub();
    }
  }

  /// Descarga tiendas activas del hub e importa en SQLite local.
  Future<void> _sincronizarTiendasDesdeHub() async {
    final hubUrl = await _configRepository.obtenerHubUrl();
    if (hubUrl == null || hubUrl.isEmpty) {
      return;
    }
    final clave = await _configRepository.obtenerValor(claveConfigHubApiKey);
    final cliente = HubSyncClient(urlBase: hubUrl, claveApi: clave);
    final remotas = await cliente.obtenerTiendas();
    if (remotas.isEmpty) {
      return;
    }
    await importarTiendasDesdeHub(
      remotas
          .map(
            (t) => Tienda(
              id: t.id,
              nombre: t.nombre,
              direccion: t.direccion,
              activa: t.activa,
            ),
          )
          .toList(),
    );
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
      throw StateError(
        'Limite de $LIMITE_MAX_TIENDAS tiendas activas alcanzado',
      );
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
  Future<List<Venta>> listarVentasTiendaPeriodo(
    String tiendaId, {
    required int dias,
  }) async {
    return _ventaRepository.listarConFiltro(
      filtroVentasPeriodoTienda(tiendaId, dias: dias),
    );
  }

  Future<bool> eliminarVenta(String ventaId) async {
    final venta = await _ventaRepository.obtenerPorId(ventaId);
    if (venta == null) {
      return false;
    }
    if (venta.estado == EstadoVenta.completada) {
      final ahora = DateTime.now().toUtc();
      await _enTransaccion((tx) async {
        for (final linea in venta.lineas) {
          final stock = await _inventarioRepository.obtenerStock(
            linea.productoId,
            venta.tiendaId,
            db: tx,
          );
          await _inventarioRepository.guardarStock(
            StockNivel(
              productoId: linea.productoId,
              tiendaId: venta.tiendaId,
              cantidad: (stock?.cantidad ?? 0.0) + linea.cantidad,
              actualizadoEn: ahora,
              stockMinimo: stock?.stockMinimo ?? 0.0,
            ),
            db: tx,
          );
        }
        await _servicioCorteCaja?.registrarAnulacion(venta, db: tx);
        await _ventaRepository.eliminar(ventaId, db: tx);
      });
    } else {
      await _ventaRepository.eliminar(ventaId);
    }
    return true;
  }

  Future<void> cambiarTiendaActiva(String tiendaId) async {
    final config = await _configRepository.obtenerConfigDispositivo();
    await _configRepository.guardarConfigDispositivo(
      ConfigDispositivo(
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
  }) {
    return realizarTraspasoMultiple(
      tiendaOrigenId: tiendaOrigenId,
      tiendaDestinoId: tiendaDestinoId,
      lineas: [
        LineaTraspasoSolicitud(productoId: productoId, cantidad: cantidad),
      ],
      notas: notas,
      operador: operador,
    );
  }

  Future<Traspaso> realizarTraspasoMultiple({
    required String tiendaOrigenId,
    required String tiendaDestinoId,
    required List<LineaTraspasoSolicitud> lineas,
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
    if (lineas.isEmpty) {
      throw StateError('Seleccione al menos un producto');
    }
    _validarPermisoTienda(operador, tiendaOrigenId);
    _validarPermisoTienda(operador, tiendaDestinoId);

    final lineasTraspaso = <LineaTraspaso>[];
    final ahora = DateTime.now().toUtc();
    final lineasPendientes = <
        ({
          String productoId,
          double cantidad,
          double anteriorOrigen,
          double anteriorDestino,
        })>[];

    for (final solicitud in lineas) {
      if (solicitud.cantidad <= 0) {
        throw StateError('La cantidad debe ser mayor a cero');
      }
      final producto =
          await _productoRepository.obtenerPorId(solicitud.productoId) ??
          (await _productoRepository.listarActivosPorTienda(
            tiendaOrigenId,
          )).where((p) => p.id == solicitud.productoId).firstOrNull;
      if (producto == null) {
        throw StateError('Producto no encontrado: ${solicitud.productoId}');
      }

      final stockOrigen = await _inventarioRepository.obtenerStock(
        solicitud.productoId,
        tiendaOrigenId,
      );
      final anteriorOrigen = stockOrigen?.cantidad ?? 0.0;
      if (anteriorOrigen < solicitud.cantidad) {
        throw StateError('Stock insuficiente de ${producto.nombre} en origen');
      }

      final stockDestino = await _inventarioRepository.obtenerStock(
        solicitud.productoId,
        tiendaDestinoId,
      );
      final anteriorDestino = stockDestino?.cantidad ?? 0.0;

      lineasPendientes.add((
        productoId: solicitud.productoId,
        cantidad: solicitud.cantidad,
        anteriorOrigen: anteriorOrigen,
        anteriorDestino: anteriorDestino,
      ));

      lineasTraspaso.add(
        LineaTraspaso(
          productoId: solicitud.productoId,
          nombreProducto: producto.nombre,
          cantidadSolicitada: solicitud.cantidad,
          cantidadRecibida: solicitud.cantidad,
        ),
      );
    }

    final traspaso = Traspaso(
      id: _generadorId.v4(),
      tiendaOrigenId: tiendaOrigenId,
      tiendaDestinoId: tiendaDestinoId,
      estado: EstadoTraspaso.completado,
      solicitadoEn: ahora,
      completadoEn: ahora,
      notas: notas,
      lineas: lineasTraspaso,
    );

    await _enTransaccion((tx) async {
      for (final linea in lineasPendientes) {
        final stockOrigen = await _inventarioRepository.obtenerStock(
          linea.productoId,
          tiendaOrigenId,
          db: tx,
        );
        final anteriorOrigen = stockOrigen?.cantidad ?? 0.0;
        final nuevoOrigen = anteriorOrigen - linea.cantidad;
        await _inventarioRepository.guardarStock(
          StockNivel(
            productoId: linea.productoId,
            tiendaId: tiendaOrigenId,
            cantidad: nuevoOrigen,
            actualizadoEn: ahora,
            stockMinimo: stockOrigen?.stockMinimo ?? 0.0,
          ),
          db: tx,
        );

        final stockDestino = await _inventarioRepository.obtenerStock(
          linea.productoId,
          tiendaDestinoId,
          db: tx,
        );
        final anteriorDestino = stockDestino?.cantidad ?? 0.0;
        final nuevoDestino = anteriorDestino + linea.cantidad;
        await _inventarioRepository.guardarStock(
          StockNivel(
            productoId: linea.productoId,
            tiendaId: tiendaDestinoId,
            cantidad: nuevoDestino,
            actualizadoEn: ahora,
            stockMinimo: stockDestino?.stockMinimo ?? 0.0,
          ),
          db: tx,
        );

        await _registrarAuditoriaInventario(
          productoId: linea.productoId,
          tiendaId: tiendaOrigenId,
          tipo: TipoMovimientoInventario.traspasoSalida,
          cantidad: linea.cantidad,
          cantidadAnterior: anteriorOrigen,
          cantidadNueva: nuevoOrigen,
          motivo: 'Traspaso enviado',
          operadorId: operador?.id,
          creadoEn: ahora,
          db: tx,
        );
        await _registrarAuditoriaInventario(
          productoId: linea.productoId,
          tiendaId: tiendaDestinoId,
          tipo: TipoMovimientoInventario.traspasoEntrada,
          cantidad: linea.cantidad,
          cantidadAnterior: anteriorDestino,
          cantidadNueva: nuevoDestino,
          motivo: 'Traspaso recibido',
          operadorId: operador?.id,
          creadoEn: ahora,
          db: tx,
        );
      }
      await repo.guardar(traspaso, db: tx);
    });
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
    final lineasRecibidas = traspaso.lineas
        .map(
          (linea) => LineaTraspaso(
            productoId: linea.productoId,
            nombreProducto: linea.nombreProducto,
            cantidadSolicitada: linea.cantidadSolicitada,
            cantidadRecibida: linea.cantidadSolicitada,
          ),
        )
        .toList();
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
    await _enTransaccion((tx) async {
      for (final linea in traspaso.lineas) {
        final stock = await _inventarioRepository.obtenerStock(
          linea.productoId,
          _tiendaActivaId,
          db: tx,
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
          db: tx,
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
          db: tx,
        );
      }
      await repo.guardar(completado, db: tx);
    });
    await _registrarEventoTraspaso(
      completado,
      TipoSyncEvento.transferCompleted,
    );
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
    DatabaseExecutor? db,
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
      db: db,
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
    if (tipo == TipoMovimientoInventario.entrada) {
      throw StateError('Registre las entradas en la seccion Compras');
    }
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
    await _enTransaccion((tx) async {
      final stockEnTx = await _inventarioRepository.obtenerStock(
        productoId,
        tiendaDestino,
        db: tx,
      );
      final baseAnterior = stockEnTx?.cantidad ?? anterior;
      final cantidadFinal = tipo == TipoMovimientoInventario.ajuste
          ? cantidad
          : baseAnterior + delta;
      await _inventarioRepository.guardarStock(
        StockNivel(
          productoId: productoId,
          tiendaId: tiendaDestino,
          cantidad: cantidadFinal,
          actualizadoEn: ahora,
          stockMinimo: stockEnTx?.stockMinimo ?? stockActual?.stockMinimo ?? 0.0,
        ),
        db: tx,
      );
      await repo.guardar(
        MovimientoInventario(
          id: _generadorId.v4(),
          productoId: productoId,
          tiendaId: tiendaDestino,
          tipo: tipo,
          cantidad: cantidad,
          cantidadAnterior: baseAnterior,
          cantidadNueva: cantidadFinal,
          motivo: motivoLimpio,
          referenciaId: null,
          proveedorId: proveedorId,
          creadoEn: ahora,
          creadoPor: operador?.id,
        ),
        db: tx,
      );
    });
    await _registrarEventoAjusteStock(
      productoId,
      delta,
      motivoLimpio,
      tiendaId: tiendaDestino,
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

  Future<List<AlertaFaltante>> obtenerAlertasFaltantes({
    String? tiendaId,
  }) async {
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
        totalVendido: redondearMonto(
          (previo?.totalVendido ?? 0.0) + venta.total,
        ),
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

  Future<List<ResumenVentasHora>> obtenerResumenPorHora(
    FiltroVentas filtro,
  ) async {
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
    final lista = ListaPrecios(id: _generadorId.v4(), nombre: nombre.trim());
    await repo.guardarLista(lista);
    return lista;
  }

  Future<void> guardarPrecioLista(
    String listaId,
    String productoId,
    double precio,
  ) async {
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }
    _validarPrecioVenta(precio, producto.costoUnitario);
    await _precioRepository?.guardarPrecioLista(
      listaId,
      productoId,
      redondearMonto(precio),
    );
  }

  Future<ResumenPreciosProducto?> obtenerResumenPreciosProducto(
    String productoId,
  ) async {
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      return null;
    }
    final repo = _precioRepository;
    final listas = await repo?.listarTodasListas() ?? [];
    final clientes = await listarClientes();
    final preciosLista =
        await repo?.listarPreciosProductoEnListas(productoId) ?? {};
    final preciosCliente =
        await repo?.listarPreciosProductoPorCliente(productoId) ?? [];
    return ResumenPreciosProducto(
      productoId: producto.id,
      nombreProducto: producto.nombre,
      costoUnitario: producto.costoUnitario,
      precioGenerico: producto.precioBase,
      precioMinimo: calcularPrecioMinimoVenta(producto.costoUnitario),
      preciosPorLista: preciosLista,
      preciosPorCliente: preciosCliente,
      nombresListas: {for (final l in listas) l.id: l.nombre},
      nombresClientes: {for (final c in clientes) c.id: c.nombre},
    );
  }

  Future<void> establecerPrecioProducto({
    required String productoId,
    required double precioUnitario,
    required AlcancePrecioVenta alcance,
    String? listaPreciosId,
    String? clienteId,
  }) async {
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }
    _validarPrecioVenta(precioUnitario, producto.costoUnitario);
    final precio = redondearMonto(precioUnitario);
    switch (alcance) {
      case AlcancePrecioVenta.generico:
        await actualizarProducto(producto.copiarCon(precioBase: precio));
      case AlcancePrecioVenta.listaPrecios:
        if (listaPreciosId == null || listaPreciosId.isEmpty) {
          throw StateError('Seleccione una lista de precios');
        }
        await guardarPrecioLista(listaPreciosId, productoId, precio);
      case AlcancePrecioVenta.clienteEspecifico:
        if (clienteId == null || clienteId.isEmpty) {
          throw StateError('Seleccione un cliente');
        }
        await guardarPrecioEspecialCliente(
          clienteId: clienteId,
          productoId: productoId,
          precioUnitario: precio,
        );
    }
  }

  void _validarPrecioVenta(double precioUnitario, double costoUnitario) {
    if (!precioVentaEsValido(precioUnitario, costoUnitario)) {
      throw StateError(mensajePrecioMinimoInvalido(costoUnitario));
    }
  }

  Future<void> eliminarListaPrecios(String listaId) async {
    await _precioRepository?.eliminarLista(listaId);
  }

  Future<List<Cliente>> listarClientesPorLista(String listaId) async {
    return _clienteRepository?.listarActivosPorLista(listaId) ?? [];
  }

  Future<List<ItemListaPrecios>> listarItemsListaPrecios(String listaId) async {
    final repo = _precioRepository;
    if (repo == null) {
      return [];
    }
    final precios = await repo.listarPreciosDeLista(listaId);
    final items = <ItemListaPrecios>[];
    for (final entry in precios.entries) {
      final producto = await _productoRepository.obtenerPorId(entry.key);
      if (producto == null || !producto.activo) {
        continue;
      }
      items.add(
        ItemListaPrecios(producto: producto, precioLista: entry.value),
      );
    }
    items.sort((a, b) => a.producto.nombre.compareTo(b.producto.nombre));
    return items;
  }

  Future<void> eliminarProductoDeLista(String listaId, String productoId) async {
    await _precioRepository?.eliminarPrecioDeLista(listaId, productoId);
  }

  Future<void> establecerFavoritoProducto(
    String productoId,
    bool favorito,
  ) async {
    await _productoRepository.establecerFavoritoCaja(productoId, favorito);
  }

  Future<void> _registrarEventoCategoria(Categoria categoria) async {
    final evento = SyncEvent(
      id: _generadorId.v4(),
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
    );
    await _syncOrchestrator.registrarEvento(evento);
  }

  Future<void> _registrarEventoVentaCompletada(Venta venta) async {
    final evento = SyncEvent(
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
    );
    await _syncOrchestrator.registrarEvento(evento);
  }

  Future<void> _registrarEventoAnulacion(Venta venta) async {
    final evento = SyncEvent(
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
    );
    await _syncOrchestrator.registrarEvento(evento);
  }

  Future<void> _registrarEventoTraspaso(
    Traspaso traspaso,
    TipoSyncEvento tipo, {
    String? almacenOrigenId,
    String? almacenDestinoId,
  }) async {
    final evento = SyncEvent(
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
    );
    await _syncOrchestrator.registrarEvento(evento);
  }

  Future<void> _registrarEventoTraspasoAlmacen({
    required String movimientoId,
    required String almacenOrigenId,
    String? almacenDestinoId,
    String? tiendaDestinoId,
    required List<LineaTraspasoSolicitud> lineas,
  }) async {
    final traspaso = Traspaso(
      id: movimientoId,
      tiendaOrigenId: '',
      tiendaDestinoId: tiendaDestinoId ?? '',
      estado: EstadoTraspaso.completado,
      solicitadoEn: DateTime.now().toUtc(),
      completadoEn: DateTime.now().toUtc(),
      notas: 'Movimiento de almacén',
      lineas: lineas
          .map(
            (l) => LineaTraspaso(
              productoId: l.productoId,
              nombreProducto: '',
              cantidadSolicitada: l.cantidad,
              cantidadRecibida: l.cantidad,
            ),
          )
          .toList(),
    );
    await _registrarEventoTraspaso(
      traspaso,
      TipoSyncEvento.transferCompleted,
      almacenOrigenId: almacenOrigenId,
      almacenDestinoId: almacenDestinoId,
    );
  }

  Future<void> _registrarEventoVariante(VarianteProducto variante) async {
    final evento = SyncEvent(
      id: _generadorId.v4(),
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
    String motivo, {
    required String tiendaId,
  }) async {
    final evento = SyncEvent(
      id: _generadorId.v4(),
      tiendaId: tiendaId,
      dispositivoId: _cajaId,
      tipo: TipoSyncEvento.stockAdjusted,
      payload: {'productoId': productoId, 'delta': delta, 'motivo': motivo},
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

  Future<HubSyncClient?> _clienteHubOpcional() async {
    final hubUrl = await _configRepository.obtenerHubUrl();
    if (hubUrl == null || hubUrl.trim().isEmpty) {
      return null;
    }
    final claveApi =
        await _configRepository.obtenerValor(claveConfigHubApiKey) ?? '';
    return HubSyncClient(urlBase: hubUrl.trim(), claveApi: claveApi);
  }

  /// Tras mutar usuarios, empuja a la nube y descarga cambios remotos.
  Future<void> _sincronizarInmediatoConHub() async {
    final hubUrl = await _configRepository.obtenerHubUrl();
    if (hubUrl == null || hubUrl.trim().isEmpty) {
      return;
    }
    await sincronizarManual();
  }

  /// Evita colisionar con cuentas ya provisionadas en el hub (p. ej. bootstrap).
  Future<String> _resolverCodigoUsuarioDisponible(
    UsuarioRepository repo,
    RolUsuario rol,
  ) async {
    final reservados = <String>{};
    var codigo = await repo.generarSiguienteCodigo(rol);
    final hub = await _clienteHubOpcional();
    if (hub == null || !await hub.verificarSalud()) {
      return codigo;
    }
    for (var intento = 0; intento < 99; intento++) {
      final ocupado = await hub.obtenerPerfilUsuario(codigo);
      if (ocupado == null) {
        return codigo;
      }
      reservados.add(ValidadorCodigoUsuario.normalizar(codigo));
      codigo = await repo.generarSiguienteCodigo(
        rol,
        codigosReservados: reservados,
      );
    }
    throw StateError('No hay codigos de usuario disponibles');
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
        'pinCredencial': snapshot.pinCredencial,
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
        'permiteStockNegativo': producto.permiteStockNegativo,
      },
      creadoEn: DateTime.now().toUtc(),
      estado: EstadoSyncEvento.pendiente,
    );
    await _syncOrchestrator.registrarEvento(evento);
  }

  // --- Almacenes ---

  Future<List<Almacen>> listarAlmacenes() async {
    final repo = _almacenRepository;
    if (repo == null) {
      return [];
    }
    final lista = await repo.listarTodos();
    if (lista.isEmpty) {
      await _sembrarAlmacenesIniciales();
      return repo.listarTodos();
    }
    return lista;
  }

  Future<void> _sembrarAlmacenesIniciales() async {
    final repo = _almacenRepository;
    if (repo == null) {
      return;
    }
    final nombres = ['Almacén Central', 'Almacén Norte', 'Almacén Sur'];
    for (var i = 0; i < nombres.length; i++) {
      await repo.guardar(
        Almacen(
          id: 'alm-${i + 1}',
          nombre: nombres[i],
          activo: true,
        ),
      );
    }
  }

  Future<Almacen> registrarAlmacen(String nombre, {String? tiendaId}) async {
    final repo = _almacenRepository;
    if (repo == null) {
      throw StateError('Almacenes no disponibles');
    }
    final almacen = Almacen(
      id: _generadorId.v4(),
      nombre: nombre.trim(),
      tiendaId: tiendaId,
      activo: true,
    );
    await repo.guardar(almacen);
    await _registrarEventoAlmacen(almacen);
    return almacen;
  }

  Future<void> traspasarAlmacenATienda({
    required String almacenId,
    required String tiendaDestinoId,
    required String productoId,
    required double cantidad,
  }) async {
    final almacenRepo = _almacenRepository;
    if (almacenRepo == null) {
      throw StateError('Almacenes no disponibles');
    }
    final stock = await almacenRepo.obtenerStock(productoId, almacenId);
    final anterior = stock?.cantidad ?? 0.0;
    if (anterior < cantidad) {
      throw StateError('Stock insuficiente en almacén');
    }
    final ahora = DateTime.now().toUtc();
    await _enTransaccion((tx) async {
      final stockAlmacen = await almacenRepo.obtenerStock(
        productoId,
        almacenId,
        db: tx,
      );
      final anteriorAlmacen = stockAlmacen?.cantidad ?? anterior;
      await almacenRepo.guardarStock(
        StockAlmacen(
          productoId: productoId,
          almacenId: almacenId,
          cantidad: anteriorAlmacen - cantidad,
          actualizadoEn: ahora,
          stockMinimo: stockAlmacen?.stockMinimo ?? stock?.stockMinimo ?? 0,
        ),
        db: tx,
      );
      final stockTienda = await _inventarioRepository.obtenerStock(
        productoId,
        tiendaDestinoId,
        db: tx,
      );
      await _inventarioRepository.guardarStock(
        StockNivel(
          productoId: productoId,
          tiendaId: tiendaDestinoId,
          cantidad: (stockTienda?.cantidad ?? 0) + cantidad,
          actualizadoEn: ahora,
          stockMinimo: stockTienda?.stockMinimo ?? 0,
        ),
        db: tx,
      );
    });
  }

  /// Resumen de existencias por almacén activo.
  Future<List<ResumenStockAlmacen>> obtenerResumenAlmacenes() async {
    final almacenRepo = _almacenRepository;
    if (almacenRepo == null) {
      return [];
    }
    final almacenes = await almacenRepo.listarActivos();
    final resumenes = <ResumenStockAlmacen>[];
    for (final almacen in almacenes) {
      final stocks = await almacenRepo.listarStockPorAlmacen(almacen.id);
      var productos = 0;
      var unidades = 0.0;
      for (final stock in stocks) {
        if (stock.cantidad <= 0) {
          continue;
        }
        productos++;
        unidades += stock.cantidad;
      }
      resumenes.add(
        ResumenStockAlmacen(
          almacenId: almacen.id,
          nombreAlmacen: almacen.nombre,
          productosConStock: productos,
          totalUnidades: redondearMonto(unidades),
        ),
      );
    }
    return resumenes;
  }

  /// Inventario detallado de un almacén (productos con cantidad).
  Future<List<StockPorAlmacen>> obtenerInventarioAlmacen(String almacenId) async {
    final almacenRepo = _almacenRepository;
    if (almacenRepo == null) {
      return [];
    }
    final almacen = await almacenRepo.obtenerPorId(almacenId);
    if (almacen == null) {
      throw StateError('Almacén no encontrado');
    }
    final stocks = await almacenRepo.listarStockPorAlmacen(almacenId);
    final resultado = <StockPorAlmacen>[];
    for (final stock in stocks) {
      if (stock.cantidad <= 0) {
        continue;
      }
      final producto = await _productoRepository.obtenerPorId(stock.productoId);
      if (producto == null || !producto.activo) {
        continue;
      }
      resultado.add(
        StockPorAlmacen(
          productoId: stock.productoId,
          nombreProducto: producto.nombre,
          almacenId: almacenId,
          nombreAlmacen: almacen.nombre,
          cantidad: stock.cantidad,
          actualizadoEn: stock.actualizadoEn,
          stockMinimo: stock.stockMinimo,
        ),
      );
    }
    resultado.sort((a, b) => a.nombreProducto.compareTo(b.nombreProducto));
    return resultado;
  }

  /// Ajusta existencias en almacén (entrada, salida o ajuste a cantidad fija).
  Future<void> ajustarStockAlmacen({
    required String productoId,
    required String almacenId,
    required TipoMovimientoInventario tipo,
    required double cantidad,
  }) async {
    final almacenRepo = _almacenRepository;
    if (almacenRepo == null) {
      throw StateError('Almacenes no disponibles');
    }
    final almacen = await almacenRepo.obtenerPorId(almacenId);
    if (almacen == null) {
      throw StateError('Almacén no encontrado');
    }
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }
    if (cantidad < 0) {
      throw StateError('La cantidad no puede ser negativa');
    }
    final stockActual = await almacenRepo.obtenerStock(productoId, almacenId);
    final anterior = stockActual?.cantidad ?? 0.0;
    late double nuevo;
    if (tipo == TipoMovimientoInventario.ajuste) {
      nuevo = cantidad;
    } else if (tipo == TipoMovimientoInventario.salida) {
      if (anterior < cantidad) {
        throw StateError('Stock insuficiente en almacén');
      }
      nuevo = anterior - cantidad;
    } else {
      nuevo = anterior + cantidad;
    }
    final ahora = DateTime.now().toUtc();
    await almacenRepo.guardarStock(
      StockAlmacen(
        productoId: productoId,
        almacenId: almacenId,
        cantidad: nuevo,
        actualizadoEn: ahora,
        stockMinimo: stockActual?.stockMinimo ?? 0,
      ),
    );
  }

  /// Productos con existencia en un almacen.
  Future<List<({Producto producto, double cantidad})>> listarProductosConStockAlmacen(
    String almacenId,
  ) async {
    final almacenRepo = _almacenRepository;
    if (almacenRepo == null) {
      return [];
    }
    final stocks = await almacenRepo.listarStockPorAlmacen(almacenId);
    final resultado = <({Producto producto, double cantidad})>[];
    for (final stock in stocks) {
      if (stock.cantidad <= 0) {
        continue;
      }
      final producto = await _productoRepository.obtenerPorId(stock.productoId);
      if (producto != null && producto.activo) {
        resultado.add((producto: producto, cantidad: stock.cantidad));
      }
    }
    resultado.sort(
      (a, b) => a.producto.nombre.compareTo(b.producto.nombre),
    );
    return resultado;
  }

  Future<void> traspasarAlmacenATiendaMultiple({
    required String almacenId,
    required String tiendaDestinoId,
    required List<LineaTraspasoSolicitud> lineas,
  }) async {
    final movimientoId = _generadorId.v4();
    await _enTransaccion((tx) async {
      for (final linea in lineas) {
        if (linea.cantidad <= 0) {
          continue;
        }
        final almacenRepo = _almacenRepository;
        if (almacenRepo == null) {
          throw StateError('Almacenes no disponibles');
        }
        final stock = await almacenRepo.obtenerStock(
          linea.productoId,
          almacenId,
          db: tx,
        );
        final anterior = stock?.cantidad ?? 0.0;
        if (anterior < linea.cantidad) {
          throw StateError('Stock insuficiente en almacén');
        }
        final ahora = DateTime.now().toUtc();
        await almacenRepo.guardarStock(
          StockAlmacen(
            productoId: linea.productoId,
            almacenId: almacenId,
            cantidad: anterior - linea.cantidad,
            actualizadoEn: ahora,
            stockMinimo: stock?.stockMinimo ?? 0,
          ),
          db: tx,
        );
        final stockTienda = await _inventarioRepository.obtenerStock(
          linea.productoId,
          tiendaDestinoId,
          db: tx,
        );
        await _inventarioRepository.guardarStock(
          StockNivel(
            productoId: linea.productoId,
            tiendaId: tiendaDestinoId,
            cantidad: (stockTienda?.cantidad ?? 0) + linea.cantidad,
            actualizadoEn: ahora,
            stockMinimo: stockTienda?.stockMinimo ?? 0,
          ),
          db: tx,
        );
      }
    });
    await _registrarEventoTraspasoAlmacen(
      movimientoId: movimientoId,
      almacenOrigenId: almacenId,
      tiendaDestinoId: tiendaDestinoId,
      lineas: lineas,
    );
  }

  Future<void> traspasarAlmacenAAlmacenMultiple({
    required String almacenOrigenId,
    required String almacenDestinoId,
    required List<LineaTraspasoSolicitud> lineas,
  }) async {
    if (almacenOrigenId == almacenDestinoId) {
      throw StateError('El almacén origen y destino deben ser distintos');
    }
    final movimientoId = _generadorId.v4();
    await _enTransaccion((tx) async {
      final almacenRepo = _almacenRepository;
      if (almacenRepo == null) {
        throw StateError('Almacenes no disponibles');
      }
      for (final linea in lineas) {
        if (linea.cantidad <= 0) {
          continue;
        }
        final stockOrigen = await almacenRepo.obtenerStock(
          linea.productoId,
          almacenOrigenId,
          db: tx,
        );
        final anteriorOrigen = stockOrigen?.cantidad ?? 0.0;
        if (anteriorOrigen < linea.cantidad) {
          throw StateError('Stock insuficiente en almacén origen');
        }
        final ahora = DateTime.now().toUtc();
        await almacenRepo.guardarStock(
          StockAlmacen(
            productoId: linea.productoId,
            almacenId: almacenOrigenId,
            cantidad: anteriorOrigen - linea.cantidad,
            actualizadoEn: ahora,
            stockMinimo: stockOrigen?.stockMinimo ?? 0,
          ),
          db: tx,
        );
        final stockDestino = await almacenRepo.obtenerStock(
          linea.productoId,
          almacenDestinoId,
          db: tx,
        );
        await almacenRepo.guardarStock(
          StockAlmacen(
            productoId: linea.productoId,
            almacenId: almacenDestinoId,
            cantidad: (stockDestino?.cantidad ?? 0) + linea.cantidad,
            actualizadoEn: ahora,
            stockMinimo: stockDestino?.stockMinimo ?? 0,
          ),
          db: tx,
        );
      }
    });
    await _registrarEventoTraspasoAlmacen(
      movimientoId: movimientoId,
      almacenOrigenId: almacenOrigenId,
      almacenDestinoId: almacenDestinoId,
      lineas: lineas,
    );
  }

  Future<void> _registrarEventoAlmacen(Almacen almacen) async {
    await _syncOrchestrator.registrarEvento(
      SyncEvent(
        id: _generadorId.v4(),
        tiendaId: _tiendaActivaId,
        dispositivoId: _cajaId,
        tipo: TipoSyncEvento.warehouseUpserted,
        payload: {
          'id': almacen.id,
          'nombre': almacen.nombre,
          'tiendaId': almacen.tiendaId,
          'activo': almacen.activo,
        },
        creadoEn: DateTime.now().toUtc(),
        estado: EstadoSyncEvento.pendiente,
      ),
    );
  }

  // --- Presentaciones ---

  Future<List<TipoPresentacion>> listarTiposPresentacion() async {
    return _presentacionRepository?.listarTodosTipos() ?? [];
  }

  Future<TipoPresentacion> registrarTipoPresentacion({
    required String nombre,
    required String unidad,
  }) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      throw StateError('Presentaciones no disponibles');
    }
    final tipo = TipoPresentacion(
      id: _generadorId.v4(),
      nombre: nombre.trim(),
      unidad: unidad,
      activo: true,
    );
    await repo.guardarTipo(tipo);
    return tipo;
  }

  Future<List<PresentacionProducto>> listarPresentacionesProducto(
    String productoId,
  ) async {
    return _presentacionRepository?.listarPorProducto(productoId) ?? [];
  }

  Future<PresentacionProducto> guardarPresentacionProducto({
    String? id,
    required String productoId,
    required String nombre,
    required double factorABase,
    String? tipoPresentacionId,
    String? codigoBarras,
    double? precio,
    bool esPresentacionBase = false,
  }) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      throw StateError('Presentaciones no disponibles');
    }
    if (precio != null) {
      final producto = await _productoRepository.obtenerPorId(productoId);
      if (producto != null &&
          !precioPresentacionEsValido(
            precio,
            producto.costoUnitario,
            factorABase,
          )) {
        throw StateError(
          mensajePrecioMinimoPresentacionInvalido(
            producto.costoUnitario,
            factorABase,
          ),
        );
      }
    }
    if (id != null) {
      final existente = await repo.obtenerPorId(id);
      if (existente == null) {
        throw StateError('Presentación no encontrada');
      }
      if (existente.esPresentacionBase && factorABase != existente.factorABase) {
        throw StateError('No se puede cambiar el factor de la unidad base');
      }
    }
    final presentacion = PresentacionProducto(
      id: id ?? _generadorId.v4(),
      productoId: productoId,
      tipoPresentacionId: tipoPresentacionId,
      nombre: nombre.trim(),
      factorABase: factorABase,
      esPresentacionBase: esPresentacionBase,
      codigoBarras: codigoBarras ?? '',
      precio: precio,
      activo: true,
    );
    await repo.guardarPresentacion(presentacion);
    return presentacion;
  }

  Future<void> eliminarPresentacionProducto(String presentacionId) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      throw StateError('Presentaciones no disponibles');
    }
    final existente = await repo.obtenerPorId(presentacionId);
    if (existente == null) {
      throw StateError('Presentación no encontrada');
    }
    if (existente.esPresentacionBase) {
      throw StateError('No se puede eliminar la unidad base');
    }
    await repo.guardarPresentacion(existente.copiarWith(activo: false));
  }

  Future<void> asegurarPresentacionBase(
    Producto producto, {
    DatabaseExecutor? db,
  }) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      return;
    }
    final existentes = await repo.listarPorProducto(producto.id);
    if (existentes.any((p) => p.esPresentacionBase)) {
      return;
    }
    await repo.guardarPresentacion(
      PresentacionProducto(
        id: _generadorId.v4(),
        productoId: producto.id,
        nombre: 'Unidad base',
        factorABase: 1,
        esPresentacionBase: true,
        precio: producto.precioBase,
        activo: true,
      ),
      db: db,
    );
    if (producto.piezasPorCaja != null && producto.piezasPorCaja! > 1) {
      await repo.guardarPresentacion(
        PresentacionProducto(
          id: _generadorId.v4(),
          productoId: producto.id,
          tipoPresentacionId: 'tp-caja',
          nombre: 'Caja x${producto.piezasPorCaja}',
          factorABase: producto.piezasPorCaja!.toDouble(),
          esPresentacionBase: false,
          precio: producto.precioBase * producto.piezasPorCaja!,
          activo: true,
        ),
        db: db,
      );
    }
  }
}
