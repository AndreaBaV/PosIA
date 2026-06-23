/// Servicio de operaciones de caja: carrito, cobro e inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
///
/// Para esta sección, necesito que muestre las cosas
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_module_butcher/posia_module_butcher.dart';
import 'package:posia_module_pharmacy/posia_module_pharmacy.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:uuid/uuid.dart';

import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../repositories/venta_repository.dart';
import 'servicio_corte_caja.dart';

/// Coordina flujo de venta en caja con persistencia y sync.
class ServicioCaja {
  /// Crea servicio con dependencias de persistencia y reglas.
  ///
  /// [productoRepository] Acceso a catalogo.
  /// [clienteRepository] Acceso a clientes.
  /// [ventaRepository] Persistencia de ventas.
  /// [motorPrecio] Resolucion de precios comerciales.
  /// [gestorInventario] Ajustes de stock.
  /// [syncOrchestrator] Cola de sincronizacion.
  /// [servicioCarniceria] Modulo vertical carniceria opcional.
  /// [servicioFarmacia] Modulo vertical farmacia opcional.
  /// [tenantId] Tenant activo en licencia.
  /// [tiendaId] Tienda de la caja.
  /// [cajaId] Identificador de caja registradora.
  ServicioCaja({
    required ProductoRepository productoRepository,
    VarianteRepository? varianteRepository,
    required ClienteRepository clienteRepository,
    DescuentoClienteRepository? descuentoClienteRepository,
    required VentaRepository ventaRepository,
    required MotorPrecio motorPrecio,
    required GestorInventario gestorInventario,
    required SyncOrchestrator syncOrchestrator,
    ServicioCarniceria? servicioCarniceria,
    ServicioFarmacia? servicioFarmacia,
    CategoriaRepository? categoriaRepository,
    VendedorRepository? vendedorRepository,
    CotizacionRepository? cotizacionRepository,
    ServicioCorteCaja? servicioCorteCaja,
    required String tenantId,
    required String tiendaId,
    required String cajaId,
  }) : _productoRepository = productoRepository,
       _varianteRepository = varianteRepository,
       _clienteRepository = clienteRepository,
       _descuentoClienteRepository = descuentoClienteRepository,
       _ventaRepository = ventaRepository,
       _motorPrecio = motorPrecio,
       _gestorInventario = gestorInventario,
       _syncOrchestrator = syncOrchestrator,
       _servicioCarniceria = servicioCarniceria,
       _servicioFarmacia = servicioFarmacia,
       _categoriaRepository = categoriaRepository,
       _vendedorRepository = vendedorRepository,
       _cotizacionRepository = cotizacionRepository,
       _servicioCorteCaja = servicioCorteCaja,
       _tenantId = tenantId,
       _tiendaId = tiendaId,
       _cajaId = cajaId;

  final ProductoRepository _productoRepository;
  final VarianteRepository? _varianteRepository;
  final ClienteRepository _clienteRepository;
  final DescuentoClienteRepository? _descuentoClienteRepository;
  final VentaRepository _ventaRepository;
  final MotorPrecio _motorPrecio;
  final GestorInventario _gestorInventario;
  final SyncOrchestrator _syncOrchestrator;
  final ServicioCarniceria? _servicioCarniceria;
  final ServicioFarmacia? _servicioFarmacia;
  final CategoriaRepository? _categoriaRepository;
  final VendedorRepository? _vendedorRepository;
  final CotizacionRepository? _cotizacionRepository;
  final ServicioCorteCaja? _servicioCorteCaja;
  final String _tenantId;
  final String _tiendaId;
  final String _cajaId;
  final Uuid _generadorId = const Uuid();

  final List<LineaCarrito> _lineasCarrito = [];
  Cliente? _clienteActivo;
  Vendedor? _vendedorActivo;
  double _descuentoTicketCliente = 0.0;

  /// Descuento automatico del cliente activo sobre el ticket.
  double obtenerDescuentoTicketCliente() => _descuentoTicketCliente;

  /// Expone servicio de carniceria para UI especializada.
  ///
  /// Retorna instancia configurada o null si modulo no activo.
  ServicioCarniceria? obtenerServicioCarniceria() {
    return _servicioCarniceria;
  }

