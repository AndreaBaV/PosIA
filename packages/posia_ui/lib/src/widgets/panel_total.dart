/// Panel superior con total de venta en tipografia grande.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-07-23 (compactado para mostrar mas carrito)
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
		// Tienda, vendedor y turno se condensan en una sola línea de apoyo para
		// ganar alto y que se vean más productos del carrito.
		final subtitulo = [
			if (nombreVendedor != null && nombreVendedor!.trim().isNotEmpty)
				nombreVendedor!,
			turnoAbierto ? 'Turno abierto' : 'Sin turno',
		].join(' · ');
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
			decoration: BoxDecoration(
				gradient: LinearGradient(
					colors: [
						PosiaColors.cobrar,
						PosiaColors.cobrar.withValues(alpha: 0.85),
					],
					begin: Alignment.centerLeft,
					end: Alignment.centerRight,
				),
			),
			child: Row(
				children: [
					const Icon(Icons.storefront_rounded, color: Colors.white, size: 20.0),
					const SizedBox(width: 8.0),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(
									nombreTienda,
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: Theme.of(context).textTheme.titleMedium?.copyWith(
										color: Colors.white,
										fontWeight: FontWeight.w600,
									),
								),
								Text(
									subtitulo,
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: Theme.of(context).textTheme.bodySmall?.copyWith(
										color: Colors.white.withValues(alpha: 0.85),
									),
								),
							],
						),
					),
					const SizedBox(width: 12.0),
					Text(
						'Total',
						style: Theme.of(context).textTheme.bodySmall?.copyWith(
							color: Colors.white.withValues(alpha: 0.85),
						),
					),
					const SizedBox(width: 6.0),
					Text(
						formatearMoneda(total),
						style: Theme.of(context).textTheme.headlineSmall?.copyWith(
							color: Colors.white,
							fontWeight: FontWeight.bold,
						),
					),
				],
			),
		);
	}
}
