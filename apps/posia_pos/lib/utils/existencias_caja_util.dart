/// Utilidades de caja para consultar existencias de productos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';

/// Muestra existencias del producto en tiendas y almacenes.
Future<void> mostrarExistenciasProductoEnCaja(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	final contenedor = await ref.read(contenedorServiciosProvider.future);
	final existencias = await contenedor.servicioAdmin.obtenerExistenciasProducto(
		producto.id,
	);
	if (!context.mounted || existencias == null) {
		return;
	}
	final tienda = await contenedor.servicioAdmin.obtenerTiendaActiva();
	if (!context.mounted) {
		return;
	}
	await DialogoExistenciasProducto.mostrar(
		context,
		nombreProducto: producto.nombre,
		nombreTiendaActual: tienda?.nombre ?? 'Tienda',
		cantidadTiendaActual: existencias.cantidadLocal,
		existenciasPorTienda: existencias.existenciasPorTienda,
		existenciasPorAlmacen: existencias.existenciasPorAlmacen,
	);
}