  /// Expone servicio de farmacia para UI especializada.
  ///
  /// Retorna instancia configurada o null si modulo no activo.
  ServicioFarmacia? obtenerServicioFarmacia() {
    return _servicioFarmacia;
  }

  /// Lineas actuales del carrito activo.
  ///
  /// Retorna copia inmutable de lineas en memoria.
  List<LineaCarrito> obtenerCarrito() {
    return List<LineaCarrito>.unmodifiable(_lineasCarrito);
  }

  /// Cliente seleccionado para la venta actual.
  ///
  /// Retorna cliente activo o null para mostrador.
  Cliente? obtenerClienteActivo() {
    return _clienteActivo;
  }

  /// Asigna cliente activo y recalcula precios del carrito.
  ///
  /// [cliente] Cliente seleccionado o null para mostrador.
  Future<void> seleccionarCliente(Cliente? cliente) async {
    _clienteActivo = cliente;
    await _sincronizarClienteEnCarrito();
  }

  /// Vendedor seleccionado para la venta actual.
  Vendedor? obtenerVendedorActivo() => _vendedorActivo;

  /// Asigna vendedor activo de la venta.
  Future<void> seleccionarVendedor(Vendedor? vendedor) async {
    _vendedorActivo = vendedor;
  }

  /// Vincula el vendedor de caja con el usuario que inicio sesion.
  Future<Vendedor> asegurarVendedorDesdeUsuario(Usuario usuario) async {
    final repo = _vendedorRepository;
    final idVendedor = 'vend-${usuario.id}';
    if (repo != null) {
      final existente = await repo.obtenerPorId(idVendedor);
      if (existente != null) {
        _vendedorActivo = existente;
        return existente;
      }
      final vendedor = Vendedor(
        id: idVendedor,
        nombre: usuario.nombre,
        codigo: usuario.codigo,
        activo: true,
        tiendaId: usuario.tiendaId,
      );
      await repo.guardar(vendedor);
      _vendedorActivo = vendedor;
      return vendedor;
    }
    final vendedor = Vendedor(
      id: idVendedor,
      nombre: usuario.nombre,
      codigo: usuario.codigo,
      activo: true,
      tiendaId: usuario.tiendaId,
    );
    _vendedorActivo = vendedor;
    return vendedor;
  }

  /// Lista categorias activas para barra de caja.
  Future<List<Categoria>> listarCategorias() async {
    final repo = _categoriaRepository;
    if (repo == null) {
      return [];
    }
    return repo.listarActivas();
  }

  /// Lista productos activos, opcionalmente filtrados por categoria.
  ///
  /// [categoriaId] Categoria solicitada; null o [CATEGORIA_TODOS_ID] = todos.
  Future<List<Producto>> listarProductos({String? categoriaId}) async {
    if (categoriaId == null || categoriaId == CATEGORIA_TODOS_ID) {
      return _productoRepository.listarActivosPorTienda(_tiendaId);
    }
    return _productoRepository.listarActivosPorCategoria(
      _tiendaId,
      categoriaId,
    );
  }

  /// Lista vendedores activos para seleccion en caja.
  Future<List<Vendedor>> listarVendedores() async {
    final repo = _vendedorRepository;
    if (repo == null) {
      return [];
    }
    return repo.listarActivos();
  }

  /// Valida requisitos previos al cobro.
  ///
  /// Retorna mensaje de error o null si puede cobrar.
  Future<String?> validarCobro() async {
    if (_lineasCarrito.isEmpty) {
      return 'Carrito vacio';
    }
    final corte = _servicioCorteCaja;
    if (corte != null && !await corte.tieneTurnoAbierto()) {
      await corte.abrirTurno(
        fondoInicial: 0.0,
        vendedorId: _vendedorActivo?.id,
      );
    }
    return null;
  }

  /// Lista clientes activos para seleccion en caja.
  ///
  /// Retorna clientes habilitados.
  Future<List<Cliente>> listarClientes() async {
    return _clienteRepository.listarActivos();
  }

  /// Agrega producto general al carrito con cantidad en piezas.
  ///
  /// [producto] Producto seleccionado.
  /// [cantidad] Cantidad a agregar; default 1.0.
  Future<void> agregarProducto(
    Producto producto, {
    double cantidad = 1.0,
  }) async {
    await _agregarLineaCarrito(
      producto: producto,
      cantidad: cantidad,
      loteId: null,
      etiquetaLote: null,
      permitirFusion: true,
    );
  }

