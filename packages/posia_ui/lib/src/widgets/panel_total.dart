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
		this.nombreVendedor,
		this.turnoAbierto = true,
		super.key,
	});

	/// Nombre de la tienda activa.
	final String nombreTienda;

	/// Total actual del carrito.
	final double total;

	/// Vendedor asignado a la venta actual.
	final String? nombreVendedor;

	/// Indica si hay turno de caja abierto.
	final bool turnoAbierto;

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 14.0),
			decoration: BoxDecoration(
				gradient: LinearGradient(
					colors: [
						PosiaColors.cobrar,
						PosiaColors.cobrar.withValues(alpha: 0.85),
					],
					begin: Alignment.centerLeft,
					end: Alignment.centerRight,
				),
				boxShadow: [
					BoxShadow(
						color: PosiaColors.cobrar.withValues(alpha: 0.25),
						blurRadius: 8.0,
						offset: const Offset(0.0, 3.0),
					),
				],
			),
			child: Row(
				children: [
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Row(
									children: [
										const Icon(Icons.storefront_rounded, color: Colors.white, size: 22.0),
										const SizedBox(width: 8.0),
										Flexible(
											child: Text(
												nombreTienda,
												style: Theme.of(context).textTheme.titleLarge?.copyWith(
													color: Colors.white,
													fontWeight: FontWeight.w600,
												),
												overflow: TextOverflow.ellipsis,
											),
										),
									],
								),
								if (nombreVendedor != null) ...[
									const SizedBox(height: 4.0),
									Text(
										'Vendedor: $nombreVendedor',
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
											color: Colors.white.withValues(alpha: 0.9),
										),
									),
								],
								const SizedBox(height: 4.0),
								Row(
									children: [
										Icon(
											turnoAbierto ? Icons.lock_open_rounded : Icons.lock_rounded,
											size: 14.0,
											color: Colors.white.withValues(alpha: 0.85),
										),
										const SizedBox(width: 4.0),
										Text(
											turnoAbierto ? 'Turno abierto' : 'Sin turno',
											style: Theme.of(context).textTheme.bodySmall?.copyWith(
												color: Colors.white.withValues(alpha: 0.85),
											),
										),
									],
								),
							],
						),
					),
					Column(
						crossAxisAlignment: CrossAxisAlignment.end,
						children: [
							Text(
								'Total',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: Colors.white.withValues(alpha: 0.85),
									letterSpacing: 0.5,
								),
							),
							Text(
								formatearMoneda(total),
								style: Theme.of(context).textTheme.headlineLarge?.copyWith(
									color: Colors.white,
									fontWeight: FontWeight.bold,
								),
							),
						],
					),
				],
			),
		);
	}
}
