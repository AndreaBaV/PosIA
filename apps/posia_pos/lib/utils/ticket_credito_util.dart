/// Utilidades para pagares y liquidacion de credito.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

/// Construye las dos copias del pagare (administrador y cliente).
Future<List<String>> construirTextosPagareCredito({
  required Venta venta,
  required ServicioAdmin servicioAdmin,
}) async {
  if (venta.clienteId == null) {
    throw StateError('La venta a crédito requiere cliente');
  }
  final cliente = await servicioAdmin.obtenerCliente(venta.clienteId!);
  if (cliente == null) {
    throw StateError('Cliente no encontrado');
  }
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  final nombreTienda = tienda?.nombre ?? 'Tienda';
  final direccionTienda = tienda?.direccion;
  final args = (
    nombreCliente: cliente.nombre,
    telefonoCliente: cliente.telefono,
    direccionCliente: cliente.direccion,
    rfcCliente: cliente.rfc,
  );
  return [
    generarTextoPagareCredito(
      venta: venta,
      nombreTienda: nombreTienda,
      nombreCliente: args.nombreCliente,
      telefonoCliente: args.telefonoCliente,
      direccionCliente: args.direccionCliente,
      etiquetaCopia: 'COPIA ADMINISTRADOR',
      direccionTienda: direccionTienda,
      rfcCliente: args.rfcCliente,
    ),
    generarTextoPagareCredito(
      venta: venta,
      nombreTienda: nombreTienda,
      nombreCliente: args.nombreCliente,
      telefonoCliente: args.telefonoCliente,
      direccionCliente: args.direccionCliente,
      etiquetaCopia: 'COPIA CLIENTE',
      direccionTienda: direccionTienda,
      rfcCliente: args.rfcCliente,
    ),
  ];
}

/// Comprobante al liquidar un credito pendiente.
Future<String> construirTextoLiquidacionCredito({
  required Venta venta,
  required ServicioAdmin servicioAdmin,
}) async {
  final tienda = await servicioAdmin.obtenerTiendaActiva();
  final cliente = venta.clienteId != null
      ? await servicioAdmin.obtenerCliente(venta.clienteId!)
      : null;
  return generarTextoLiquidacionCredito(
    venta: venta,
    nombreTienda: tienda?.nombre ?? 'Tienda',
    nombreCliente: cliente?.nombre ?? 'Cliente',
    direccionTienda: tienda?.direccion,
    telefonoCliente: cliente?.telefono,
  );
}