  /// Agrega producto de carniceria vendido por peso en kilogramos.
  ///
  /// [producto] Corte o producto por kg.
  /// [pesoKg] Peso capturado de bascula o manual.
  /// Retorna mensaje de error o cadena vacia si fue exitoso.
  Future<String> agregarProductoConPeso(
    Producto producto,
    double pesoKg,
  ) async {
    final servicioCarniceria = _servicioCarniceria;
    if (servicioCarniceria == null) {
      return 'Modulo carniceria no activo';
    }
    final resultado = servicioCarniceria.validarPesoParaVenta(pesoKg);
    if (!resultado.valido) {
      return resultado.mensajeError;
    }
    await _agregarLineaCarrito(
      producto: producto,
      cantidad: resultado.pesoKg,
      loteId: null,
      etiquetaLote: formatearPesoKg(resultado.pesoKg),
      permitirFusion: false,
    );
    return '';
  }

  /// Agrega producto farmaceutico con lote seleccionado.
  ///
  /// [producto] Medicamento o producto farmacia.
  /// [lote] Lote FEFO seleccionado.
  /// [cantidad] Unidades a vender.
  /// Retorna mensaje de error o cadena vacia si fue exitoso.
  Future<String> agregarProductoConLote(
    Producto producto,
    LoteFarmacia lote,
    double cantidad,
  ) async {
    final servicioFarmacia = _servicioFarmacia;
    if (servicioFarmacia == null) {
      return 'Modulo farmacia no activo';
    }
    final validacion = await servicioFarmacia.validarLoteParaVenta(
      lote.id,
      cantidad,
    );
    if (!validacion.valido) {
      return validacion.mensajeError;
    }
    await _agregarLineaCarrito(
      producto: producto,
      cantidad: cantidad,
      loteId: lote.id,
      etiquetaLote: lote.generarEtiquetaVisible(),
      permitirFusion: false,
    );
    return '';
  }

  /// Indica si el producto tiene presentaciones activas.
  Future<bool> productoTieneVariantes(String productoId) async {
    final repo = _varianteRepository;
    if (repo == null) {
      return false;
    }
    final cantidad = await repo.contarActivasPorProducto(productoId);
    return cantidad > 0;
  }

  /// Lista presentaciones activas de un producto padre.
  Future<List<VarianteProducto>> listarVariantesActivas(
    String productoId,
  ) async {
    return _varianteRepository?.listarActivasPorProductoPadre(productoId) ?? [];
  }

  /// Agrega presentacion al carrito usando precio de la variante.
  Future<void> agregarVariante(VarianteProducto variante) async {
    final padre = await _productoRepository.obtenerPorId(
      variante.productoPadreId,
    );
    if (padre == null) {
      return;
    }
    final productoVenta = padre.copiarCon(
      id: variante.id,
      nombre: '${padre.nombre} - ${variante.nombre}',
      codigoBarras: variante.codigoBarras,
      precioBase: variante.precioBase,
    );
    await agregarProducto(productoVenta);
  }

  /// Busca variante o producto por codigo de barras y lo agrega al carrito.
  ///
  /// [codigoBarras] Codigo escaneado.
  /// Retorna verdadero si el producto fue encontrado y agregado.
  Future<bool> agregarPorCodigoBarras(String codigoBarras) async {
    final variante = await _varianteRepository?.buscarPorCodigoBarras(
      codigoBarras,
    );
    if (variante != null) {
      await agregarVariante(variante);
      return true;
    }
    final producto = await _productoRepository.buscarPorCodigoBarras(
      codigoBarras,
    );
    if (producto == null) {
      return false;
    }
    if (await productoTieneVariantes(producto.id)) {
      return false;
    }
    await agregarProducto(producto);
    return true;
  }

  /// Elimina linea del carrito por indice.
  ///
  /// [indice] Posicion de la linea a eliminar.
  Future<void> eliminarLinea(int indice) async {
    if (indice < 0 || indice >= _lineasCarrito.length) {
      return;
    }
    _lineasCarrito.removeAt(indice);
    await _aplicarDescuentosCliente();
  }

  /// Vacia el carrito activo sin persistir venta.
  void vaciarCarrito() {
    _lineasCarrito.clear();
    _clienteActivo = null;
    _descuentoTicketCliente = 0.0;
  }

