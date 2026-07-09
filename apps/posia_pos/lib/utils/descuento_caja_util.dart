/// Utilidades para descuentos manuales en pantalla de caja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';
import '../widgets/dialogo_descuento_caja.dart';

/// Indica si el usuario en sesion puede aplicar descuentos en caja.
bool puedeDescuentoEnCaja(WidgetRef ref) {
	final usuario = ref.read(sesionUsuarioProvider);
	if (usuario == null) {
		return false;
	}
	return PoliticaAccesoAdmin.puedeAplicarDescuentoEnCaja(usuario);
}

/// Muestra dialogo para descontar una linea del carrito.
Future<void> mostrarDescuentoLineaCaja(
	BuildContext context,
	WidgetRef ref,
	int indice,
) async {
	if (!puedeDescuentoEnCaja(ref)) {
		return;
	}
	final estado = ref.read(carritoNotifierProvider).value;
	if (estado == null || indice < 0 || indice >= estado.lineas.length) {
		return;
	}
	final linea = estado.lineas[indice];
	if (calcularDescuentoMaximoLinea(linea) <= 0.0 &&
		linea.descuentoLinea <= 0.0) {
		if (context.mounted) {
			PosiaNotificaciones.mostrarSnackBar(
				context,
				SnackBar(
					content: Text(
						'No se puede descontar: precio mínimo '
						'${formatearMoneda(calcularPrecioMinimoUnitarioLinea(linea))}',
					),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
		return;
	}
	final resultado = await DialogoDescuentoCaja.mostrarLinea(
		context: context,
		linea: linea,
	);
	if (!context.mounted || !resultado.confirmado) {
		return;
	}
	final notifier = ref.read(carritoNotifierProvider.notifier);
	String? error;
	if (resultado.quitar) {
		error = await notifier.aplicarDescuentoLinea(indice, 0.0);
	} else if (resultado.esPorcentaje) {
		error = await notifier.aplicarDescuentoLineaPorcentaje(
			indice,
			resultado.valor,
		);
	} else {
		error = await notifier.aplicarDescuentoLinea(indice, resultado.valor);
	}
	if (error != null && context.mounted) {
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text(error), backgroundColor: PosiaColors.cancelar),
		);
	}
}

/// Muestra dialogo para descontar el ticket completo.
Future<void> mostrarDescuentoTicketCaja(
	BuildContext context,
	WidgetRef ref,
) async {
	if (!puedeDescuentoEnCaja(ref)) {
		return;
	}
	final estado = ref.read(carritoNotifierProvider).value;
	if (estado == null || estado.lineas.isEmpty) {
		return;
	}
	final maximo = calcularDescuentoMaximoTicket(estado.lineas);
	if (maximo <= 0.0 && estado.descuentoTicket <= 0.0) {
		if (context.mounted) {
			PosiaNotificaciones.mostrarSnackBar(
				context,
				const SnackBar(
					content: Text(
						'No se puede descontar más: el total ya está en el mínimo permitido',
					),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
		return;
	}
	final resultado = await DialogoDescuentoCaja.mostrarTicket(
		context: context,
		lineas: estado.lineas,
		descuentoActual: estado.descuentoTicket,
	);
	if (!context.mounted || !resultado.confirmado) {
		return;
	}
	final notifier = ref.read(carritoNotifierProvider.notifier);
	String? error;
	if (resultado.quitar) {
		error = await notifier.aplicarDescuentoTicket(0.0);
	} else if (resultado.esPorcentaje) {
		error = await notifier.aplicarDescuentoTicketPorcentaje(resultado.valor);
	} else {
		error = await notifier.aplicarDescuentoTicket(resultado.valor);
	}
	if (error != null && context.mounted) {
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text(error), backgroundColor: PosiaColors.cancelar),
		);
	}
}
