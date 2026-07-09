/// Destinos del panel admin abribles por atajos de teclado.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../providers/admin_providers.dart';
import '../screens/pantalla_configuracion_admin.dart';
import '../screens/pantalla_corte_caja.dart';
import '../screens/pantalla_creditos_pendientes.dart';
import '../screens/pantalla_cotizaciones_admin.dart';
import '../screens/pantalla_historial_ventas.dart';
import '../screens/pantalla_pedidos_admin.dart';
import '../screens/pantalla_reportes_admin.dart';
import '../screens/pantalla_ventas_dia.dart';

/// Construye pantalla admin por clave de tile si el usuario tiene permiso.
Widget? construirDestinoAdmin(
	String clave,
	Usuario usuario, {
	RolPersonalizado? rolPersonalizado,
}) {
	if (!tileAdminVisible(
		usuario,
		clave,
		rolPersonalizado: rolPersonalizado,
	)) {
		return null;
	}
	return switch (clave) {
		'ventas' => const PantallaVentasDia(),
		'pedidos' => const PantallaPedidosAdmin(),
		'historial' => const PantallaHistorialVentas(),
		'creditos' => const PantallaCreditosPendientes(),
		'cotizaciones' => const PantallaCotizacionesAdmin(),
		'corte' => const PantallaCorteCaja(),
		'reportes' => const PantallaReportesAdmin(),
		'config' => const PantallaConfiguracionAdmin(),
		_ => null,
	};
}