  /// Calcula total del carrito activo.
  ///
  /// Retorna monto total redondeado en MXN.
  double calcularTotalCarrito() {
    var acumulado = 0.0;
    for (final linea in _lineasCarrito) {
      acumulado = acumulado + linea.calcularSubtotal();
    }
    final neto = acumulado - _descuentoTicketCliente;
    return redondearMonto(neto < 0.0 ? 0.0 : neto);
  }

  /// Cierra venta, persiste, ajusta inventario y encola sync.
  ///
  /// [request] Forma de pago y descuentos.
  /// Retorna venta persistida o null si carrito vacio o validacion falla.
  Future<Venta?> cobrar(CobroRequest request) async {
    if (_lineasCarrito.isEmpty) {
      return null;
    }
    final errorCobro = await validarCobroRequest(request);
    if (errorCobro != null) {
      return null;
    }
    final lineasVenta = _lineasCarrito
        .map(
          (linea) => LineaVenta(
            productoId: linea.producto.id,
            nombreProducto: linea.producto.nombre,
            cantidad: linea.cantidad,
            precioUnitario: linea.precioUnitario,
            reglaPrecio: linea.reglaPrecio,
            loteId: linea.loteId,
            etiquetaLote: linea.etiquetaLote,
            descuentoLinea: linea.descuentoLinea,
          ),
        )
        .toList();
    final turno = await _servicioCorteCaja?.obtenerTurnoAbierto();
    final total = Venta.calcularTotalDesdeLineas(
      lineasVenta,
      descuentoTicket: request.descuentoTicket + _descuentoTicketCliente,
    );
    double? montoEfectivo;
    double? montoTarjeta;
    double? montoTransferencia;
    switch (request.metodoPago) {
      case MetodoPago.efectivo:
        montoEfectivo = total;
      case MetodoPago.tarjeta:
        montoTarjeta = total;
      case MetodoPago.transferencia:
        montoTransferencia = total;
      case MetodoPago.mixto:
        montoEfectivo = request.montoEfectivo;
        montoTarjeta = request.montoTarjeta;
        montoTransferencia = request.montoTransferencia;
      case MetodoPago.credito:
        break;
    }
    int? creditoDias;
    DateTime? creditoVenceEn;
    if (request.metodoPago == MetodoPago.credito) {
      creditoDias = request.diasCredito ?? _clienteActivo!.diasCredito;
      creditoVenceEn = calcularFechaVencimientoCredito(
        DateTime.now().toUtc(),
        creditoDias,
      );
    }
    final venta = Venta(
      id: _generadorId.v4(),
      tiendaId: _tiendaId,
      cajaId: _cajaId,
      clienteId: _clienteActivo?.id,
      lineas: lineasVenta,
      metodoPago: request.metodoPago,
      total: total,
      creadaEn: DateTime.now().toUtc(),
      vendedorId: _vendedorActivo?.id,
      turnoCajaId: turno?.id,
      descuentoTicket: request.descuentoTicket + _descuentoTicketCliente,
      montoEfectivo: montoEfectivo,
      montoTarjeta: montoTarjeta,
      montoTransferencia: montoTransferencia,
      creditoDias: creditoDias,
      creditoVenceEn: creditoVenceEn,
    );
    await _ventaRepository.guardar(venta);
    if (turno != null && _servicioCorteCaja != null) {
      await _servicioCorteCaja.registrarVenta(turno, venta);
    }
    await _gestorInventario.aplicarVenta(venta);
    await _aplicarDescuentosLote(venta);
    await _registrarEventoVenta(venta);
    vaciarCarrito();
    return venta;
  }

  /// Valida cobro con multipago y credito.
  Future<String?> validarCobroRequest(CobroRequest request) async {
    final errorBase = await validarCobro();
    if (errorBase != null) {
      return errorBase;
    }
    final total = calcularTotalCarrito() - request.descuentoTicket;
    if (total <= 0.0) {
      return 'Total invalido';
    }
    if (request.metodoPago == MetodoPago.credito) {
      final dias = request.diasCredito ?? _clienteActivo?.diasCredito;
      return validarClienteParaCredito(_clienteActivo, diasCredito: dias);
    }
    if (request.metodoPago == MetodoPago.mixto) {
      final efectivo = request.montoEfectivo ?? 0.0;
      final tarjeta = request.montoTarjeta ?? 0.0;
      final transferencia = request.montoTransferencia ?? 0.0;
      final suma = redondearMonto(efectivo + tarjeta + transferencia);
      if ((suma - total).abs() > 0.01) {
        return 'Montos mixtos deben sumar ${formatearMoneda(total)}';
      }
    }
    return null;
  }

