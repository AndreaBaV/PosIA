/// Panel superior con total de venta en tipografia grande.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Muestra nombre de tienda y total actual del carrito.
class PanelTotal extends StatelessWidget {
	/// Crea panel de total visible permanentemente.
	///
	/// [nombreTienda] Nombre de sucursal activa.
	/// [total] Monto total del carrito en MXN.
	const PanelTotal({
		required this.nombreTienda,
		required this.total,
		super.key,
	});

	/// Nombre de la tienda activa.
	final String nombreTienda;

	/// Total actual del carrito.
	final double total;

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
			color: PosiaColors.tarjeta,
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceBetween,
				children: [
					Row(
						children: [
							const Icon(Icons.store, size: 28.0, color: PosiaColors.neutro),
							const SizedBox(width: 8.0),
							Text(
								nombreTienda,
								style: Theme.of(context).textTheme.titleLarge,
							),
						],
					),
					Text(
						formatearMoneda(total),
						style: Theme.of(context).textTheme.headlineLarge?.copyWith(
							color: PosiaColors.cobrar,
						),
					),
				],
			),
		);
	}
}
