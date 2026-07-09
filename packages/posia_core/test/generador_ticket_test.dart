import 'package:test/test.dart';
import 'package:posia_core/posia_core.dart';

void main() {
  test('generarTextoTicket incluye total y tienda', () {
    final venta = Venta(
      id: 'venta-test-001',
      tiendaId: 'tienda-test',
      cajaId: 'caja-1',
      clienteId: null,
      total: 100.0,
      metodoPago: MetodoPago.efectivo,
      estado: EstadoVenta.completada,
      creadaEn: DateTime.utc(2026, 6, 11, 20, 30),
      vendedorId: 'vend-001',
      turnoCajaId: 'turno-test-001',
      lineas: const [
        LineaVenta(
          productoId: 'prod-1',
          nombreProducto: 'Producto demo',
          cantidad: 2,
          precioUnitario: 50.0,
          reglaPrecio: ReglaPrecio.precioBase,
        ),
      ],
    );
    final texto = generarTextoTicket(
      venta: venta,
      nombreTienda: 'Tienda Centro',
      direccionTienda: 'Av. Principal 123',
      nombreVendedor: 'Juan Perez',
      codigoVendedor: '001',
      nombreCliente: 'Maria Garcia',
      telefonoCliente: '5551234567',
    );
    expect(texto, contains('Tienda Centro'));
    expect(texto, contains('LA FORTUNA'));
    expect(texto, contains('Av. Principal 123'));
    expect(texto, contains('Atendió: Juan Perez'));
    expect(texto, contains('Maria Garcia'));
    expect(texto, isNot(contains('Publico en general')));
    expect(texto, contains('11/06/2026'));
    expect(texto, isNot(contains('TURNO')));
    expect(texto, contains('110626-T001'));
    expect(texto, contains('100'));
  });

  test('generarTextoTicket muestra publico en general sin cliente', () {
    final venta = Venta(
      id: 'venta-test-002',
      tiendaId: 'tienda-test',
      cajaId: 'caja-1',
      clienteId: null,
      total: 50.0,
      metodoPago: MetodoPago.efectivo,
      estado: EstadoVenta.completada,
      creadaEn: DateTime.utc(2026, 6, 11),
      lineas: const [],
    );
    final texto = generarTextoTicket(
      venta: venta,
      nombreTienda: 'Tienda Centro',
    );
    expect(texto, contains('Publico en general'));
  });

  test('generarTextoCorteCaja incluye efectivo esperado', () {
    final turno = TurnoCaja(
      id: 'turno-test-001',
      tiendaId: 'tienda-test',
      cajaId: 'caja-1',
      vendedorId: null,
      fondoInicial: 500.0,
      totalEfectivo: 1200.0,
      totalTarjeta: 0.0,
      totalTransferencia: 0.0,
      totalVentas: 1200.0,
      cantidadVentas: 8,
      abiertoEn: DateTime.utc(2026, 6, 11, 8),
      cerradoEn: DateTime.utc(2026, 6, 11, 20),
      estado: EstadoTurnoCaja.cerrado,
    );
    final texto = generarTextoCorteCaja(
      turno: turno,
      nombreTienda: 'Tienda Centro',
    );
    expect(texto, contains('CORTE DE CAJA'));
    expect(texto, contains('1700'));
  });

  test('generarTextoComprobanteTraspaso incluye recibido y firmas', () {
    final traspaso = Traspaso(
      id: 'traspaso-test-001',
      tiendaOrigenId: 't1',
      tiendaDestinoId: 't2',
      estado: EstadoTraspaso.completado,
      solicitadoEn: DateTime.utc(2026, 6, 22, 18),
      completadoEn: DateTime.utc(2026, 6, 22, 18),
      notas: 'Urgente',
      lineas: const [
        LineaTraspaso(
          productoId: 'p1',
          nombreProducto: 'Arroz 1kg',
          cantidadSolicitada: 10,
          cantidadRecibida: 10,
        ),
        LineaTraspaso(
          productoId: 'p2',
          nombreProducto: 'Frijol 1kg',
          cantidadSolicitada: 5,
          cantidadRecibida: 5,
        ),
      ],
    );
    final ticket = generarTextoTicketTraspaso(
      traspaso: traspaso,
      nombreTiendaOrigen: 'Centro',
      nombreTiendaDestino: 'Norte',
      nombreOperador: 'Ana',
    );
    final comprobante = generarTextoComprobanteTraspaso(
      traspaso: traspaso,
      nombreTiendaOrigen: 'Centro',
      nombreTiendaDestino: 'Norte',
      nombreOperadorEnvio: 'Ana',
    );
    expect(ticket, contains('TRASPASO LA FORTUNA'));
    expect(ticket, contains('Arroz 1kg'));
    expect(ticket, contains('Total unidades: 15'));
    expect(comprobante, contains('PRODUCTOS RECIBIDOS'));
    expect(comprobante, contains('RECIBE:'));
    expect(comprobante, contains('Ana'));
  });

  test('generarTextoPagareCredito incluye copia y firma', () {
    final venta = Venta(
      id: 'venta-credito-001',
      tiendaId: 'tienda-test',
      cajaId: 'caja-1',
      clienteId: 'cli-1',
      total: 250.0,
      metodoPago: MetodoPago.credito,
      estado: EstadoVenta.completada,
      creadaEn: DateTime.utc(2026, 6, 22, 10),
      creditoDias: 15,
      creditoVenceEn: DateTime.utc(2026, 7, 7),
      lineas: const [
        LineaVenta(
          productoId: 'p1',
          nombreProducto: 'Arroz 1kg',
          cantidad: 2,
          precioUnitario: 125.0,
          reglaPrecio: ReglaPrecio.precioBase,
        ),
      ],
    );
    final texto = generarTextoPagareCredito(
      venta: venta,
      nombreTienda: 'Abarrotes Centro',
      nombreCliente: 'Juan Lopez',
      telefonoCliente: '5551234567',
      direccionCliente: 'Calle 5 #10',
      etiquetaCopia: 'COPIA CLIENTE',
    );
    expect(texto, contains('PAGARE LA FORTUNA'));
    expect(texto, contains('COPIA CLIENTE'));
    expect(texto, contains('Juan Lopez'));
    expect(
      texto,
      anyOf(contains('UNA SOLA EXHIBICION'), contains('una sola exhibición')),
    );
    expect(texto, contains('FIRMA DEL DEUDOR'));
    expect(texto, contains('Plazo: 15 día(s)'));
    expect(texto, contains('Vence:'));
  });

  test('generarTextoCotizacion incluye folio y total', () {
    final texto = generarTextoCotizacion(
      id: 'cotizacion-abc-123',
      nombreTienda: 'Tienda Norte',
      lineas: const [
        LineaVenta(
          productoId: 'p1',
          nombreProducto: 'Aceite 1L',
          cantidad: 3,
          precioUnitario: 40.0,
          reglaPrecio: ReglaPrecio.precioBase,
        ),
      ],
      total: 120.0,
      creadaEn: DateTime.utc(2026, 6, 22),
      nombreCliente: 'Maria',
    );
    expect(texto, contains('COTIZACION'));
    expect(texto, contains('COTIZACI'));
    expect(texto, contains('120'));
    expect(texto, contains('Maria'));
  });

  test('generarTextoCompra incluye proveedor y total', () {
    final texto = generarTextoCompra(
      compra: Compra(
        id: 'compra-abc-123',
        tiendaId: 't1',
        proveedorId: 'prov1',
        fechaCompra: DateTime.utc(2026, 6, 10),
        notas: 'Entrega parcial',
        total: 250.0,
        creadaEn: DateTime.utc(2026, 6, 10, 12),
        lineas: const [
          LineaCompra(
            productoId: 'p1',
            nombreProducto: 'Arroz 1kg',
            cantidad: 10,
            costoUnitario: 25.0,
            subtotal: 250.0,
          ),
        ],
      ),
      nombreProveedor: 'Distribuidora Norte',
      nombreTienda: 'Tienda Centro',
    );
    expect(texto, contains('COMPRA'));
    expect(texto, contains('Distribuidora Norte'));
    expect(texto, contains('250'));
  });

  test('generarTextoPedido incluye entrega y total', () {
    final texto = generarTextoPedido(
      pedido: Pedido(
        id: 'pedido-abc-123',
        tiendaId: 't1',
        nombreEntrega: 'Ana Perez',
        telefonoEntrega: '5551234567',
        direccionEntrega: 'Calle 5 #10',
        esCredito: false,
        metodoPago: MetodoPago.efectivo,
        total: 180.0,
        estado: EstadoPedido.recibido,
        creadoEn: DateTime.utc(2026, 6, 12),
        lineas: const [
          LineaPedido(
            productoId: 'p1',
            nombreProducto: 'Aceite',
            cantidad: 2,
            precioUnitario: 90.0,
          ),
        ],
      ),
      nombreTienda: 'Tienda Centro',
    );
    expect(texto, contains('PEDIDO'));
    expect(texto, contains('Ana Perez'));
    expect(texto, contains('180'));
  });

  test('generarTextoLiquidacionCredito marca credito pagado', () {
    final venta = Venta(
      id: 'venta-credito-002',
      tiendaId: 'tienda-test',
      cajaId: 'caja-1',
      clienteId: 'cli-1',
      total: 500.0,
      metodoPago: MetodoPago.credito,
      estado: EstadoVenta.completada,
      creadaEn: DateTime.utc(2026, 6, 1),
      creditoLiquidado: true,
      creditoLiquidadoEn: DateTime.utc(2026, 6, 15),
      lineas: const [],
    );
    final texto = generarTextoLiquidacionCredito(
      venta: venta,
      nombreTienda: 'Tienda Centro',
      nombreCliente: 'Pedro',
    );
    expect(texto, contains('LIQUIDACION DE CREDITO'));
    expect(
      texto,
      anyOf(contains('CREDITO LIQUIDADO'), contains('CRÉDITO LIQUIDADO')),
    );
    expect(texto, contains('500'));
  });

  test('formatearLeyendaCompartirTicketDigital es breve y sin emojis', () {
    final contenido = construirTicketDigitalVenta(
      venta: Venta(
        id: 'venta-test-003',
        tiendaId: 'tienda-test',
        cajaId: 'caja-1',
        clienteId: null,
        total: 100.0,
        metodoPago: MetodoPago.efectivo,
        estado: EstadoVenta.completada,
        creadaEn: DateTime.utc(2026, 6, 11),
        lineas: const [],
      ),
      nombreTienda: 'Tienda Centro',
    );
    final leyenda = formatearLeyendaCompartirTicketDigital(contenido);
    expect(leyenda, contains('La Fortuna'));
    expect(leyenda, contains('TICKET DE VENTA'));
    expect(leyenda, contains('Folio ${contenido.folio}'));
    expect(leyenda, isNot(contains('🛒')));
    expect(leyenda, isNot(contains('Producto demo')));
  });
}
