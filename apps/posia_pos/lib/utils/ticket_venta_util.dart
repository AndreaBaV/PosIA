/// Utilidades para construir tickets de venta enriquecidos.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

/// Resuelve datos de tienda, caja, vendedor y cliente para el ticket.
Future<String> construirTextoTicketVenta({
  required Venta venta,
  required ServicioAdmin servicioAdmin,
  ConfigDispositivo? config,
  double? montoRecibido,
}) async {
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  final cliente = venta.clienteId != null
      ? await servicioAdmin.obtenerCliente(venta.clienteId!)
      : null;
  final vendedor = venta.vendedorId != null
      ? await servicioAdmin.obtenerVendedor(venta.vendedorId!)
      : null;
  return generarTextoTicket(
    venta: venta,
    nombreTienda: tienda?.nombre ?? 'Tienda',
    direccionTienda: tienda?.direccion,
    nombreVendedor: vendedor?.nombre,
    codigoVendedor: vendedor?.codigo,
    nombreCliente: cliente?.nombre,
    telefonoCliente: cliente?.telefono,
    rfcCliente: cliente?.rfc,
    direccionCliente: cliente?.direccion,
    montoRecibido: montoRecibido,
    conLogoImpreso: true,
  );
}

/// Ticket digital de venta para WhatsApp (imagen con logo).
Future<TicketDigitalContenido> obtenerTicketDigitalVenta({
  required Venta venta,
  required ServicioAdmin servicioAdmin,
  ConfigDispositivo? config,
  double? montoRecibido,
}) async {
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  final cliente = venta.clienteId != null
      ? await servicioAdmin.obtenerCliente(venta.clienteId!)
      : null;
  final vendedor = venta.vendedorId != null
      ? await servicioAdmin.obtenerVendedor(venta.vendedorId!)
      : null;
  return construirTicketDigitalVenta(
    venta: venta,
    nombreTienda: tienda?.nombre ?? 'Tienda',
    direccionTienda: tienda?.direccion,
    nombreVendedor: vendedor?.nombre,
    codigoVendedor: vendedor?.codigo,
    nombreCliente: cliente?.nombre,
    telefonoCliente: cliente?.telefono,
    rfcCliente: cliente?.rfc,
    direccionCliente: cliente?.direccion,
    montoRecibido: montoRecibido,
  );
}

List<LineaVenta> _lineasCotizacionComoVenta(List<LineaCotizacion> lineas) {
  return lineas
      .map(
        (linea) => LineaVenta(
          productoId: linea.productoId,
          nombreProducto: linea.nombreProducto,
          cantidad: linea.cantidad,
          precioUnitario: linea.precioUnitario,
          reglaPrecio: linea.reglaPrecio,
        ),
      )
      .toList();
}

/// Texto imprimible de una cotizacion ya guardada.
String construirTextoCotizacionGuardada({
  required Cotizacion cotizacion,
  required String nombreTienda,
  String? direccionTienda,
}) {
  return generarTextoCotizacion(
    id: cotizacion.id,
    nombreTienda: nombreTienda,
    lineas: _lineasCotizacionComoVenta(cotizacion.lineas),
    total: cotizacion.total,
    creadaEn: cotizacion.creadaEn,
    nombreCotizacion: cotizacion.nombre.isEmpty ? null : cotizacion.nombre,
    nombreCliente: cotizacion.nombreCliente,
    notas: cotizacion.notas.isEmpty ? null : cotizacion.notas,
    direccionTienda: direccionTienda,
    vigenciaDias: cotizacion.vigenciaDias,
    conLogoImpreso: true,
  );
}

/// Persiste cotizacion desde carrito con texto e imagen digital.
Future<({Cotizacion cotizacion, String texto, TicketDigitalContenido digital})>
registrarCotizacionDesdeCarrito({
  required ServicioCaja servicioCaja,
  required ServicioAdmin servicioAdmin,
  String nombre = '',
  String? notas,
}) async {
  final cotizacion = await servicioCaja.registrarCotizacionCarrito(
    nombre: nombre,
    notas: notas,
  );
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  final nombreTienda = tienda?.nombre ?? 'Tienda';
  final digital = construirTicketDigitalDesdeCotizacion(
    cotizacion: cotizacion,
    nombreTienda: nombreTienda,
    direccionTienda: tienda?.direccion,
  );
  final texto = construirTextoCotizacionGuardada(
    cotizacion: cotizacion,
    nombreTienda: nombreTienda,
    direccionTienda: tienda?.direccion,
  );
  return (cotizacion: cotizacion, texto: texto, digital: digital);
}

/// Ticket digital de cotización por id.
Future<TicketDigitalContenido> obtenerTicketDigitalCotizacionPorId({
  required String cotizacionId,
  required ServicioAdmin servicioAdmin,
}) async {
  final cotizacion = await servicioAdmin.obtenerCotizacion(cotizacionId);
  if (cotizacion == null) {
    throw StateError('Cotización no encontrada');
  }
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  return construirTicketDigitalDesdeCotizacion(
    cotizacion: cotizacion,
    nombreTienda: tienda?.nombre ?? 'Tienda',
    direccionTienda: tienda?.direccion,
  );
}

/// Texto imprimible de cotizacion guardada por id.
Future<String> construirTextoCotizacionPorId({
  required String cotizacionId,
  required ServicioAdmin servicioAdmin,
}) async {
  final cotizacion = await servicioAdmin.obtenerCotizacion(cotizacionId);
  if (cotizacion == null) {
    throw StateError('Cotización no encontrada');
  }
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  return construirTextoCotizacionGuardada(
    cotizacion: cotizacion,
    nombreTienda: tienda?.nombre ?? 'Tienda',
    direccionTienda: tienda?.direccion,
  );
}
