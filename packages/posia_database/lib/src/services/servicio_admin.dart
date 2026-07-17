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

import '../database/posia_local_database.dart';
import '../models/alta_producto_request.dart';
import '../models/alerta_faltante.dart';
import '../models/config_dispositivo.dart';
import '../models/config_impresora.dart';
import '../models/estado_sync_admin.dart';
import '../models/asignacion_compra_solicitud.dart';
import '../models/linea_compra_solicitud.dart';
import '../models/linea_pedido_solicitud.dart';
import '../models/linea_traspaso_solicitud.dart';
import '../models/item_lista_precios.dart';
import '../models/resumen_precios_producto.dart';
import '../models/resultado_importacion_productos.dart';
import '../models/resumen_vendedor.dart';
import '../models/resumen_ventas_dia.dart';
import '../models/stock_por_tienda.dart';
import '../models/stock_por_almacen.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/combo_repository.dart';
import '../repositories/compra_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_promocion_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/presentacion_repository.dart';
import '../repositories/sync_event_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../repositories/venta_repository.dart';
import '../repositories/almacen_repository.dart';
import '../repositories/rol_personalizado_repository.dart';
import '../repositories/sync_state_repository.dart';
import '../utils/limpiador_base_local.dart';
import '../utils/sincronizador_vendedor_usuario.dart';
import '../models/resultado_reconciliacion_hub.dart';
import '../services/servicio_reconciliacion_hub.dart';
import '../sync/admin_emisor_eventos_sync.dart';
import 'admin_almacenes.dart';
import 'admin_catalogo_productos.dart';
import 'admin_categorias.dart';
import 'admin_clientes.dart';
import 'admin_compras.dart';
import 'admin_inventario_movimientos.dart';
import 'admin_listas_precios.dart';
import 'admin_pedidos_cotizaciones.dart';
import 'admin_promociones.dart';
import 'admin_proveedores.dart';
import 'admin_reportes.dart';
import 'admin_traspasos.dart';
import 'admin_vendedores.dart';
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
    LotePromocionRepository? lotePromocionRepository,
    ComboRepository? comboRepository,
    RolPersonalizadoRepository? rolPersonalizadoRepository,
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
       _clienteRepository = clienteRepository,
       _descuentoClienteRepository = descuentoClienteRepository,
       _vendedorRepository = vendedorRepository,
       _usuarioRepository = usuarioRepository,
       _compraRepository = compraRepository,
       _pedidoRepository = pedidoRepository,
       _cotizacionRepository = cotizacionRepository,
       _precioRepository = precioRepository,
       _traspasoRepository = traspasoRepository,
       _almacenRepository = almacenRepository,
       _presentacionRepository = presentacionRepository,
       _lotePromocionRepository =
           lotePromocionRepository ??
           LotePromocionRepository(baseDatos: baseDatos),
       _comboRepository = comboRepository ?? ComboRepository(baseDatos: baseDatos),
       _rolPersonalizadoRepository = rolPersonalizadoRepository,
       _servicioCorteCaja = servicioCorteCaja,
       _baseDatos = baseDatos,
       _tiendaActivaId = tiendaActivaId,
       _cajaId = cajaId,
       _emisorEventos = AdminEmisorEventosSync(
         syncOrchestrator: syncOrchestrator,
         tiendaActivaId: tiendaActivaId,
         cajaId: cajaId,
       ) {
    _catalogoProductos = AdminCatalogoProductos(
      productoRepository: productoRepository,
      inventarioRepository: inventarioRepository,
      tiendaRepository: tiendaRepository,
      lotePromocionRepository: _lotePromocionRepository,
      emisorEventos: _emisorEventos,
      baseDatos: baseDatos,
      tiendaActivaId: tiendaActivaId,
      precioRepository: precioRepository,
      presentacionRepository: presentacionRepository,
      varianteRepository: varianteRepository,
      almacenRepository: almacenRepository,
    );
    _almacenes = AdminAlmacenes(
      productoRepository: productoRepository,
      emisorEventos: _emisorEventos,
      almacenRepository: almacenRepository,
    );
    _proveedores = AdminProveedores(
      emisorEventos: _emisorEventos,
      proveedorRepository: proveedorRepository,
      compraRepository: compraRepository,
    );
    _clientes = AdminClientes(
      productoRepository: productoRepository,
      ventaRepository: ventaRepository,
      emisorEventos: _emisorEventos,
      catalogoProductos: _catalogoProductos,
      tiendaActivaId: tiendaActivaId,
      clienteRepository: clienteRepository,
      descuentoClienteRepository: descuentoClienteRepository,
      precioRepository: precioRepository,
      pedidoRepository: pedidoRepository,
      cotizacionRepository: cotizacionRepository,
    );
    _compras = AdminCompras(
      productoRepository: productoRepository,
      inventarioRepository: inventarioRepository,
      emisorEventos: _emisorEventos,
      almacenes: _almacenes,
      baseDatos: baseDatos,
      compraRepository: compraRepository,
      proveedorRepository: proveedorRepository,
      almacenRepository: almacenRepository,
      movimientoRepository: movimientoRepository,
    );
    _pedidosCotizaciones = AdminPedidosCotizaciones(
      emisorEventos: _emisorEventos,
      tiendaActivaId: tiendaActivaId,
      pedidoRepository: pedidoRepository,
      cotizacionRepository: cotizacionRepository,
      usuarioRepository: usuarioRepository,
    );
    _traspasos = AdminTraspasos(
      productoRepository: productoRepository,
      inventarioRepository: inventarioRepository,
      emisorEventos: _emisorEventos,
      baseDatos: baseDatos,
      tiendaActivaId: tiendaActivaId,
      traspasoRepository: traspasoRepository,
      movimientoRepository: movimientoRepository,
    );
    _categorias = AdminCategorias(
      emisorEventos: _emisorEventos,
      categoriaRepository: categoriaRepository,
    );
    _vendedores = AdminVendedores(vendedorRepository: vendedorRepository);
    _reportes = AdminReportes(
      ventaRepository: ventaRepository,
      vendedores: _vendedores,
    );
    _listasPrecios = AdminListasPrecios(
      productoRepository: productoRepository,
      emisorEventos: _emisorEventos,
      catalogoProductos: _catalogoProductos,
      clientes: _clientes,
      precioRepository: precioRepository,
      clienteRepository: clienteRepository,
    );
    _inventarioMovimientos = AdminInventarioMovimientos(
      inventarioRepository: inventarioRepository,
      productoRepository: productoRepository,
      tiendaRepository: tiendaRepository,
      emisorEventos: _emisorEventos,
      baseDatos: baseDatos,
      tiendaActivaId: tiendaActivaId,
      movimientoRepository: movimientoRepository,
    );
    _promociones = AdminPromociones(
      lotePromocionRepository: _lotePromocionRepository,
      comboRepository: _comboRepository,
      emisorEventos: _emisorEventos,
      syncOrchestrator: syncOrchestrator,
      productoRepository: productoRepository,
      varianteRepository: varianteRepository,
    );
  }

  final TiendaRepository _tiendaRepository;
  final VentaRepository _ventaRepository;
  final ProductoRepository _productoRepository;
  final InventarioRepository _inventarioRepository;
  final SyncEventRepository _syncEventRepository;
  final SyncOrchestrator _syncOrchestrator;
  final ConfigRepository _configRepository;
  final ClienteRepository? _clienteRepository;
  final DescuentoClienteRepository? _descuentoClienteRepository;
  final VendedorRepository? _vendedorRepository;
  final UsuarioRepository? _usuarioRepository;
  final CompraRepository? _compraRepository;
  final PedidoRepository? _pedidoRepository;
  final CotizacionRepository? _cotizacionRepository;
  final PrecioRepository? _precioRepository;
  final TraspasoRepository? _traspasoRepository;
  final AlmacenRepository? _almacenRepository;
  final PresentacionRepository? _presentacionRepository;
  final LotePromocionRepository _lotePromocionRepository;
  final ComboRepository _comboRepository;
  final RolPersonalizadoRepository? _rolPersonalizadoRepository;
  final ServicioCorteCaja? _servicioCorteCaja;
  final Database _baseDatos;
  final String _tiendaActivaId;
  final String _cajaId;
  final Uuid _generadorId = const Uuid();
  final AdminEmisorEventosSync _emisorEventos;
  late final AdminCatalogoProductos _catalogoProductos;
  late final AdminAlmacenes _almacenes;
  late final AdminProveedores _proveedores;
  late final AdminClientes _clientes;
  late final AdminCompras _compras;
  late final AdminPedidosCotizaciones _pedidosCotizaciones;
  late final AdminTraspasos _traspasos;
  late final AdminCategorias _categorias;
  late final AdminVendedores _vendedores;
  late final AdminReportes _reportes;
  late final AdminListasPrecios _listasPrecios;
  late final AdminInventarioMovimientos _inventarioMovimientos;
  late final AdminPromociones _promociones;
  MotorPrecio? _motorPrecioCache;

  MotorPrecio? get _motorPrecio {
    final repo = _precioRepository;
    if (repo == null) {
      return null;
    }
    return _motorPrecioCache ??= MotorPrecio(repositorioPrecio: repo);
  }

  /// Resuelve precio comercial con listas, mayoreo y cliente.
  Future<ResultadoPrecio> resolverPrecioComercial({
    required Producto producto,
    required double cantidad,
    Cliente? cliente,
  }) async {
    final motor = _motorPrecio;
    if (motor == null) {
      return ResultadoPrecio(
        precioUnitario: producto.precioBase,
        reglaAplicada: ReglaPrecio.precioBase,
      );
    }
    return motor.resolverPrecio(
      ContextoPrecio(
        producto: producto,
        cantidad: cantidad,
        tiendaId: _tiendaActivaId,
        cliente: cliente,
        canal: _canalVentaProducto(producto),
      ),
    );
  }

  /// Resuelve precio comercial por identificadores de producto y cliente.
  Future<ResultadoPrecio> resolverPrecioComercialPorId({
    required String productoId,
    required double cantidad,
    String? clienteId,
  }) async {
    final producto = await _productoRepository.obtenerPorId(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }
    Cliente? cliente;
    if (clienteId != null) {
      cliente = await _clienteRepository?.obtenerPorId(clienteId);
    }
    return resolverPrecioComercial(
      producto: producto,
      cantidad: cantidad,
      cliente: cliente,
    );
  }

  CanalVenta _canalVentaProducto(Producto producto) {
    return producto.moduloVertical == ModuloVertical.carniceria
        ? CanalVenta.mayoreo
        : CanalVenta.mostrador;
  }

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
  Future<List<Producto>> listarProductos() {
    return _catalogoProductos.listarProductos();
  }

  Future<List<Producto>> listarProductosActivosPorTienda(String tiendaId) {
    return _catalogoProductos.listarProductosActivosPorTienda(tiendaId);
  }

  /// Lista catalogo completo incluyendo inactivos (admin).
  Future<List<Producto>> listarProductosCatalogo() {
    return _catalogoProductos.listarProductosCatalogo();
  }

  Future<Producto?> obtenerProducto(String productoId) {
    return _catalogoProductos.obtenerProducto(productoId);
  }

  Future<List<EscalaMayoreo>> listarEscalasMayoreo(String productoId) {
    return _catalogoProductos.listarEscalasMayoreo(productoId);
  }

  Future<Producto> registrarProductoCompleto(AltaProductoRequest req) async {
    final producto = await _catalogoProductos.registrarProductoCompleto(req);
    await sincronizarPresentacionesProducto(producto.id);
    return producto;
  }

  /// Importa varios productos en secuencia reutilizando validaciones de alta individual.
  Future<ResultadoImportacionProductos> importarProductosLote(
    List<({int numeroFila, AltaProductoRequest solicitud})> filas, {
    void Function(int actual, int total)? alProgreso,
  }) async {
    final errores = <ErrorImportacionProducto>[];
    var importados = 0;
    final total = filas.length;
    final miembrosPorLote = <String, List<String>>{};
    final metaPorLote =
        <String, ({double cantidadMinima, double precioUnitario})>{};
    final categoriasCreadas = <String, String>{};

    for (var i = 0; i < total; i++) {
      alProgreso?.call(i + 1, total);
      final fila = filas[i];
      try {
        final solicitud = await _resolverCategoriaImportacion(
          fila.solicitud,
          categoriasCreadas: categoriasCreadas,
        );
        final producto = await registrarProductoCompleto(solicitud);
        importados++;
        final codigoLote = solicitud.lotePromocionCodigo?.trim();
        if (codigoLote != null && codigoLote.isNotEmpty) {
          final piezas = solicitud.piezasPorCaja;
          final precioCaja = solicitud.precioCaja;
          if (piezas == null ||
              piezas <= 0 ||
              precioCaja == null ||
              precioCaja <= 0) {
            throw StateError(
              'Lote promocion "$codigoLote" requiere piezas_caja y precio_caja',
            );
          }
          final precioUnitario = redondearMonto(precioCaja / piezas);
          final meta = metaPorLote[codigoLote];
          if (meta != null) {
            if (meta.cantidadMinima != piezas.toDouble() ||
                meta.precioUnitario != precioUnitario) {
              throw StateError(
                'Lote promocion "$codigoLote" tiene piezas/precio inconsistentes',
              );
            }
          } else {
            metaPorLote[codigoLote] = (
              cantidadMinima: piezas.toDouble(),
              precioUnitario: precioUnitario,
            );
          }
          miembrosPorLote.putIfAbsent(codigoLote, () => []).add(producto.id);
        }
      } catch (e) {
        errores.add(
          ErrorImportacionProducto(
            numeroFila: fila.numeroFila,
            nombre: fila.solicitud.nombre,
            mensaje: e is StateError ? e.message : e.toString(),
          ),
        );
      }
    }

    for (final entrada in miembrosPorLote.entries) {
      final meta = metaPorLote[entrada.key];
      if (meta == null || entrada.value.isEmpty) {
        continue;
      }
      try {
        await _promociones.registrarLoteDesdeImportacion(
          codigoExterno: entrada.key,
          cantidadMinima: meta.cantidadMinima,
          precioUnitario: meta.precioUnitario,
          productoIds: entrada.value,
        );
      } catch (e) {
        errores.add(
          ErrorImportacionProducto(
            numeroFila: 0,
            nombre: 'Lote promocion ${entrada.key}',
            mensaje: e is StateError ? e.message : e.toString(),
          ),
        );
      }
    }

    return ResultadoImportacionProductos(
      importados: importados,
      errores: errores,
    );
  }

  /// Lista lotes de promoción (mayoreo cruzado entre productos).
  Future<List<LotePromocion>> listarLotesPromocion() =>
      _promociones.listarLotesPromocion();

  /// Obtiene un lote de promoción por id.
  Future<LotePromocion?> obtenerLotePromocion(String id) =>
      _promociones.obtenerLotePromocion(id);

  /// Sugiere miembros para un lote a partir de la familia de un producto
  /// (el producto mismo más sus variantes activas).
  Future<List<MiembroPromocion>> sugerirMiembrosDeFamilia(String productoPadreId) =>
      _promociones.sugerirMiembrosDeFamilia(productoPadreId);

  /// Resuelve nombres para mostrar de una lista de ids miembro.
  Future<List<MiembroPromocion>> nombresDeMiembrosPromocion(List<String> productoIds) =>
      _promociones.nombresDeMiembros(productoIds);

  /// Crea o actualiza un lote de promoción desde la UI de administración.
  Future<LotePromocion> guardarLotePromocion({
    String? id,
    required String nombre,
    required double cantidadMinima,
    required double precioUnitario,
    required List<String> productoIds,
    bool activo = true,
  }) => _promociones.guardarLotePromocion(
    id: id,
    nombre: nombre,
    cantidadMinima: cantidadMinima,
    precioUnitario: precioUnitario,
    productoIds: productoIds,
    activo: activo,
  );

  /// Desactiva un lote de promoción (baja lógica).
  Future<void> eliminarLotePromocion(String id) =>
      _promociones.eliminarLotePromocion(id);

  /// Lista combos de precio fijo (llevar productos distintos).
  Future<List<Combo>> listarCombos() => _promociones.listarCombos();

  /// Obtiene un combo por id.
  Future<Combo?> obtenerCombo(String id) => _promociones.obtenerCombo(id);

  /// Crea o actualiza un combo de precio fijo desde la UI de administración.
  Future<Combo> guardarCombo({
    String? id,
    required String nombre,
    required double precioCombo,
    required List<ComboMiembro> miembros,
    bool activo = true,
  }) => _promociones.guardarCombo(
    id: id,
    nombre: nombre,
    precioCombo: precioCombo,
    miembros: miembros,
    activo: activo,
  );

  /// Desactiva un combo (baja lógica).
  Future<void> eliminarCombo(String id) => _promociones.eliminarCombo(id);

  Future<Producto> actualizarProducto(
    Producto producto, {
    List<EscalaMayoreo>? escalasMayoreo,
  }) {
    return _catalogoProductos.actualizarProducto(
      producto,
      escalasMayoreo: escalasMayoreo,
    );
  }

  Future<bool> eliminarProducto(String productoId) {
    return _catalogoProductos.eliminarProducto(productoId);
  }

  Future<bool> reactivarProducto(String productoId) {
    return _catalogoProductos.reactivarProducto(productoId);
  }

  Future<bool> eliminarProductoPermanente(String productoId) {
    return _catalogoProductos.eliminarProductoPermanente(productoId);
  }

  Future<List<Producto>> listarProductosPorProveedor(String proveedorId) {
    return _catalogoProductos.listarProductosPorProveedor(proveedorId);
  }

  /// Busca producto activo por codigo de barras en la tienda actual.
  Future<Producto?> buscarProductoPorCodigoBarras(String codigoBarras) {
    return _catalogoProductos.buscarProductoPorCodigoBarras(codigoBarras);
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
  }) {
    return _catalogoProductos.registrarProducto(
      nombre: nombre,
      codigoBarras: codigoBarras,
      precioBase: precioBase,
    );
  }

  /// Obtiene inventario consolidado de todas las tiendas activas.
  ///
  /// Retorna lista de existencias por producto y sucursal.
  Future<List<StockPorTienda>> obtenerInventarioConsolidado() {
    return _catalogoProductos.obtenerInventarioConsolidado();
  }

  /// Agrupa existencias por producto con totales por tienda y almacén.
  Future<List<InventarioAgrupado>> obtenerInventarioAgrupado({
    String? tiendaReferenciaId,
  }) {
    return _catalogoProductos.obtenerInventarioAgrupado(
      tiendaReferenciaId: tiendaReferenciaId,
    );
  }

  /// Existencias de un producto en todas las tiendas y almacenes.
  Future<InventarioAgrupado?> obtenerExistenciasProducto(
    String productoId, {
    String? tiendaReferenciaId,
  }) {
    return _catalogoProductos.obtenerExistenciasProducto(
      productoId,
      tiendaReferenciaId: tiendaReferenciaId,
    );
  }

  /// Garantiza que el producto tenga una presentación base antes de operar
  /// en caja. Delegado a [_catalogoProductos]; usado también por traspasos.
  Future<void> asegurarPresentacionBase(
    Producto producto, {
    DatabaseExecutor? db,
  }) {
    return _catalogoProductos.asegurarPresentacionBase(producto, db: db);
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
  /// [incluirCatalogo] Si es true, reencola el catalogo local espejado en Neon
  /// antes de enviar. Se omite automaticamente si la cola ya esta saturada
  /// (p. ej. tras pulsar "Sincronizar" muchas veces).
  Future<ResultadoSync> sincronizarManual({
    ReporteProgresoSync? alProgreso,
    bool incluirCatalogo = true,
  }) async {
    alProgreso?.call(
      const ProgresoSync(
        fase: FaseProgresoSync.preparar,
        indice: 0,
        total: 0,
        mensaje: 'Colapsando catálogo duplicado en cola…',
      ),
    );
    // Solo elimina versiones viejas del mismo producto/entidad; conserva el
    // pendiente mas reciente (p. ej. empaques recien guardados) para subirlo.
    final colapsados = await _syncEventRepository.colapsarDuplicadosCatalogo();
    if (colapsados > 0) {
      alProgreso?.call(
        ProgresoSync(
          fase: FaseProgresoSync.preparar,
          indice: 0,
          total: 0,
          mensaje: 'Colapsados $colapsados eventos de catálogo duplicados…',
        ),
      );
    }

    final pendientes = await _syncEventRepository.contarPendientes();
    final debeReencolar =
        incluirCatalogo && pendientes < UMBRAL_NO_REENCOLAR_CATALOGO;
    if (debeReencolar) {
      alProgreso?.call(
        const ProgresoSync(
          fase: FaseProgresoSync.preparar,
          indice: 0,
          total: 0,
          mensaje: 'Preparando catálogo local para la nube…',
        ),
      );
      await _reencolarCatalogoLocalPendiente(alProgreso: alProgreso);
    } else if (incluirCatalogo && pendientes >= UMBRAL_NO_REENCOLAR_CATALOGO) {
      alProgreso?.call(
        ProgresoSync(
          fase: FaseProgresoSync.preparar,
          indice: 0,
          total: 0,
          mensaje:
              'Cola local alta ($pendientes): se omite reencolar catálogo…',
        ),
      );
    }
    final resultado = await _syncOrchestrator.sincronizarCompleto(
      alProgreso: alProgreso,
    );
    await PosiaLocalDatabase.obtenerInstancia()
        .completarMigracionIntegridadTrasSync();
    return resultado;
  }

  /// Acción EXPLÍCITA de recuperación: re-sube el catálogo local completo a
  /// Neon. NO debe llamarse en el sync periódico (satura la cola). Úsese solo
  /// para sembrar un Neon vacío o forzar una re-subida manual desde un
  /// dispositivo que es fuente de verdad del catálogo.
  Future<ResultadoSync> resubirCatalogoCompleto({
    ReporteProgresoSync? alProgreso,
  }) async {
    await _reencolarCatalogoLocalPendiente(alProgreso: alProgreso);
    final resultado = await _syncOrchestrator.sincronizarCompleto(
      alProgreso: alProgreso,
    );
    await PosiaLocalDatabase.obtenerInstancia()
        .completarMigracionIntegridadTrasSync();
    return resultado;
  }

  /// Acción EXPLÍCITA de recuperación: descarta de la cola local (pendiente o
  /// error) los eventos de catálogo espejo — obsoletos ahora que el catálogo
  /// ya no se re-sube automáticamente (ver [resubirCatalogoCompleto]). NO
  /// toca ventas, compras, movimientos, asistencia ni nómina: esos siguen en
  /// cola hasta subir. Pensado para vaciar colas que quedaron atoradas con
  /// cientos de reencolados de catálogo antes de este fix.
  Future<int> descartarCatalogoEnCola() {
    return _syncEventRepository.descartarPendientesCatalogoEspejo();
  }

  /// Encola de nuevo todo el catalogo local que Neon proyecta como espejo.
  ///
  /// Cubre altas hechas offline, datos previos al sync de cada entidad, y
  /// tablas que el push incremental no habia vuelto a subir.
  Future<int> _reencolarCatalogoLocalPendiente({
    ReporteProgresoSync? alProgreso,
  }) async {
    if (_tiendaActivaId.trim().isEmpty || _cajaId.trim().isEmpty) {
      return 0;
    }

    final tiendas =
        (await _tiendaRepository.listarTodas()).where((t) => !t.esStubFk).toList();
    final almacenes = await listarAlmacenes();
    final categorias =
        (await listarCategorias()).where((c) => !c.esStubFk).toList();
    final tiposPresentacion = await listarTiposPresentacion();
    final productos = await listarProductosCatalogo();
    final clientes = await listarClientes();
    final listas = await listarListasPrecios();
    final roles = await _rolPersonalizadoRepository?.listarTodos() ?? [];
    final usuarios = await _usuarioRepository?.listarTodos() ?? [];
    final lotes = await _lotePromocionRepository.listarTodos();
    final preciosCliente =
        await _precioRepository?.listarTodosPreciosClienteProducto() ?? [];
    final descuentosCliente =
        await _descuentoClienteRepository?.listarTodos() ?? [];
    final proveedores =
        (await listarProveedores()).where((p) => !p.esStubFk).toList();
    final compras = await _compraRepository?.listarRecientes() ?? [];
    final turnosCaja =
        await _servicioCorteCaja?.listarTurnosRecientes(limite: 200) ??
        const <TurnoCaja>[];
    final pedidos =
        await _pedidoRepository?.listarPorTienda(_tiendaActivaId) ??
        const <Pedido>[];

    var totalEstimado =
        tiendas.length +
        almacenes.length +
        categorias.length +
        tiposPresentacion.length +
        productos.length +
        clientes.length +
        listas.length +
        roles.length +
        usuarios.length +
        lotes.length +
        preciosCliente.length +
        descuentosCliente.length +
        proveedores.length +
        compras.length +
        turnosCaja.length +
        pedidos.length;
    // Presentaciones, escalas, variantes e items de lista se cuentan al vuelo.
    var encolados = 0;

    void reportar(String mensaje) {
      alProgreso?.call(
        ProgresoSync(
          fase: FaseProgresoSync.preparar,
          indice: encolados,
          total: totalEstimado > 0 ? totalEstimado : encolados,
          mensaje: mensaje,
        ),
      );
    }

    reportar('Preparando catálogo local…');

    for (final tienda in tiendas) {
      await _emisorEventos.tienda(tienda);
      encolados++;
      reportar('Tiendas ($encolados)…');
    }
    for (final almacen in almacenes) {
      await _emisorEventos.almacen(almacen);
      encolados++;
      reportar('Almacenes ($encolados)…');
    }
    for (final categoria in categorias) {
      await _emisorEventos.categoria(categoria);
      encolados++;
      reportar('Categorías ($encolados)…');
    }
    for (final tipo in tiposPresentacion) {
      await _emisorEventos.tipoPresentacion(tipo);
      encolados++;
      reportar('Tipos presentación ($encolados)…');
    }
    for (final producto in productos) {
      await _emisorEventos.producto(producto);
      encolados++;
      final escalas =
          await _precioRepository?.listarEscalasMayoreoPersistidas(
            producto.id,
          ) ??
          [];
      if (escalas.isNotEmpty) {
        await _emisorEventos.escalasMayoreo(producto.id, escalas);
        encolados++;
        totalEstimado++;
      }
      await sincronizarPresentacionesProducto(producto.id);
      encolados++;
      totalEstimado++;
      final variantes = await listarVariantes(producto.id);
      for (final variante in variantes) {
        await _emisorEventos.variante(variante);
        encolados++;
        totalEstimado++;
      }
      reportar('Productos y precios ($encolados)…');
    }
    for (final lote in lotes) {
      await _registrarEventoLotePromocion(lote, empujarInmediato: false);
      encolados++;
      reportar('Lotes promoción ($encolados)…');
    }
    for (final cliente in clientes) {
      await _emisorEventos.cliente(cliente);
      encolados++;
      reportar('Clientes ($encolados)…');
    }
    for (final lista in listas) {
      await _emisorEventos.listaPrecios(lista);
      encolados++;
      final items =
          await _precioRepository?.listarPreciosDeLista(lista.id) ?? {};
      for (final entrada in items.entries) {
        await _emisorEventos.itemListaPrecios(
          listaId: lista.id,
          productoId: entrada.key,
          precioUnitario: entrada.value,
        );
        encolados++;
        totalEstimado++;
      }
      reportar('Listas de precios ($encolados)…');
    }
    for (final precio in preciosCliente) {
      await _emisorEventos.precioClienteProducto(
        clienteId: precio.clienteId,
        productoId: precio.productoId,
        precioUnitario: precio.precioUnitario,
      );
      encolados++;
      reportar('Precios cliente ($encolados)…');
    }
    for (final descuento in descuentosCliente) {
      await _emisorEventos.descuentoCliente(descuento);
      encolados++;
      reportar('Descuentos cliente ($encolados)…');
    }
    for (final rol in roles) {
      await _emisorEventos.rolPersonalizado(rol);
      encolados++;
      reportar('Roles ($encolados)…');
    }
    for (final usuario in usuarios) {
      await _registrarEventoUsuario(usuario);
      encolados++;
      reportar('Usuarios ($encolados)…');
    }
    for (final proveedor in proveedores) {
      await _emisorEventos.proveedor(proveedor);
      encolados++;
      reportar('Proveedores ($encolados)…');
    }
    for (final compra in compras) {
      await _emisorEventos.compra(compra);
      encolados++;
      reportar('Compras ($encolados)…');
    }
    final corte = _servicioCorteCaja;
    if (corte != null) {
      for (final turno in turnosCaja) {
        await corte.publicarTurnoParaSync(turno, empujarAhora: false);
        encolados++;
        reportar('Cortes de caja ($encolados)…');
      }
    }
    for (final pedido in pedidos) {
      await _registrarEventoPedido(pedido, empujarInmediato: false);
      encolados++;
      reportar('Pedidos ($encolados)…');
    }

    reportar('Catálogo listo ($encolados eventos)…');
    return encolados;
  }

  /// Limpia placeholders, vacía la base local y descarga desde Neon.
  ///
  /// Empuja pendientes (incl. catálogo) antes de vaciar, para no perder
  /// empaques/productos locales que aún no estaban en la nube.
  Future<ResultadoReconciliacionHub> reconciliarConHub({
    ReporteProgresoSync? alProgreso,
  }) async {
    await _syncEventRepository.colapsarDuplicadosCatalogo();
    final servicio = ServicioReconciliacionHub(
      baseDatos: _baseDatos,
      configRepository: _configRepository,
      syncOrchestrator: _syncOrchestrator,
      syncStateRepository: SyncStateRepository(baseDatos: _baseDatos),
      tiendaRepository: _tiendaRepository,
    );
    return servicio.reconciliar(alProgreso: alProgreso);
  }

  /// Empuja cambios locales y descarga usuarios y roles del hub (reparacion).
  Future<ResultadoSync> repararSincronizacionUsuarios({
    ReporteProgresoSync? alProgreso,
  }) async {
    alProgreso?.call(
      const ProgresoSync(
        fase: FaseProgresoSync.preparar,
        indice: 0,
        total: 0,
        mensaje: 'Descargando equipo desde la nube…',
      ),
    );
    await importarRolesPersonalizadosDesdeHub();
    await importarUsuariosDesdeHub();
    final repo = _usuarioRepository;
    if (repo != null) {
      final activos = await repo.listarTodos();
      for (final usuario in activos) {
        await _registrarEventoUsuario(usuario);
      }
    }
    final rolesRepo = _rolPersonalizadoRepository;
    if (rolesRepo != null) {
      final roles = await rolesRepo.listarTodos();
      for (final rol in roles) {
        await _emisorEventos.rolPersonalizado(rol);
      }
    }
    return sincronizarManual(alProgreso: alProgreso);
  }

  /// Descarga cuentas del hub Postgres e importa en SQLite local.
  Future<int> importarUsuariosDesdeHub() async {
    final repo = _usuarioRepository;
    if (repo == null) {
      return 0;
    }
    final cliente = await _clienteHubOpcional();
    if (cliente == null || !await cliente.tieneAuthHub()) {
      return 0;
    }
    await _sincronizarTiendasDesdeHub();
    await importarRolesPersonalizadosDesdeHub();
    final remotos = await cliente.obtenerUsuarios();
    if (remotos.isEmpty) {
      return 0;
    }
    var importados = 0;
    final ahora = DateTime.now().toUtc().toIso8601String();
    for (final remoto in remotos) {
      RolUsuario rol;
      try {
        rol = RolUsuario.values.byName(remoto.rol);
      } on ArgumentError {
        rol = RolUsuario.empleado;
      }
      final aplicado = await repo.guardarRemoto(
        id: remoto.id,
        nombre: remoto.nombre,
        codigo: remoto.codigo,
        rol: rol,
        tiendaId: remoto.tiendaId,
        rolPersonalizadoId: remoto.rolPersonalizadoId,
        activo: remoto.activo,
        pinCredencial: remoto.pinCredencial,
        creadoEn: remoto.creadoEn.isNotEmpty ? remoto.creadoEn : ahora,
        actualizadoEn: remoto.actualizadoEn.isNotEmpty
            ? remoto.actualizadoEn
            : ahora,
      );
      if (aplicado) {
        importados++;
      }
    }
    return importados;
  }

  /// Descarga roles personalizados del hub Postgres e importa en SQLite local.
  Future<int> importarRolesPersonalizadosDesdeHub() async {
    final repo = _rolPersonalizadoRepository;
    if (repo == null) {
      return 0;
    }
    final cliente = await _clienteHubOpcional();
    if (cliente == null || !await cliente.tieneAuthHub()) {
      return 0;
    }
    final remotos = await cliente.obtenerRolesPersonalizados();
    if (remotos.isEmpty) {
      return 0;
    }
    var importados = 0;
    for (final remoto in remotos) {
      await repo.guardar(
        RolPersonalizado(
          id: remoto.id,
          nombre: remoto.nombre,
          descripcion: remoto.descripcion,
          permisosAdmin: remoto.permisosAdmin,
          categoriasPermitidas: remoto.categoriasPermitidas,
          activo: remoto.activo,
          tiendaId: remoto.tiendaId,
        ),
      );
      importados++;
    }
    return importados;
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
    await _configRepository.guardarValor(claveConfigHubApiKey, clave.trim());
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

  Future<List<Categoria>> listarCategorias() {
    return _categorias.listarCategorias();
  }

  /// Crea la categoria indicada en la solicitud de importacion si aún no existe.
  Future<AltaProductoRequest> _resolverCategoriaImportacion(
    AltaProductoRequest solicitud, {
    required Map<String, String> categoriasCreadas,
  }) async {
    final aCrear = solicitud.categoriaACrear?.trim();
    if (aCrear == null || aCrear.isEmpty) {
      if (solicitud.categoriaId.trim().isEmpty) {
        throw StateError('Categoria no resuelta para "${solicitud.nombre}"');
      }
      return solicitud;
    }
    final clave = normalizarTextoBusqueda(aCrear);
    final cached = categoriasCreadas[clave];
    if (cached != null) {
      return solicitud.copiarCon(
        categoriaId: cached,
        limpiarCategoriaACrear: true,
      );
    }
    final existentes = await listarCategorias();
    for (final c in existentes.where((c) => c.activa)) {
      if (normalizarTextoBusqueda(c.nombre) == clave) {
        categoriasCreadas[clave] = c.id;
        return solicitud.copiarCon(
          categoriaId: c.id,
          limpiarCategoriaACrear: true,
        );
      }
    }
    final creada = await registrarCategoria(nombre: aCrear);
    categoriasCreadas[clave] = creada.id;
    return solicitud.copiarCon(
      categoriaId: creada.id,
      limpiarCategoriaACrear: true,
    );
  }

  Future<Categoria> registrarCategoria({
    required String nombre,
    String icono = 'shopping_basket',
    String colorHex = '#4CAF50',
  }) {
    return _categorias.registrarCategoria(
      nombre: nombre,
      icono: icono,
      colorHex: colorHex,
    );
  }

  Future<void> actualizarCategoria(Categoria categoria) {
    return _categorias.actualizarCategoria(categoria);
  }

  /// Reordena categorias segun lista de ids.
  Future<void> reordenarCategorias(List<String> idsOrdenados) {
    return _categorias.reordenarCategorias(idsOrdenados);
  }

  Future<void> eliminarCategoria(String categoriaId) {
    return _categorias.eliminarCategoria(categoriaId);
  }

  Future<Producto> asignarCategoriaProducto(
    Producto producto,
    String? categoriaId,
  ) async {
    final actualizado = producto.copiarCon(categoriaId: categoriaId);
    await _productoRepository.guardar(actualizado);
    await _emisorEventos.producto(actualizado);
    return actualizado;
  }

  // --- Variantes ---

  Future<List<VarianteProducto>> listarVariantes(String productoPadreId) {
    return _catalogoProductos.listarVariantes(productoPadreId);
  }

  Future<VarianteProducto> registrarVariante({
    required String productoPadreId,
    required String nombre,
    required String sku,
    required String codigoBarras,
    required double precioBase,
  }) {
    return _catalogoProductos.registrarVariante(
      productoPadreId: productoPadreId,
      nombre: nombre,
      sku: sku,
      codigoBarras: codigoBarras,
      precioBase: precioBase,
    );
  }

  Future<void> actualizarVariante(VarianteProducto variante) {
    return _catalogoProductos.actualizarVariante(variante);
  }

  // --- Clientes ---

  Future<List<Cliente>> listarClientes() {
    return _clientes.listarClientes();
  }

  Future<Cliente> registrarCliente({
    required String nombre,
    bool creditoHabilitado = false,
  }) {
    return _clientes.registrarCliente(
      nombre: nombre,
      creditoHabilitado: creditoHabilitado,
    );
  }

  Future<void> actualizarCliente(Cliente cliente) {
    return _clientes.actualizarCliente(cliente);
  }

  /// Elimina un cliente sin historial de ventas, pedidos ni cotizaciones.
  ///
  /// Lanza [StateError] si el cliente tiene movimientos registrados.
  Future<void> eliminarCliente(String clienteId) {
    return _clientes.eliminarCliente(clienteId);
  }

  Future<Cliente?> obtenerCliente(String clienteId) {
    return _clientes.obtenerCliente(clienteId);
  }

  Future<Vendedor?> obtenerVendedor(String vendedorId) async {
    return _vendedorRepository?.obtenerPorId(vendedorId);
  }

  Future<List<Venta>> listarVentasCliente(String clienteId, {int dias = 90}) {
    return _clientes.listarVentasCliente(clienteId, dias: dias);
  }

  Future<ResumenCliente> obtenerResumenCliente(String clienteId) {
    return _clientes.obtenerResumenCliente(clienteId);
  }

  // --- Descuentos de cliente ---

  Future<List<DescuentoCliente>> listarDescuentosCliente(String clienteId) {
    return _clientes.listarDescuentosCliente(clienteId);
  }

  Future<DescuentoCliente> registrarDescuentoCliente({
    required String clienteId,
    required TipoDescuentoCliente tipo,
    required double valor,
    required CondicionDescuentoCliente condicion,
    String? productoId,
    double? umbral,
    String descripcion = '',
  }) {
    return _clientes.registrarDescuentoCliente(
      clienteId: clienteId,
      tipo: tipo,
      valor: valor,
      condicion: condicion,
      productoId: productoId,
      umbral: umbral,
      descripcion: descripcion,
    );
  }

  Future<void> actualizarDescuentoCliente(DescuentoCliente descuento) {
    return _clientes.actualizarDescuentoCliente(descuento);
  }

  Future<void> eliminarDescuentoCliente(String descuentoId) {
    return _clientes.eliminarDescuentoCliente(descuentoId);
  }

  Future<List<PrecioClienteProducto>> listarPreciosEspecialesCliente(
    String clienteId,
  ) {
    return _clientes.listarPreciosEspecialesCliente(clienteId);
  }

  Future<void> guardarPrecioEspecialCliente({
    required String clienteId,
    required String productoId,
    required double precioUnitario,
  }) {
    return _clientes.guardarPrecioEspecialCliente(
      clienteId: clienteId,
      productoId: productoId,
      precioUnitario: precioUnitario,
    );
  }

  Future<void> eliminarPrecioEspecialCliente(
    String clienteId,
    String productoId,
  ) {
    return _clientes.eliminarPrecioEspecialCliente(clienteId, productoId);
  }

  // --- Vendedores ---

  Future<List<Vendedor>> listarVendedores({Usuario? operador}) {
    return _vendedores.listarVendedores(operador: operador);
  }

  Future<void> actualizarVendedor(Vendedor vendedor, {Usuario? operador}) {
    return _vendedores.actualizarVendedor(vendedor, operador: operador);
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
      // Preferir tiendas ya recibidas en el login; no bloquear en hub.
      await _asegurarTiendasAdministrador(tiendasIniciales: tiendasDesdeHub);
      // Usuarios remotos se importan en sync de fondo / manual.
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

  Future<List<RolPersonalizado>> listarRolesPersonalizados({
    Usuario? operador,
  }) async {
    final repo = _rolPersonalizadoRepository;
    if (repo == null) {
      return [];
    }
    if (operador != null &&
        !PoliticaAccesoAdmin.puedeGestionarRolesPersonalizados(operador)) {
      return [];
    }
    return repo.listarTodos();
  }

  Future<List<RolPersonalizado>> listarRolesPersonalizadosActivos() async {
    final repo = _rolPersonalizadoRepository;
    if (repo == null) {
      return [];
    }
    return repo.listarActivos();
  }

  Future<RolPersonalizado?> obtenerRolPersonalizado(String id) async {
    return _rolPersonalizadoRepository?.obtenerPorId(id);
  }

  Future<RolPersonalizado> guardarRolPersonalizado(
    RolPersonalizado rol, {
    Usuario? operador,
  }) async {
    final repo = _rolPersonalizadoRepository;
    if (repo == null) {
      throw StateError('Repositorio de roles personalizados no configurado');
    }
    if (operador != null &&
        !PoliticaAccesoAdmin.puedeGestionarRolesPersonalizados(operador)) {
      throw StateError('Sin permiso para gestionar roles personalizados');
    }
    final nombre = rol.nombre.trim();
    if (nombre.isEmpty) {
      throw StateError('El nombre del rol es obligatorio');
    }
    if (rol.permisosAdmin.isEmpty) {
      throw StateError('Seleccione al menos un permiso de administración');
    }
    for (final clave in rol.permisosAdmin) {
      if (!PermisosAdmin.asignables.contains(clave)) {
        throw StateError('Permiso no válido: $clave');
      }
    }
    await repo.guardar(rol);
    await _emisorEventos.rolPersonalizado(rol);
    await _sincronizarInmediatoConHub();
    return rol;
  }

  Future<RolPersonalizado> crearRolPersonalizado({
    required String nombre,
    String descripcion = '',
    required List<String> permisosAdmin,
    List<String> categoriasPermitidas = const [],
    String? tiendaId,
    Usuario? operador,
  }) async {
    final rol = RolPersonalizado(
      id: _generadorId.v4(),
      nombre: nombre,
      descripcion: descripcion,
      permisosAdmin: permisosAdmin,
      categoriasPermitidas: categoriasPermitidas,
      activo: true,
      tiendaId: tiendaId,
    );
    return guardarRolPersonalizado(rol, operador: operador);
  }

  Future<void> desactivarRolPersonalizado(
    String id, {
    Usuario? operador,
  }) async {
    final repo = _rolPersonalizadoRepository;
    if (repo == null) {
      throw StateError('Repositorio de roles personalizados no configurado');
    }
    if (operador != null &&
        !PoliticaAccesoAdmin.puedeGestionarRolesPersonalizados(operador)) {
      throw StateError('Sin permiso para gestionar roles personalizados');
    }
    final existente = await repo.obtenerPorId(id);
    if (existente == null) {
      throw StateError('Rol personalizado no encontrado');
    }
    await repo.guardar(existente.copiarCon(activo: false));
    await _emisorEventos.rolPersonalizado(existente.copiarCon(activo: false));
    await _sincronizarInmediatoConHub();
  }

  Future<List<Producto>> listarProductosCatalogoFiltrados({
    Usuario? operador,
    RolPersonalizado? rolPersonalizado,
  }) async {
    final productos = await listarProductosCatalogo();
    if (operador == null) {
      return productos;
    }
    final permitidas = PoliticaAccesoAdmin.categoriasProductoPermitidas(
      operador,
      rolPersonalizado,
    );
    if (permitidas == null) {
      return productos;
    }
    return productos
        .where(
          (p) => p.categoriaId != null && permitidas.contains(p.categoriaId),
        )
        .toList();
  }

  void validarAccesoProductoEnCategoria({
    required Usuario operador,
    RolPersonalizado? rolPersonalizado,
    String? categoriaId,
  }) {
    if (!PoliticaAccesoAdmin.puedeEditarProductoEnCategoria(
      operador,
      rolPersonalizado,
      categoriaId,
    )) {
      throw StateError('Sin permiso para editar productos de esta categoría');
    }
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
    String? rolPersonalizadoId,
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
    final rolPersonalizadoFinal = await _resolverRolPersonalizadoAsignado(
      rol: rol,
      rolPersonalizadoId: rolPersonalizadoId,
      limpiarSiAdministrador: true,
    );
    final usuario = Usuario(
      id: IdPosia.usuario(codigo),
      nombre: nombreLimpio,
      codigo: codigo,
      pin: pin.trim(),
      rol: rol,
      tiendaId: rol == RolUsuario.administrador ? null : tiendaDestino,
      rolPersonalizadoId: rolPersonalizadoFinal,
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

    final rolPersonalizadoFinal = await _resolverRolPersonalizadoAsignado(
      rol: rolFinal,
      rolPersonalizadoId: esPropiaCuenta
          ? existente.rolPersonalizadoId
          : usuario.rolPersonalizadoId,
      limpiarSiAdministrador: true,
    );

    final actualizado = existente.copiarCon(
      nombre: nombreLimpio,
      codigo: codigoFinal,
      pin: pinFinal,
      rol: rolFinal,
      activo: usuario.activo,
      tiendaId: tiendaFinal,
      limpiarTiendaId: limpiarTiendaId,
      rolPersonalizadoId: rolPersonalizadoFinal,
      limpiarRolPersonalizado:
          rolFinal == RolUsuario.administrador && rolPersonalizadoFinal == null,
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
    await SincronizadorVendedorUsuario.sincronizar(
      repo: repo,
      usuario: usuario,
    );
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

  Future<List<Proveedor>> listarProveedores() {
    return _proveedores.listarProveedores();
  }

  Future<Proveedor> registrarProveedor({
    required String nombre,
    String contacto = '',
    String telefono = '',
  }) {
    return _proveedores.registrarProveedor(
      nombre: nombre,
      contacto: contacto,
      telefono: telefono,
    );
  }

  Future<void> actualizarProveedor(Proveedor proveedor) {
    return _proveedores.actualizarProveedor(proveedor);
  }

  /// Elimina un proveedor sin compras registradas.
  ///
  /// Los productos vinculados quedan sin proveedor asignado.
  /// Lanza [StateError] si el proveedor tiene compras en el historial.
  Future<void> eliminarProveedor(String proveedorId) {
    return _proveedores.eliminarProveedor(proveedorId);
  }

  Future<Proveedor?> obtenerProveedor(String proveedorId) {
    return _proveedores.obtenerProveedor(proveedorId);
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

  /// Almacén por defecto para compras sin ubicación explícita.
  Future<Almacen> obtenerAlmacenPorDefectoCompra() {
    return _compras.obtenerAlmacenPorDefectoCompra();
  }

  Future<Compra> registrarCompra({
    required String proveedorId,
    required List<LineaCompraSolicitud> lineas,
    required DateTime fechaCompra,
    String notas = '',
    List<AsignacionCompraSolicitud>? ubicaciones,
    Usuario? operador,
  }) {
    return _compras.registrarCompra(
      proveedorId: proveedorId,
      lineas: lineas,
      fechaCompra: fechaCompra,
      notas: notas,
      ubicaciones: ubicaciones,
      operador: operador,
    );
  }

  Future<List<Compra>> listarCompras({
    String? tiendaId,
    Usuario? operador,
  }) {
    // Historial a nivel empresa (razon social); tiendaId/operador se ignoran.
    return _compras.listarCompras();
  }

  Future<Compra?> obtenerCompra(String compraId) {
    return _compras.obtenerCompra(compraId);
  }

  /// Usado por [registrarPedido]; el resto de operaciones de pedido viven en
  /// [_pedidosCotizaciones], que tiene su propia copia (evita el acople
  /// inverso hacia ServicioAdmin).
  void _validarGestionPedidos(Usuario? operador) {
    if (operador != null && !PermisosUsuario.puedeGestionarPedidos(operador)) {
      throw StateError('Sin permiso para gestionar pedidos');
    }
  }

  // --- Pedidos ---

  Future<List<Usuario>> listarEmpleadosParaAsignacion({Usuario? operador}) {
    return _pedidosCotizaciones.listarEmpleadosParaAsignacion(
      operador: operador,
    );
  }

  Future<List<Pedido>> listarPedidosRecibidos({
    String? tiendaId,
    Usuario? operador,
  }) {
    return _pedidosCotizaciones.listarPedidosRecibidos(
      tiendaId: tiendaId,
      operador: operador,
    );
  }

  Future<List<Pedido>> listarPedidosTienda({
    String? tiendaId,
    Usuario? operador,
  }) {
    return _pedidosCotizaciones.listarPedidosTienda(
      tiendaId: tiendaId,
      operador: operador,
    );
  }

  Future<List<Pedido>> listarPedidosAsignadosA(Usuario empleado) {
    return _pedidosCotizaciones.listarPedidosAsignadosA(empleado);
  }

  /// Pedidos entregados para mostrar en historial de operaciones.
  Future<List<Pedido>> listarPedidosEntregadosHistorial({int dias = 7}) {
    return _pedidosCotizaciones.listarPedidosEntregadosHistorial(dias: dias);
  }

  Future<Pedido?> obtenerPedido(String pedidoId) {
    return _pedidosCotizaciones.obtenerPedido(pedidoId);
  }

  // --- Cotizaciones ---

  Future<List<Cotizacion>> listarCotizaciones({int dias = 30}) {
    return _pedidosCotizaciones.listarCotizaciones(dias: dias);
  }

  Future<Cotizacion?> obtenerCotizacion(String cotizacionId) {
    return _pedidosCotizaciones.obtenerCotizacion(cotizacionId);
  }

  Future<bool> eliminarCotizacion(String cotizacionId) {
    return _pedidosCotizaciones.eliminarCotizacion(cotizacionId);
  }

  /// Registra cotizacion desde administracion (sin carrito de caja).
  Future<Cotizacion> registrarCotizacion({
    required List<LineaCotizacion> lineas,
    String? clienteId,
    String nombre = '',
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
    Cliente? cliente;
    String? nombreCliente;
    if (clienteId != null) {
      cliente = await _clienteRepository?.obtenerPorId(clienteId);
      nombreCliente = cliente?.nombre;
    }
    final lineasResueltas = <LineaCotizacion>[];
    for (final solicitud in lineas) {
      if (solicitud.cantidad <= 0) {
        throw StateError('Cantidad inválida en línea de cotización');
      }
      final producto = await _productoRepository.obtenerPorId(
        solicitud.productoId,
      );
      if (producto == null) {
        throw StateError('Producto no encontrado');
      }
      final precio = await resolverPrecioComercial(
        producto: producto,
        cantidad: solicitud.cantidad,
        cliente: cliente,
      );
      lineasResueltas.add(
        LineaCotizacion(
          productoId: producto.id,
          nombreProducto: producto.nombre,
          cantidad: solicitud.cantidad,
          precioUnitario: redondearMonto(precio.precioUnitario),
          reglaPrecio: precio.reglaAplicada,
        ),
      );
    }
    final cotizacion = Cotizacion(
      id: _generadorId.v4(),
      tiendaId: _tiendaActivaId,
      nombre: nombre.trim(),
      clienteId: clienteId,
      nombreCliente: nombreCliente,
      total: Cotizacion.calcularTotalDesdeLineas(lineasResueltas),
      notas: notas.trim(),
      vigenciaDias: vigenciaDias,
      creadaEn: DateTime.now().toUtc(),
      cajaId: _cajaId,
      vendedorId: vendedorId,
      lineas: lineasResueltas,
    );
    await repo.guardar(cotizacion);
    await _emisorEventos.cotizacion(cotizacion);
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
      throw StateError(
        'Nombre, telefono y direccion de entrega son obligatorios',
      );
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
    Cliente? clientePedido;
    if (clienteId != null) {
      clientePedido = await _clienteRepository?.obtenerPorId(clienteId);
    }
    for (final solicitud in lineas) {
      if (solicitud.cantidad <= 0) {
        throw StateError('Cantidad invalida en linea de pedido');
      }
      final producto = await _productoRepository.obtenerPorId(
        solicitud.productoId,
      );
      if (producto == null) {
        throw StateError('Producto no encontrado');
      }
      final precio = await resolverPrecioComercial(
        producto: producto,
        cantidad: solicitud.cantidad,
        cliente: clientePedido,
      );
      lineasPedido.add(
        LineaPedido(
          productoId: producto.id,
          nombreProducto: producto.nombre,
          cantidad: solicitud.cantidad,
          precioUnitario: redondearMonto(precio.precioUnitario),
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
    await _registrarEventoPedido(pedido);
    return pedido;
  }

  Future<Pedido> asignarPedido({
    required String pedidoId,
    required String empleadoUsuarioId,
    Usuario? operador,
  }) async {
    final actualizado = await _pedidosCotizaciones.asignarPedido(
      pedidoId: pedidoId,
      empleadoUsuarioId: empleadoUsuarioId,
      operador: operador,
    );
    await _registrarEventoPedido(actualizado);
    return actualizado;
  }

  Future<Pedido> marcarPedidoEntregado({
    required String pedidoId,
    Usuario? operador,
  }) async {
    final actualizado = await _pedidosCotizaciones.marcarPedidoEntregado(
      pedidoId: pedidoId,
      operador: operador,
    );
    await _registrarEventoPedido(actualizado);
    return actualizado;
  }

  Future<Pedido> cancelarPedido({
    required String pedidoId,
    Usuario? operador,
  }) async {
    final actualizado = await _pedidosCotizaciones.cancelarPedido(
      pedidoId: pedidoId,
      operador: operador,
    );
    await _registrarEventoPedido(actualizado);
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
    await _configRepository.guardarValor(
      claveConfigTeclaCobrar,
      tecla.trim().toUpperCase(),
    );
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
    final raw = await _configRepository.obtenerValor(
      claveConfigEtiquetaAnchoMm,
    );
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
    final raw = await _configRepository.obtenerValor(
      claveConfigEtiquetasCarpeta,
    );
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> guardarCarpetaEtiquetas(String ruta) async {
    await _configRepository.guardarValor(
      claveConfigEtiquetasCarpeta,
      ruta.trim(),
    );
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
      final producto = await _productoRepository.obtenerPorId(
        solicitud.productoId,
      );
      if (producto == null) {
        throw StateError('Producto no encontrado');
      }
      final precio = await resolverPrecioComercial(
        producto: producto,
        cantidad: solicitud.cantidad,
        cliente: cliente,
      );
      if (precio.precioUnitario <= 0) {
        throw StateError('Precio invalido en linea de credito');
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
          precioUnitario: redondearMonto(precio.precioUnitario),
          reglaPrecio: precio.reglaAplicada,
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

    TurnoCaja? turnoActualizado;
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
        turnoActualizado = await _servicioCorteCaja.registrarVenta(
          turno,
          venta,
          db: tx,
        );
      }
    });
    if (turnoActualizado != null) {
      await _servicioCorteCaja?.notificarTurnoActualizado(turnoActualizado!);
    }
    await _emisorEventos.ventaCompletada(venta);
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
    TurnoCaja? turnoActualizado;
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
      turnoActualizado = await _servicioCorteCaja?.registrarDevolucion(
        venta,
        montoDevuelto,
        db: tx,
      );
    });
    if (turnoActualizado != null) {
      await _servicioCorteCaja?.notificarTurnoActualizado(turnoActualizado!);
    }
    await _emisorEventos.devolucionParcial(
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
    TurnoCaja? turnoActualizado;
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
      turnoActualizado = await _servicioCorteCaja?.registrarAnulacion(
        venta,
        db: tx,
      );
    });
    if (turnoActualizado != null) {
      await _servicioCorteCaja?.notificarTurnoActualizado(turnoActualizado!);
    }
    await _emisorEventos.anulacion(venta);
    return true;
  }

  // --- Traspasos ---

  Future<List<Traspaso>> listarTraspasos() {
    return _traspasos.listarTraspasos();
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
      await _tiendaRepository.fusionarRemota(tienda);
    }
  }

  Future<void> _asegurarTiendasAdministrador({
    List<Tienda> tiendasIniciales = const [],
  }) async {
    if (tiendasIniciales.isNotEmpty) {
      await importarTiendasDesdeHub(tiendasIniciales);
    }
    // Solo consultar hub si no hay tiendas locales ni en el payload de login.
    // Evita colgar el arranque cuando el hub esta lento o caido.
    if ((await _tiendaRepository.listarActivasOperativas()).isEmpty) {
      try {
        await _sincronizarTiendasDesdeHub().timeout(
          const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS),
        );
      } on Object {
        // Admin puede reintentar desde la pantalla de tiendas.
      }
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
              latitud: t.latitud,
              longitud: t.longitud,
              radioMetrosAsistencia: t.radioMetrosAsistencia,
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
    await _emisorEventos.tienda(tienda);
    return tienda;
  }

  Future<void> actualizarTienda(Tienda tienda) async {
    await _tiendaRepository.guardar(tienda);
    await _emisorEventos.tienda(tienda);
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
      latitud: tienda.latitud,
      longitud: tienda.longitud,
      radioMetrosAsistencia: tienda.radioMetrosAsistencia,
    );
    await _tiendaRepository.guardar(inactiva);
    await _emisorEventos.tienda(inactiva);
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
      TurnoCaja? turnoActualizado;
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
        turnoActualizado = await _servicioCorteCaja?.registrarAnulacion(
          venta,
          db: tx,
        );
        await _ventaRepository.eliminar(ventaId, db: tx);
      });
      if (turnoActualizado != null) {
        await _servicioCorteCaja?.notificarTurnoActualizado(turnoActualizado!);
      }
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
    return _traspasos.realizarTraspaso(
      tiendaOrigenId: tiendaOrigenId,
      tiendaDestinoId: tiendaDestinoId,
      productoId: productoId,
      cantidad: cantidad,
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
  }) {
    return _traspasos.realizarTraspasoMultiple(
      tiendaOrigenId: tiendaOrigenId,
      tiendaDestinoId: tiendaDestinoId,
      lineas: lineas,
      notas: notas,
      operador: operador,
    );
  }

  /// Compatibilidad: delega en [realizarTraspaso] usando la tienda activa del dispositivo.
  Future<Traspaso> solicitarTraspaso({
    required String tiendaDestinoId,
    required String productoId,
    required double cantidad,
    String notas = '',
  }) {
    return _traspasos.solicitarTraspaso(
      tiendaDestinoId: tiendaDestinoId,
      productoId: productoId,
      cantidad: cantidad,
      notas: notas,
    );
  }

  /// Completa traspasos antiguos en transito (flujo de dos pasos).
  Future<bool> recibirTraspaso(String traspasoId) {
    return _traspasos.recibirTraspaso(traspasoId);
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
  }) {
    return _inventarioMovimientos.registrarMovimientoInventario(
      productoId: productoId,
      tipo: tipo,
      cantidad: cantidad,
      motivo: motivo,
      proveedorId: proveedorId,
      tiendaId: tiendaId,
      operador: operador,
    );
  }

  Future<List<MovimientoInventario>> listarMovimientosInventario({
    String? tiendaId,
    Usuario? operador,
  }) {
    return _inventarioMovimientos.listarMovimientosInventario(
      tiendaId: tiendaId,
      operador: operador,
    );
  }

  Future<void> configurarStockMinimo(
    String productoId,
    double stockMinimo, {
    String? tiendaId,
    Usuario? operador,
  }) {
    return _inventarioMovimientos.configurarStockMinimo(
      productoId,
      stockMinimo,
      tiendaId: tiendaId,
      operador: operador,
    );
  }

  Future<List<AlertaFaltante>> obtenerAlertasFaltantes({String? tiendaId}) {
    return _inventarioMovimientos.obtenerAlertasFaltantes(tiendaId: tiendaId);
  }

  // --- Reportes ---

  Future<List<ResumenVendedor>> obtenerResumenPorVendedor(FiltroVentas filtro) {
    return _reportes.obtenerResumenPorVendedor(filtro);
  }

  Future<List<ResumenProductoVenta>> obtenerResumenPorProducto(
    FiltroVentas filtro,
  ) {
    return _reportes.obtenerResumenPorProducto(filtro);
  }

  Future<List<ResumenVentasHora>> obtenerResumenPorHora(FiltroVentas filtro) {
    return _reportes.obtenerResumenPorHora(filtro);
  }

  Future<Map<MetodoPago, double>> obtenerTotalesPorMetodoPago(
    FiltroVentas filtro,
  ) {
    return _reportes.obtenerTotalesPorMetodoPago(filtro);
  }

  Future<List<ListaPrecios>> listarListasPrecios() {
    return _listasPrecios.listarListasPrecios();
  }

  Future<ListaPrecios> registrarListaPrecios(String nombre) {
    return _listasPrecios.registrarListaPrecios(nombre);
  }

  Future<void> guardarPrecioLista(
    String listaId,
    String productoId,
    double precio,
  ) {
    return _listasPrecios.guardarPrecioLista(listaId, productoId, precio);
  }

  Future<ResumenPreciosProducto?> obtenerResumenPreciosProducto(
    String productoId,
  ) {
    return _listasPrecios.obtenerResumenPreciosProducto(productoId);
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
    _catalogoProductos.validarPrecioVenta(precioUnitario, producto.costoUnitario);
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

  Future<void> eliminarListaPrecios(String listaId) {
    return _listasPrecios.eliminarListaPrecios(listaId);
  }

  Future<List<Cliente>> listarClientesPorLista(String listaId) {
    return _listasPrecios.listarClientesPorLista(listaId);
  }

  Future<List<ItemListaPrecios>> listarItemsListaPrecios(String listaId) {
    return _listasPrecios.listarItemsListaPrecios(listaId);
  }

  Future<void> eliminarProductoDeLista(String listaId, String productoId) {
    return _listasPrecios.eliminarProductoDeLista(listaId, productoId);
  }

  Future<void> establecerFavoritoProducto(String productoId, bool favorito) {
    return _catalogoProductos.establecerFavoritoProducto(productoId, favorito);
  }

  Future<void> _registrarEventoPedido(
    Pedido pedido, {
    bool empujarInmediato = true,
  }) async {
    final eventoId = await _emisorEventos.pedido(pedido);
    if (empujarInmediato) {
      await _syncOrchestrator.sincronizarEventosPorIds([eventoId]);
    }
  }

  Future<void> _registrarEventoLotePromocion(
    LotePromocion lote, {
    bool empujarInmediato = true,
  }) async {
    final eventoId = await _emisorEventos.lotePromocion(lote);
    if (empujarInmediato) {
      await _syncOrchestrator.sincronizarEventosPorIds([eventoId]);
    }
  }

  Future<void> sincronizarPresentacionesProducto(String productoId) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      return;
    }
    final presentaciones = await repo.listarPorProducto(productoId);
    await _emisorEventos.presentacionesReemplazadas(
      productoId,
      presentaciones,
    );
    // Colapsar: deja el snapshot mas reciente por producto.
    await _syncEventRepository.colapsarDuplicadosCatalogo();
    // Empujar solo el evento de este producto (no la cola antigua completa).
    final pendientes = await _syncEventRepository.obtenerPendientes();
    final idsEmpaque = pendientes
        .where(
          (e) =>
              e.tipo == TipoSyncEvento.productPresentationsReplaced &&
              (e.payload['productoId']?.toString() == productoId),
        )
        .map((e) => e.id)
        .toList();
    // ignore: unawaited_futures
    _syncOrchestrator.sincronizarEventosPorIds(idsEmpaque).catchError(
      (Object _) => const ResultadoEnvioHub(exitoso: false),
    );
  }

  Future<void> _registrarEventoTraspasoAlmacen({
    required String movimientoId,
    required String almacenOrigenId,
    String? almacenDestinoId,
    String? tiendaDestinoId,
    required List<LineaTraspasoSolicitud> lineas,
  }) async {
    final lineasTraspaso = <LineaTraspaso>[];
    for (final linea in lineas) {
      if (linea.cantidad <= 0) {
        continue;
      }
      final producto = await _productoRepository.obtenerPorId(linea.productoId);
      lineasTraspaso.add(
        LineaTraspaso(
          productoId: linea.productoId,
          nombreProducto: producto?.nombre ?? linea.productoId,
          cantidadSolicitada: linea.cantidad,
          cantidadRecibida: linea.cantidad,
        ),
      );
    }
    if (lineasTraspaso.isEmpty) {
      return;
    }
    final destinoId = tiendaDestinoId != null && tiendaDestinoId.isNotEmpty
        ? tiendaDestinoId
        : (almacenDestinoId != null && almacenDestinoId.isNotEmpty
              ? codificarAlmacenEnTraspaso(almacenDestinoId)
              : '');
    final traspaso = Traspaso(
      id: movimientoId,
      tiendaOrigenId: codificarAlmacenEnTraspaso(almacenOrigenId),
      tiendaDestinoId: destinoId,
      estado: EstadoTraspaso.completado,
      solicitadoEn: DateTime.now().toUtc(),
      completadoEn: DateTime.now().toUtc(),
      notas: 'Abastecimiento desde almacén',
      lineas: lineasTraspaso,
    );
    final repo = _traspasoRepository;
    if (repo != null) {
      await repo.guardar(traspaso);
    }
    await _emisorEventos.traspaso(
      traspaso,
      TipoSyncEvento.transferCompleted,
      almacenOrigenId: almacenOrigenId,
      almacenDestinoId: almacenDestinoId,
    );
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

  Future<String?> _resolverRolPersonalizadoAsignado({
    required RolUsuario rol,
    String? rolPersonalizadoId,
    bool limpiarSiAdministrador = false,
  }) async {
    if (limpiarSiAdministrador && rol == RolUsuario.administrador) {
      return null;
    }
    if (rolPersonalizadoId == null || rolPersonalizadoId.isEmpty) {
      return null;
    }
    final repo = _rolPersonalizadoRepository;
    if (repo == null) {
      throw StateError('Repositorio de roles personalizados no configurado');
    }
    final rolPersonalizado = await repo.obtenerPorId(rolPersonalizadoId);
    if (rolPersonalizado == null || !rolPersonalizado.activo) {
      throw StateError('Rol personalizado no encontrado o inactivo');
    }
    return rolPersonalizado.id;
  }

  /// [usuario.id] debe existir en [_usuarioRepository]: el evento necesita el
  /// snapshot (pin/timestamps) que no vive en el modelo de dominio.
  Future<void> _registrarEventoUsuario(Usuario usuario) async {
    final repo = _usuarioRepository;
    if (repo == null) {
      return;
    }
    final snapshot = await repo.obtenerSnapshotSync(usuario.id);
    if (snapshot == null) {
      return;
    }
    await _emisorEventos.usuario(usuario, snapshot: snapshot);
  }

  // --- Almacenes ---

  Future<List<Almacen>> listarAlmacenes() {
    return _almacenes.listarAlmacenes();
  }

  Future<Almacen> registrarAlmacen(String nombre, {String? tiendaId}) {
    return _almacenes.registrarAlmacen(nombre, tiendaId: tiendaId);
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
    final movimientoId = _generadorId.v4();
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
    await _registrarEventoTraspasoAlmacen(
      movimientoId: movimientoId,
      almacenOrigenId: almacenId,
      tiendaDestinoId: tiendaDestinoId,
      lineas: [
        LineaTraspasoSolicitud(productoId: productoId, cantidad: cantidad),
      ],
    );
  }

  /// Resumen de existencias por almacén activo.
  Future<List<ResumenStockAlmacen>> obtenerResumenAlmacenes() {
    return _almacenes.obtenerResumenAlmacenes();
  }

  /// Inventario detallado de un almacén (productos con cantidad).
  Future<List<StockPorAlmacen>> obtenerInventarioAlmacen(String almacenId) {
    return _almacenes.obtenerInventarioAlmacen(almacenId);
  }

  /// Ajusta existencias en almacén (entrada, salida o ajuste a cantidad fija).
  Future<void> ajustarStockAlmacen({
    required String productoId,
    required String almacenId,
    required TipoMovimientoInventario tipo,
    required double cantidad,
  }) {
    return _almacenes.ajustarStockAlmacen(
      productoId: productoId,
      almacenId: almacenId,
      tipo: tipo,
      cantidad: cantidad,
    );
  }

  /// Productos con existencia en un almacen.
  Future<List<({Producto producto, double cantidad})>>
  listarProductosConStockAlmacen(String almacenId) {
    return _almacenes.listarProductosConStockAlmacen(almacenId);
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
    await _emisorEventos.tipoPresentacion(tipo);
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
    bool sincronizar = true,
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
      if (existente.esPresentacionBase &&
          factorABase != existente.factorABase) {
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
      precio: precio != null ? redondearMonto(precio) : null,
      activo: true,
    );
    await repo.guardarPresentacion(presentacion);
    if (sincronizar) {
      await sincronizarPresentacionesProducto(productoId);
    }
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
    await sincronizarPresentacionesProducto(existente.productoId);
  }
}
