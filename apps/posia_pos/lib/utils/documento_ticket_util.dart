/// Construccion de textos de documentos para compartir o imprimir.
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

/// Texto de compra a proveedor listo para WhatsApp o impresion.
Future<String> construirTextoCompra({
	required Compra compra,
	required String nombreProveedor,
	required ServicioAdmin servicio,
}) async {
	final nombreTienda = await _nombreTiendaPorId(servicio, compra.tiendaId);
	return generarTextoCompra(
		compra: compra,
		nombreProveedor: nombreProveedor,
		nombreTienda: nombreTienda,
	);
}

/// Texto de pedido listo para WhatsApp o impresion.
Future<String> construirTextoPedido({
	required Pedido pedido,
	required ServicioAdmin servicio,
}) async {
	final nombreTienda = await _nombreTiendaPorId(servicio, pedido.tiendaId);
	return generarTextoPedido(
		pedido: pedido,
		nombreTienda: nombreTienda,
	);
}