  /// Convierte lineas del carrito al formato de venta/cotizacion.
  List<LineaVenta> lineasCarritoComoVenta() {
    return _lineasCarrito
        .map(
          (linea) => LineaVenta(
            productoId: linea.producto.id,
            nombreProducto: linea.etiquetaLote != null && linea.etiquetaLote!.isNotEmpty
                ? '${linea.producto.nombre} (${linea.etiquetaLote})'
                : linea.producto.nombre,
            cantidad: linea.cantidad,
            precioUnitario: linea.precioUnitario,
            reglaPrecio: linea.reglaPrecio,
            loteId: linea.loteId,
            etiquetaLote: linea.etiquetaLote,
          ),
        )
        .toList();
  }

  /// Registra cotizacion persistida desde el carrito actual.
  Future<Cotizacion> registrarCotizacionCarrito({
    String? notas,
    int vigenciaDias = VIGENCIA_COTIZACION_DIAS,
  }) async {
    if (_lineasCarrito.isEmpty) {
      throw StateError('El carrito esta vacio');
    }
    final repo = _cotizacionRepository;
    if (repo == null) {
      throw StateError('Repositorio de cotizaciones no configurado');
    }
    final lineas = _lineasCarrito
        .map(
          (linea) => LineaCotizacion(
            productoId: linea.producto.id,
            nombreProducto: linea.etiquetaLote != null && linea.etiquetaLote!.isNotEmpty
                ? '${linea.producto.nombre} (${linea.etiquetaLote})'
                : linea.producto.nombre,
            cantidad: linea.cantidad,
            precioUnitario: linea.precioUnitario,
            reglaPrecio: linea.reglaPrecio,
          ),
        )
        .toList();
    final cotizacion = Cotizacion(
      id: _generadorId.v4(),
      tiendaId: _tiendaId,
      clienteId: _clienteActivo?.id,
      nombreCliente: _clienteActivo?.nombre,
      total: calcularTotalCarrito(),
      notas: notas?.trim() ?? '',
      vigenciaDias: vigenciaDias,
      creadaEn: DateTime.now().toUtc(),
      cajaId: _cajaId,
      vendedorId: _vendedorActivo?.id,
      lineas: lineas,
    );
    await repo.guardar(cotizacion);
    return cotizacion;
  }

  /// Aplica descuento absoluto a una linea del carrito.
  void aplicarDescuentoLinea(int indice, double descuento) {
    if (indice < 0 || indice >= _lineasCarrito.length) {
      return;
    }
    final linea = _lineasCarrito[indice];
    _lineasCarrito[indice] = linea.copiarCon(
      descuentoLinea: descuento < 0.0 ? 0.0 : descuento,
    );
  }

  /// Lista productos favoritos configurados para caja rapida.
  Future<List<Producto>> listarFavoritosCaja() async {
    return _productoRepository.listarFavoritosCaja(_tiendaId);
  }

  /// Obtiene total vendido en el dia para la tienda activa.
  ///
  /// Retorna suma de ventas del dia en MXN.
  Future<double> obtenerTotalDelDia() async {
    return _ventaRepository.calcularTotalDelDia(_tiendaId);
  }

