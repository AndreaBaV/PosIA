/// Servicio de operaciones de caja: carrito, cobro e inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'dart:async';

import 'package:posia_core/posia_core.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_farmacia_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/ticket_espera_repository.dart';
import '../repositories/presentacion_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../utils/sincronizador_vendedor_usuario.dart';
import '../repositories/venta_repository.dart';
import 'servicio_carniceria.dart';
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
  /// [tiendaId] Tienda de la caja.
  /// [cajaId] Identificador de caja registradora.
  ServicioCaja({
    required ProductoRepository productoRepository,
    required InventarioRepository inventarioRepository,
    LoteFarmaciaRepository? loteFarmaciaRepository,
    required Database baseDatos,
    VarianteRepository? varianteRepository,
    PresentacionRepository? presentacionRepository,
    required ClienteRepository clienteRepository,
    required VentaRepository ventaRepository,
    required MotorPrecio motorPrecio,
    required GestorInventario gestorInventario,
    required SyncOrchestrator syncOrchestrator,
    ServicioCarniceria? servicioCarniceria,
    ServicioFarmacia? servicioFarmacia,
    CategoriaRepository? categoriaRepository,
    VendedorRepository? vendedorRepository,
    CotizacionRepository? cotizacionRepository,
    TicketEsperaRepository? ticketEsperaRepository,
    ServicioCorteCaja? servicioCorteCaja,
    required String tiendaId,
    required String cajaId,
  }) : _productoRepository = productoRepository,
       _inventarioRepository = inventarioRepository,
       _loteFarmaciaRepository = loteFarmaciaRepository,
       _baseDatos = baseDatos,
       _varianteRepository = varianteRepository,
       _presentacionRepository = presentacionRepository,
       _clienteRepository = clienteRepository,
       _ventaRepository = ventaRepository,
       _motorPrecio = motorPrecio,
       _gestorInventario = gestorInventario,
       _syncOrchestrator = syncOrchestrator,
       _servicioCarniceria = servicioCarniceria,
       _servicioFarmacia = servicioFarmacia,
       _categoriaRepository = categoriaRepository,
       _vendedorRepository = vendedorRepository,
       _cotizacionRepository = cotizacionRepository,
       _ticketEsperaRepository = ticketEsperaRepository,
       _servicioCorteCaja = servicioCorteCaja,
       _tiendaId = tiendaId,
       _cajaId = cajaId;

  final ProductoRepository _productoRepository;
  final InventarioRepository _inventarioRepository;
  final LoteFarmaciaRepository? _loteFarmaciaRepository;
  final Database _baseDatos;
  final VarianteRepository? _varianteRepository;
  final PresentacionRepository? _presentacionRepository;
  final ClienteRepository _clienteRepository;
  final VentaRepository _ventaRepository;
  final MotorPrecio _motorPrecio;
  final GestorInventario _gestorInventario;
  final SyncOrchestrator _syncOrchestrator;
  final ServicioCarniceria? _servicioCarniceria;
  final ServicioFarmacia? _servicioFarmacia;
  final CategoriaRepository? _categoriaRepository;
  final VendedorRepository? _vendedorRepository;
  final CotizacionRepository? _cotizacionRepository;
  final TicketEsperaRepository? _ticketEsperaRepository;
  final ServicioCorteCaja? _servicioCorteCaja;
  final String _tiendaId;
  final String _cajaId;

  final List<LineaCarrito> _lineasCarrito = [];
  Cliente? _clienteActivo;
  Vendedor? _vendedorActivo;
  final Uuid _generadorId = const Uuid();

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
    if (repo != null) {
      final vendedor = await SincronizadorVendedorUsuario.sincronizar(
        repo: repo,
        usuario: usuario,
      );
      _vendedorActivo = vendedor;
      return vendedor;
    }
    final vendedor = Vendedor(
      id: SincronizadorVendedorUsuario.idVendedorParaUsuario(usuario.id),
      nombre: usuario.nombre,
      codigo: usuario.codigo,
      activo: usuario.activo,
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
    final errorStock = await _validarStockCarrito();
    if (errorStock != null) {
      return errorStock;
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

  /// Resuelve precio comercial para producto y cantidad sin modificar carrito.
  Future<ResultadoPrecio> resolverPrecioVenta(
    Producto producto,
    double cantidad,
  ) async {
    final contexto = ContextoPrecio(
      producto: producto,
      cantidad: cantidad,
      tiendaId: _tiendaId,
      cliente: _clienteActivo,
      canal: _canalVentaProducto(producto),
    );
    return _motorPrecio.resolverPrecio(contexto);
  }

  /// Agrega producto general al carrito con cantidad en piezas.
  ///
  /// [producto] Producto seleccionado.
  /// [cantidad] Cantidad a agregar; default 1.0.
  Future<void> agregarProducto(
    Producto producto, {
    double cantidad = 1.0,
  }) async {
    final errorStock = await _validarStockParaAgregar(producto, cantidad);
    if (errorStock != null) {
      throw StateError(errorStock);
    }
    await _agregarLineaCarrito(
      producto: producto,
      cantidad: cantidad,
      loteId: null,
      etiquetaLote: null,
      permitirFusion: true,
      factorABase: 1.0,
      productoStockId: null,
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
    var pesoValidado = pesoKg;
    final servicioCarniceria = _servicioCarniceria;
    if (servicioCarniceria != null) {
      final resultado = servicioCarniceria.validarPesoParaVenta(pesoKg);
      if (!resultado.valido) {
        return resultado.mensajeError;
      }
      pesoValidado = resultado.pesoKg;
    } else if (pesoKg <= 0.0) {
      return 'El peso debe ser mayor a cero';
    } else if (!validarPesoMinimoKg(pesoKg)) {
      return 'Peso minimo: ${formatearPesoKg(convertirGramosAKilogramos(PESO_MINIMO_GRAMOS_CARNICERIA))}';
    }
    await _agregarLineaCarrito(
      producto: producto,
      cantidad: pesoValidado,
      loteId: null,
      etiquetaLote: formatearPesoKg(pesoValidado),
      permitirFusion: true,
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

  /// Indica si el producto tiene presentaciones comerciales activas.
  Future<bool> productoTienePresentaciones(String productoId) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      return false;
    }
    final presentaciones = await repo.listarActivasPorProducto(productoId);
    return presentaciones.any((p) => !p.esPresentacionBase);
  }

  /// Lista presentaciones activas (excluye solo la base si es unica).
  Future<List<PresentacionProducto>> listarPresentacionesActivas(
    String productoId,
  ) async {
    final repo = _presentacionRepository;
    if (repo == null) {
      return [];
    }
    final presentaciones = await repo.listarActivasPorProducto(productoId);
    return presentaciones.where((p) => !p.esPresentacionBase).toList();
  }

  /// Agrega presentacion comercial al carrito con factor de inventario.
  Future<void> agregarPresentacion(
    PresentacionProducto presentacion, {
    double cantidad = 1.0,
  }) async {
    final padre = await _productoRepository.obtenerPorId(presentacion.productoId);
    if (padre == null) {
      return;
    }
    if (presentacion.esPresentacionBase) {
      await agregarProducto(padre, cantidad: cantidad);
      return;
    }
    final productoVenta = padre.copiarCon(
      id: presentacion.id,
      nombre: '${padre.nombre} - ${presentacion.nombre}',
      codigoBarras: presentacion.codigoBarras,
      precioBase: presentacion.precio ??
          redondearMonto(padre.precioBase * presentacion.factorABase),
    );
    final errorStock = await _validarStockParaAgregar(
      productoVenta,
      cantidad,
      factorABase: presentacion.factorABase,
      productoStockId: presentacion.productoId,
    );
    if (errorStock != null) {
      throw StateError(errorStock);
    }
    await _agregarLineaCarrito(
      producto: productoVenta,
      cantidad: cantidad,
      loteId: null,
      etiquetaLote: null,
      permitirFusion: true,
      factorABase: presentacion.factorABase,
      productoStockId: presentacion.productoId,
    );
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
    final presentacion = await _presentacionRepository?.buscarPorCodigoBarras(
      codigoBarras,
    );
    if (presentacion != null) {
      await agregarPresentacion(presentacion);
      return true;
    }
    final variante = await _varianteRepository?.buscarPorCodigoBarras(
      codigoBarras,
    );
    if (variante != null) {
      await agregarVariante(variante);
      return true;
    }
    final producto = await _productoRepository.buscarPorCodigoBarras(
      codigoBarras,
      tiendaId: _tiendaId,
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
  }

  /// Vacia el carrito activo sin persistir venta.
  void vaciarCarrito() {
    _lineasCarrito.clear();
    _clienteActivo = null;
  }

  /// Lista tickets apartados en esta tienda y caja.
  Future<List<TicketEnEspera>> listarTicketsEnEspera() async {
    final repo = _ticketEsperaRepository;
    if (repo == null) {
      return [];
    }
    return repo.listarPorTiendaCaja(_tiendaId, _cajaId);
  }

  /// Cantidad de carritos apartados en esta caja.
  Future<int> contarTicketsEnEspera() async {
    final repo = _ticketEsperaRepository;
    if (repo == null) {
      return 0;
    }
    return repo.contarPorTiendaCaja(_tiendaId, _cajaId);
  }

  /// Guarda el carrito actual en espera y deja la caja libre.
  Future<String> ponerCarritoEnEspera({String notas = ''}) async {
    if (_lineasCarrito.isEmpty) {
      throw StateError('El carrito esta vacio');
    }
    final repo = _ticketEsperaRepository;
    if (repo == null) {
      throw StateError('Tickets en espera no disponibles');
    }
    final ticket = TicketEnEspera(
      id: _generadorId.v4(),
      tiendaId: _tiendaId,
      cajaId: _cajaId,
      clienteId: _clienteActivo?.id,
      nombreCliente: _clienteActivo?.nombre,
      vendedorId: _vendedorActivo?.id,
      notas: notas.trim(),
      descuentoTicket: 0.0,
      total: calcularTotalCarrito(),
      creadoEn: DateTime.now().toUtc(),
      lineas: _lineasCarrito
          .map(LineaTicketEspera.desdeLineaCarrito)
          .toList(),
    );
    await repo.guardar(ticket);
    vaciarCarrito();
    return ticket.id;
  }

  /// Restaura un ticket apartado al carrito activo.
  Future<void> recuperarTicketEnEspera(String ticketId) async {
    final repo = _ticketEsperaRepository;
    if (repo == null) {
      throw StateError('Tickets en espera no disponibles');
    }
    final ticket = await repo.obtenerPorId(ticketId);
    if (ticket == null) {
      throw StateError('Ticket en espera no encontrado');
    }
    _lineasCarrito.clear();
    _clienteActivo = null;
    if (ticket.clienteId != null) {
      _clienteActivo = await _clienteRepository.obtenerPorId(ticket.clienteId!);
    }
    _vendedorActivo = null;
    if (ticket.vendedorId != null) {
      _vendedorActivo = await _vendedorRepository?.obtenerPorId(ticket.vendedorId!);
    }
    for (final linea in ticket.lineas) {
      final producto = await _productoRepository.obtenerPorId(linea.productoId);
      _lineasCarrito.add(
        linea.aLineaCarrito(producto ?? linea.productoRespaldo(_tiendaId)),
      );
    }
    await repo.eliminar(ticketId);
  }

  /// Elimina un ticket apartado sin recuperarlo.
  Future<void> eliminarTicketEnEspera(String ticketId) async {
    final repo = _ticketEsperaRepository;
    if (repo == null) {
      throw StateError('Tickets en espera no disponibles');
    }
    await repo.eliminar(ticketId);
  }

  /// Indica si el carrito activo tiene lineas.
  bool carritoTieneLineas() => _lineasCarrito.isNotEmpty;

  /// Calcula total del carrito activo.
  ///
  /// Retorna monto total redondeado en MXN.
  double calcularTotalCarrito() {
    var acumulado = 0.0;
    for (final linea in _lineasCarrito) {
      acumulado = acumulado + linea.calcularSubtotal();
    }
    return redondearMonto(acumulado < 0.0 ? 0.0 : acumulado);
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
    final total = Venta.calcularTotalDesdeLineas(lineasVenta);
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
    final lineasInventario = await _prepararLineasInventario();
    final turno = await _servicioCorteCaja?.obtenerTurnoAbierto();
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
      descuentoTicket: 0.0,
      montoEfectivo: montoEfectivo,
      montoTarjeta: montoTarjeta,
      montoTransferencia: montoTransferencia,
      creditoDias: creditoDias,
      creditoVenceEn: creditoVenceEn,
    );
    TurnoCaja? turnoActualizado;
    await _baseDatos.transaction((tx) async {
      await _ventaRepository.guardar(venta, db: tx);
      if (turno != null && _servicioCorteCaja != null) {
        turnoActualizado = await _servicioCorteCaja.registrarVenta(
          turno,
          venta,
          db: tx,
        );
      }
      await _aplicarInventarioVentaTransaccional(tx, lineasInventario);
      await _aplicarDescuentosLoteTransaccional(tx, venta);
    });
    vaciarCarrito();
    if (turnoActualizado != null) {
      unawaited(
        _servicioCorteCaja?.notificarTurnoActualizado(turnoActualizado!),
      );
    }
    unawaited(_registrarEventoVenta(venta));
    return venta;
  }

  /// Valida cobro con multipago y credito.
  Future<String?> validarCobroRequest(CobroRequest request) async {
    final errorBase = await validarCobro();
    if (errorBase != null) {
      return errorBase;
    }
    final total = calcularTotalCarrito();
    if (total <= 0.0) {
      return 'Total invalido';
    }
    if (request.metodoPago == MetodoPago.efectivo) {
      final recibido = request.montoRecibido;
      if (recibido == null || recibido <= 0.0) {
        return 'Indique el monto recibido en efectivo';
      }
      if (redondearMonto(recibido) < redondearMonto(total)) {
        return 'Monto recibido insuficiente';
      }
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
    await _syncOrchestrator.registrarEvento(
      SyncEvent(
        id: _generadorId.v4(),
        tiendaId: cotizacion.tiendaId,
        dispositivoId: _cajaId,
        tipo: TipoSyncEvento.quoteUpserted,
        payload: {
          'id': cotizacion.id,
          'tiendaId': cotizacion.tiendaId,
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
    return cotizacion;
  }

  /// Lista productos favoritos configurados para caja rapida.
  Future<List<Producto>> listarFavoritosCaja() async {
    return _productoRepository.listarFavoritosCaja(_tiendaId);
  }

  /// Mapa productoId -> existencia en la tienda activa de caja.
  Future<Map<String, double>> mapaStockLocalTienda() async {
    final stocks = await _inventarioRepository.listarStockPorTienda(_tiendaId);
    return {for (final stock in stocks) stock.productoId: stock.cantidad};
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
    double factorABase = 1.0,
    String? productoStockId,
  }) async {
    final contexto = ContextoPrecio(
      producto: producto,
      cantidad: cantidad,
      tiendaId: _tiendaId,
      cliente: _clienteActivo,
      canal: _canalVentaProducto(producto),
    );
    final resultado = await _motorPrecio.resolverPrecio(contexto);
    if (permitirFusion) {
      final indiceExistente = _buscarIndiceLineaFusionable(producto.id);
      if (indiceExistente >= 0) {
        final lineaActual = _lineasCarrito[indiceExistente];
        if (lineaActual.factorABase == factorABase &&
            lineaActual.productoStockId == productoStockId) {
          final cantidadNueva = lineaActual.cantidad + cantidad;
          final contextoActualizado = ContextoPrecio(
            producto: producto,
            cantidad: cantidadNueva,
            tiendaId: _tiendaId,
            cliente: _clienteActivo,
            canal: _canalVentaProducto(producto),
          );
          final precioActualizado = await _motorPrecio.resolverPrecio(
            contextoActualizado,
          );
          _lineasCarrito[indiceExistente] = lineaActual.copiarCon(
            cantidad: cantidadNueva,
            precioUnitario: precioActualizado.precioUnitario,
            reglaPrecio: precioActualizado.reglaAplicada,
            etiquetaLote: _etiquetaLoteFusionada(producto, cantidadNueva) ??
                lineaActual.etiquetaLote,
          );
          return;
        }
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
        factorABase: factorABase,
        productoStockId: productoStockId,
      ),
    );
  }

  Future<void> _sincronizarClienteEnCarrito() async {
    await _recalcularPreciosCarrito();
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

  /// Busca linea general fusionable sin lote asociado.
  ///
  /// [productoId] Identificador del producto.
  /// Retorna indice o -1 si no existe.
  int _buscarIndiceLineaFusionable(String productoId) {
    var indice = 0;
    for (final linea in _lineasCarrito) {
      if (linea.producto.id == productoId && linea.loteId == null) {
        return indice;
      }
      indice = indice + 1;
    }
    return -1;
  }

  CanalVenta _canalVentaProducto(Producto producto) {
    return producto.moduloVertical == ModuloVertical.carniceria
        ? CanalVenta.mayoreo
        : CanalVenta.mostrador;
  }

  String? _etiquetaLoteFusionada(Producto producto, double cantidadTotal) {
    if (producto.requierePeso() ||
        producto.moduloVertical == ModuloVertical.carniceria) {
      return formatearPesoKg(cantidadTotal);
    }
    return null;
  }

  /// Encola evento SaleCompleted para sincronizacion.
  ///
  /// [venta] Venta recien cerrada.
  Future<void> _registrarEventoVenta(Venta venta) async {
    final evento = SyncEvent(
      id: _generadorId.v4(),
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

  Future<String?> _validarStockCarrito() async {
    final cantidadesPorProducto = <String, double>{};
    for (final linea in _lineasCarrito) {
      final stockId =
          linea.productoStockId ?? await _resolverIdStock(linea.producto);
      final cantidadBase = linea.cantidad * linea.factorABase;
      cantidadesPorProducto[stockId] =
          (cantidadesPorProducto[stockId] ?? 0) + cantidadBase;
    }
    for (final entry in cantidadesPorProducto.entries) {
      final producto = await _productoRepository.obtenerPorId(entry.key);
      if (producto == null || producto.permiteStockNegativo) {
        continue;
      }
      final disponible = await _gestorInventario.obtenerCantidadDisponible(
        entry.key,
        _tiendaId,
      );
      if (disponible < entry.value) {
        return 'Stock insuficiente: ${producto.nombre} '
            '(disponible ${disponible.toStringAsFixed(1)}, '
            'requerido ${entry.value.toStringAsFixed(1)})';
      }
    }
    return null;
  }

  Future<String?> _validarStockParaAgregar(
    Producto producto,
    double cantidadAgregar, {
    double factorABase = 1.0,
    String? productoStockId,
  }) async {
    final stockId = productoStockId ?? await _resolverIdStock(producto);
    final productoStock = stockId == producto.id
        ? producto
        : await _productoRepository.obtenerPorId(stockId);
    if (productoStock?.permiteStockNegativo == true) {
      return null;
    }
    if (producto.permiteStockNegativo && productoStockId == null) {
      return null;
    }
    var cantidadEnCarrito = 0.0;
    for (final linea in _lineasCarrito) {
      final lineaStockId =
          linea.productoStockId ?? await _resolverIdStock(linea.producto);
      if (lineaStockId == stockId) {
        cantidadEnCarrito += linea.cantidad * linea.factorABase;
      }
    }
    final totalRequerido =
        cantidadEnCarrito + (cantidadAgregar * factorABase);
    final disponible = await _gestorInventario.obtenerCantidadDisponible(
      stockId,
      _tiendaId,
    );
    if (disponible < totalRequerido) {
      final nombre = productoStock?.nombre ?? producto.nombre;
      return 'Stock insuficiente: $nombre '
          '(disponible ${disponible.toStringAsFixed(1)})';
    }
    return null;
  }

  Future<String> _resolverIdStock(Producto producto) async {
    final padre = await _productoRepository.obtenerPorId(producto.id);
    if (padre != null) {
      return producto.id;
    }
    final presentacion = await _presentacionRepository?.obtenerPorId(
      producto.id,
    );
    if (presentacion != null) {
      return presentacion.productoId;
    }
    final variante = await _varianteRepository?.obtenerPorId(producto.id);
    if (variante != null) {
      return variante.productoPadreId;
    }
    return producto.id;
  }

  /// Resuelve ids de stock antes de abrir transaccion SQLite (evita deadlock).
  Future<List<LineaCarrito>> _prepararLineasInventario() async {
    final preparadas = <LineaCarrito>[];
    for (final linea in _lineasCarrito) {
      if (linea.productoStockId != null) {
        preparadas.add(linea);
        continue;
      }
      preparadas.add(
        linea.copiarCon(
          productoStockId: await _resolverIdStock(linea.producto),
        ),
      );
    }
    return preparadas;
  }

  Future<void> _aplicarInventarioVentaTransaccional(
    Transaction tx,
    List<LineaCarrito> lineas,
  ) async {
    final ahora = DateTime.now().toUtc();
    for (final linea in lineas) {
      final stockId = linea.productoStockId;
      if (stockId == null) {
        throw StateError('Stock no resuelto para ${linea.producto.nombre}');
      }
      final cantidadBase = linea.cantidad * linea.factorABase;
      final stock = await _inventarioRepository.obtenerStock(
        stockId,
        _tiendaId,
        db: tx,
      );
      await _inventarioRepository.guardarStock(
        StockNivel(
          productoId: stockId,
          tiendaId: _tiendaId,
          cantidad: (stock?.cantidad ?? 0.0) - cantidadBase,
          actualizadoEn: ahora,
          stockMinimo: stock?.stockMinimo ?? 0.0,
        ),
        db: tx,
      );
    }
  }

  Future<void> _aplicarDescuentosLoteTransaccional(
    Transaction tx,
    Venta venta,
  ) async {
    final loteRepo = _loteFarmaciaRepository;
    if (loteRepo == null) {
      return;
    }
    for (final linea in venta.lineas) {
      final loteId = linea.loteId;
      if (loteId == null) {
        continue;
      }
      await loteRepo.descontarCantidad(loteId, linea.cantidad, db: tx);
    }
  }
}
