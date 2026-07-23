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
		this.descuentoTicket = 0.0,
		this.alDobleClicLinea,
		this.alDobleClicPrecio,
		super.key,
	});

	/// Lineas del carrito activo.
	final List<LineaCarrito> lineas;

	/// Total actual del carrito.
	final double total;

	/// Descuento global aplicado al ticket.
	final double descuentoTicket;

	/// Accion al eliminar linea por indice.
	final ValueChanged<int> alEliminarLinea;

	/// Accion al hacer doble clic en linea (editar cantidad/precio).
	final ValueChanged<int>? alDobleClicLinea;

	/// Accion al hacer doble clic en el PRECIO de la linea: fija el precio final
	/// manual (sobreprecio o descuento) sin recalcular el peso/cantidad.
	final ValueChanged<int>? alDobleClicPrecio;

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
									Column(
										crossAxisAlignment: CrossAxisAlignment.end,
										children: [
											if (descuentoTicket > 0.0)
												Text(
													'-${formatearMoneda(descuentoTicket)}',
													style: Theme.of(context).textTheme.bodySmall?.copyWith(
														color: PosiaColors.cancelar,
													),
												),
											Text(
												formatearMoneda(total),
												style: Theme.of(context).textTheme.titleMedium?.copyWith(
													color: PosiaColors.cobrar,
													fontWeight: FontWeight.bold,
												),
											),
										],
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
										child: Padding(
											padding: const EdgeInsets.symmetric(
												horizontal: 6.0,
												vertical: 4.0,
											),
											child: Row(
												crossAxisAlignment: CrossAxisAlignment.center,
												children: [
													Expanded(
														child: GestureDetector(
															onDoubleTap: alDobleClicLinea != null
																? () => alDobleClicLinea!(indice)
																: null,
															child: Padding(
																padding: const EdgeInsets.symmetric(
																	horizontal: 6.0,
																	vertical: 8.0,
																),
																child: Row(
																	children: [
																		Tooltip(
																			message: 'Doble clic para editar',
																			child: SizedBox(
																				width: 52.0,
																				child: Text(
																					_formatearCantidad(linea.cantidad),
																					textAlign: TextAlign.center,
																					style: const TextStyle(
																						color: PosiaColors.cobrar,
																						fontSize: 15.0,
																						fontWeight: FontWeight.bold,
																					),
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
																		GestureDetector(
																			onDoubleTap: alDobleClicPrecio != null
																				? () => alDobleClicPrecio!(indice)
																				: null,
																			child: Text(
																				formatearMoneda(subtotal),
																				style: TextStyle(
																					fontWeight: FontWeight.bold,
																					color: linea.reglaPrecio == ReglaPrecio.precioManual
																						? Colors.orange.shade900
																						: PosiaColors.cobrar,
																					),
																				),
																			),
																	],
																),
															),
														),
													),
													Material(
														color: Colors.transparent,
														child: IconButton(
															icon: const Icon(Icons.close, size: 20.0),
															color: PosiaColors.cancelar,
															style: IconButton.styleFrom(
																minimumSize: const Size(44.0, 44.0),
																tapTargetSize: MaterialTapTargetSize.shrinkWrap,
															),
															tooltip: 'Quitar',
															onPressed: () => alEliminarLinea(indice),
														),
													),
												],
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
	String _formatearCantidad(double cantidad) {
		if (cantidad == cantidad.roundToDouble()) {
			return cantidad.toStringAsFixed(0);
		}
		// Hasta 3 decimales, sin ceros de mas: 0.275 se muestra "0.275", no
		// redondeado a "0.3" como hacia el circulo verde anterior (1 decimal).
		return cantidad
			.toStringAsFixed(3)
			.replaceAll(RegExp(r'0+$'), '')
			.replaceAll(RegExp(r'\.$'), '');
	}

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