  /// Agrega linea al carrito resolviendo precio comercial.
  ///
  /// [producto] Producto vendido.
  /// [cantidad] Cantidad o peso en kg.
  /// [loteId] Lote farmacia opcional.
  /// [etiquetaLote] Etiqueta visible de lote o peso.
  /// [permitirFusion] Indica si puede sumarse a linea existente.
  Future<void> _agregarLineaCarrito({
    required Producto producto,
    required double cantidad,
    required String? loteId,
    required String? etiquetaLote,
    required bool permitirFusion,
  }) async {
    final contexto = ContextoPrecio(
      producto: producto,
      cantidad: cantidad,
      tiendaId: _tiendaId,
      cliente: _clienteActivo,
      canal: producto.moduloVertical == ModuloVertical.carniceria
          ? CanalVenta.mayoreo
          : CanalVenta.mostrador,
    );
    final resultado = await _motorPrecio.resolverPrecio(contexto);
    if (permitirFusion) {
      final indiceExistente = _buscarIndiceLineaGeneral(producto.id);
      if (indiceExistente >= 0) {
        final lineaActual = _lineasCarrito[indiceExistente];
        final cantidadNueva = lineaActual.cantidad + cantidad;
        final contextoActualizado = ContextoPrecio(
          producto: producto,
          cantidad: cantidadNueva,
          tiendaId: _tiendaId,
          cliente: _clienteActivo,
          canal: CanalVenta.mostrador,
        );
        final precioActualizado = await _motorPrecio.resolverPrecio(
          contextoActualizado,
        );
        _lineasCarrito[indiceExistente] = lineaActual.copiarCon(
          cantidad: cantidadNueva,
          precioUnitario: precioActualizado.precioUnitario,
          reglaPrecio: precioActualizado.reglaAplicada,
        );
        await _aplicarDescuentosCliente();
        return;
      }
    }
    _lineasCarrito.add(
      LineaCarrito(
        producto: producto,
        cantidad: cantidad,
        precioUnitario: resultado.precioUnitario,
        reglaPrecio: resultado.reglaAplicada,
        loteId: loteId,
        etiquetaLote: etiquetaLote,
      ),
    );
    await _aplicarDescuentosCliente();
  }

  Future<void> _sincronizarClienteEnCarrito() async {
    await _recalcularPreciosCarrito();
    await _aplicarDescuentosCliente();
  }

  Future<void> _aplicarDescuentosCliente() async {
    _descuentoTicketCliente = 0.0;
    for (var i = 0; i < _lineasCarrito.length; i++) {
      _lineasCarrito[i] = _lineasCarrito[i].copiarCon(descuentoLinea: 0.0);
    }
  }

  /// Recalcula precio unitario de cada linea segun cliente activo.
  Future<void> _recalcularPreciosCarrito() async {
    final lineasActualizadas = <LineaCarrito>[];
    for (final linea in _lineasCarrito) {
      final contexto = ContextoPrecio(
        producto: linea.producto,
        cantidad: linea.cantidad,
        tiendaId: _tiendaId,
        cliente: _clienteActivo,
        canal: linea.producto.moduloVertical == ModuloVertical.carniceria
            ? CanalVenta.mayoreo
            : CanalVenta.mostrador,
      );
      final resultado = await _motorPrecio.resolverPrecio(contexto);
      lineasActualizadas.add(
        linea.copiarCon(
          precioUnitario: resultado.precioUnitario,
          reglaPrecio: resultado.reglaAplicada,
        ),
      );
    }
    _lineasCarrito
      ..clear()
      ..addAll(lineasActualizadas);
  }

  /// Descuenta lotes farmaceuticos vendidos tras cerrar venta.
  ///
  /// [venta] Venta completada con lineas de lote.
  Future<void> _aplicarDescuentosLote(Venta venta) async {
    final servicioFarmacia = _servicioFarmacia;
    if (servicioFarmacia == null) {
      return;
    }
    for (final linea in venta.lineas) {
      final loteId = linea.loteId;
      if (loteId == null) {
        continue;
      }
      await servicioFarmacia.aplicarVentaLote(loteId, linea.cantidad);
    }
  }

  /// Busca linea general fusionable sin lote asociado.
  ///
  /// [productoId] Identificador del producto.
  /// Retorna indice o -1 si no existe.
  int _buscarIndiceLineaGeneral(String productoId) {
    var indice = 0;
    for (final linea in _lineasCarrito) {
      final esGeneral = linea.producto.moduloVertical == ModuloVertical.general;
      final sinLote = linea.loteId == null;
      if (linea.producto.id == productoId && esGeneral && sinLote) {
        return indice;
      }
      indice = indice + 1;
    }
    return -1;
  }

  /// Encola evento SaleCompleted para sincronizacion.
  ///
  /// [venta] Venta recien cerrada.
  Future<void> _registrarEventoVenta(Venta venta) async {
    final evento = SyncEvent(
      id: _generadorId.v4(),
      tenantId: _tenantId,
      tiendaId: _tiendaId,
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
}
