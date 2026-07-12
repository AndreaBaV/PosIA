/// Construccion de tickets digitales para compartir o imprimir.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

Future<String?> _nombreTiendaPorId(ServicioAdmin servicio, String tiendaId) async {
	final tiendas = await servicio.obtenerTiendasPermitidas();
	for (final tienda in tiendas) {
		if (tienda.id == tiendaId) {
			return tienda.nombre;
		}
	}
	return null;
}

Future<String?> _direccionTiendaPorId(ServicioAdmin servicio, String tiendaId) async {
	final tiendas = await servicio.obtenerTiendasPermitidas();
	for (final tienda in tiendas) {
		if (tienda.id == tiendaId) {
			return tienda.direccion;
		}
	}
	return null;
}

/// Ticket digital de compra a proveedor.
Future<TicketDigitalContenido> obtenerTicketDigitalCompra({
	required Compra compra,
	required String nombreProveedor,
	required ServicioAdmin servicio,
}) async {
	final tiendaId = compra.tiendaId ??
		compra.asignaciones
			.where((a) => a.esTienda)
			.map((a) => a.destinoId)
			.cast<String?>()
			.firstOrNull;
	final nombreTienda = tiendaId == null
		? 'Empresa'
		: await _nombreTiendaPorId(servicio, tiendaId);
	final direccionTienda = tiendaId == null
		? null
		: await _direccionTiendaPorId(servicio, tiendaId);
	return construirTicketDigitalCompra(
		compra: compra,
		nombreProveedor: nombreProveedor,
		nombreTienda: nombreTienda ?? 'Empresa',
		direccionTienda: direccionTienda,
	);
}

/// Ticket digital de pedido listo para WhatsApp o impresion.
Future<TicketDigitalContenido> obtenerTicketDigitalPedido({
	required Pedido pedido,
	required ServicioAdmin servicio,
}) async {
	final nombreTienda = await _nombreTiendaPorId(servicio, pedido.tiendaId);
	final direccionTienda = await _direccionTiendaPorId(servicio, pedido.tiendaId);
	return construirTicketDigitalPedido(
		pedido: pedido,
		nombreTienda: nombreTienda ?? 'Tienda',
		direccionTienda: direccionTienda,
	);
}
