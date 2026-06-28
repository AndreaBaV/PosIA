/// Panel lateral del carrito activo con iconos de linea.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Lista lineas del carrito con boton de eliminar por icono.
class PanelCarrito extends StatelessWidget {
	/// Crea panel de carrito lateral.
	///
	/// [lineas] Lineas actuales del carrito.
	/// [alEliminarLinea] Callback con indice de linea a quitar.
	const PanelCarrito({
		required this.lineas,
		required this.alEliminarLinea,
		this.total = 0.0,
		this.alTocarLinea,
		super.key,
	});

	/// Lineas del carrito activo.
	final List<LineaCarrito> lineas;

	/// Total actual del carrito.
	final double total;

	/// Accion al eliminar linea por indice.
	final ValueChanged<int> alEliminarLinea;

	/// Accion al tocar linea (ej. descuento).
	final ValueChanged<int>? alTocarLinea;

	@override
	Widget build(BuildContext context) {
		return ColoredBox(
			color: PosiaColors.fondo,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
						color: PosiaColors.tarjeta,
						child: Row(
							children: [
								Container(
									padding: const EdgeInsets.all(8.0),
									decoration: BoxDecoration(
										color: PosiaColors.cobrar.withValues(alpha: 0.12),
										borderRadius: BorderRadius.circular(10.0),
									),
									child: const Icon(Icons.shopping_cart_outlined, color: PosiaColors.cobrar),
								),
								const SizedBox(width: 10.0),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												'${lineas.length}',
												style: Theme.of(context).textTheme.titleMedium?.copyWith(
													fontWeight: FontWeight.bold,
												),
											),
										],
									),
								),
								if (lineas.isNotEmpty)
									Text(
										formatearMoneda(total),
										style: Theme.of(context).textTheme.titleMedium?.copyWith(
											color: PosiaColors.cobrar,
											fontWeight: FontWeight.bold,
										),
									),
							],
						),
					),
					const Divider(height: 1.0),
					Expanded(
						child: lineas.isEmpty
							? LayoutBuilder(
								builder: (context, constraints) {
									final compacto = constraints.maxHeight < 130;
									return Center(
										child: FittedBox(
											fit: BoxFit.scaleDown,
											child: Padding(
												padding: EdgeInsets.symmetric(
													horizontal: 12.0,
													vertical: compacto ? 4.0 : 8.0,
												),
												child: Column(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(
															Icons.remove_shopping_cart_outlined,
															size: compacto ? 28.0 : 40.0,
															color: Colors.grey.shade400,
														),
														SizedBox(height: compacto ? 4.0 : 8.0),
														Text(
															'Vacío',
															style: (compacto
																	? Theme.of(context).textTheme.bodyMedium
																	: Theme.of(context).textTheme.titleSmall)
																?.copyWith(
																	color: Colors.grey.shade600,
																	fontWeight: FontWeight.w600,
																),
														),
													],
												),
											),
										),
									);
								},
							)
							: ListView.separated(
								padding: const EdgeInsets.all(8.0),
								itemCount: lineas.length,
								separatorBuilder: (_, _) => const SizedBox(height: 6.0),
								itemBuilder: (context, indice) {
									final linea = lineas[indice];
									final subtotal = linea.calcularSubtotal();
									return Material(
										color: PosiaColors.tarjeta,
										borderRadius: BorderRadius.circular(12.0),
										elevation: 0.5,
										child: InkWell(
											borderRadius: BorderRadius.circular(12.0),
											onTap: alTocarLinea != null
												? () => alTocarLinea!(indice)
												: null,
											child: Padding(
												padding: const EdgeInsets.symmetric(
													horizontal: 10.0,
													vertical: 8.0,
												),
												child: Row(
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														CircleAvatar(
															backgroundColor: PosiaColors.cobrar,
															radius: 18.0,
															child: Text(
																linea.cantidad.toStringAsFixed(
																	linea.cantidad ==
																			linea.cantidad.roundToDouble()
																		? 0
																		: 1,
																),
																style: const TextStyle(
																	color: Colors.white,
																	fontSize: 12.0,
																	fontWeight: FontWeight.bold,
																),
															),
														),
														const SizedBox(width: 10.0),
														Expanded(
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																mainAxisSize: MainAxisSize.min,
																children: [
																	Text(
																		linea.producto.nombre,
																		maxLines: 2,
																		overflow: TextOverflow.ellipsis,
																		style: const TextStyle(
																			fontWeight: FontWeight.w600,
																		),
																	),
																	const SizedBox(height: 2.0),
																	Text(
																		_construirSubtituloLinea(linea),
																		maxLines: 1,
																		overflow: TextOverflow.ellipsis,
																		style: TextStyle(
																			fontSize: 12.0,
																			color: Colors.grey.shade600,
																		),
																	),
																],
															),
														),
														const SizedBox(width: 6.0),
														Text(
															formatearMoneda(subtotal),
															style: const TextStyle(
																fontWeight: FontWeight.bold,
																color: PosiaColors.cobrar,
															),
														),
														IconButton(
															icon: const Icon(Icons.close, size: 18.0),
															color: PosiaColors.cancelar,
															padding: const EdgeInsets.all(4.0),
															constraints: const BoxConstraints(
																minWidth: 32.0,
																minHeight: 32.0,
															),
															tooltip: 'Quitar',
															onPressed: () => alEliminarLinea(indice),
														),
													],
												),
											),
										),
									);
								},
							),
					),
				],
			),
		);
	}

	/// Construye subtitulo de linea con peso, lote o precio unitario.
	String _construirSubtituloLinea(LineaCarrito linea) {
		if (linea.etiquetaLote != null && linea.producto.moduloVertical == ModuloVertical.farmacia) {
			return '${linea.etiquetaLote} · ${formatearMoneda(linea.precioUnitario)}';
		}
		if (linea.producto.moduloVertical == ModuloVertical.carniceria) {
			return '${formatearPesoKg(linea.cantidad)} · ${formatearMoneda(linea.precioUnitario)}/kg';
		}
		if (linea.descuentoLinea > 0.0) {
			return '${formatearMoneda(linea.precioUnitario)} · desc ${formatearMoneda(linea.descuentoLinea)}';
		}
		return formatearMoneda(linea.precioUnitario);
	}
}
