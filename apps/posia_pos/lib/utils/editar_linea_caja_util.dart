/// Utilidades para editar lineas del carrito en caja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';
import '../widgets/dialogo_editar_linea_carrito.dart';
import 'descuento_caja_util.dart';

/// Indica si el usuario puede editar precios en caja.
bool puedeEditarPrecioEnCaja(WidgetRef ref) {
	final usuario = ref.read(sesionUsuarioProvider);
	if (usuario == null) {
		return false;
	}
	return PoliticaAccesoAdmin.puedeEditarPrecioEnCaja(usuario);
}

/// Muestra dialogo de edicion al hacer doble clic en una linea.
Future<void> mostrarEditarLineaCaja(
	BuildContext context,
	WidgetRef ref,
	int indice,
) async {
	final estado = ref.read(carritoNotifierProvider).value;
	if (estado == null || indice < 0 || indice >= estado.lineas.length) {
		return;
	}
	final linea = estado.lineas[indice];
	final resultado = await DialogoEditarLineaCarrito.mostrar(
		context: context,
		linea: linea,
		puedeEditarPrecio: puedeEditarPrecioEnCaja(ref),
		puedeDescuentoLinea: puedeDescuentoEnCaja(ref),
	);
	if (!context.mounted || !resultado.confirmado) {
		return;
	}

	final notifier = ref.read(carritoNotifierProvider.notifier);
	String? error;

	if (resultado.cantidad != null &&
		(resultado.cantidad! - linea.cantidad).abs() > 0.0001) {
		error = await notifier.actualizarCantidadLinea(indice, resultado.cantidad!);
		if (error != null) {
			if (context.mounted) {
				PosiaNotificaciones.mostrarSnackBar(
					context,
					SnackBar(content: Text(error), backgroundColor: PosiaColors.cancelar),
				);
			}
			return;
		}
	}

	if (resultado.precioUnitario != null &&
		puedeEditarPrecioEnCaja(ref) &&
		(redondearMonto(resultado.precioUnitario!) -
				redondearMonto(linea.precioUnitario))
			.abs() >
			0.001) {
		error = await notifier.actualizarPrecioLinea(
			indice,
			resultado.precioUnitario!,
		);
		if (error != null) {
			if (context.mounted) {
				PosiaNotificaciones.mostrarSnackBar(
					context,
					SnackBar(content: Text(error), backgroundColor: PosiaColors.cancelar),
				);
			}
			return;
		}
	}

	if (puedeDescuentoEnCaja(ref)) {
		if (resultado.quitarDescuentoLinea) {
			error = await notifier.aplicarDescuentoLinea(indice, 0.0);
		} else if (resultado.descuentoLinea != null &&
			(redondearMonto(resultado.descuentoLinea!) -
					redondearMonto(linea.descuentoLinea))
				.abs() >
				0.001) {
			error = await notifier.aplicarDescuentoLinea(
				indice,
				resultado.descuentoLinea!,
			);
		}
		if (error != null && context.mounted) {
			PosiaNotificaciones.mostrarSnackBar(
				context,
				SnackBar(content: Text(error), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}
