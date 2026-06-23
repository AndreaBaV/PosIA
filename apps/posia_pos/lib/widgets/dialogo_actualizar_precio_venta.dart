/// Dialogo para actualizar precio de venta con calculo de utilidad.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

/// Muestra dialogo para ajustar precio de venta de un producto.
Future<bool> mostrarDialogoActualizarPrecioVenta({
	required BuildContext context,
	required Producto producto,
	required Future<ServicioAdmin> Function() obtenerServicio,
}) async {
	final precioController = TextEditingController(
		text: producto.precioBase.toStringAsFixed(2),
	);
	final guardado = await showDialog<bool>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: Text('Actualizar precio · ${producto.nombre}'),
			content: SizedBox(
				width: 420.0,
				child: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text('Costo actual: ${formatearMoneda(producto.costoUnitario)}'),
							Text('Precio actual: ${formatearMoneda(producto.precioBase)}'),
							const SizedBox(height: 12.0),
							TextField(
								controller: precioController,
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								decoration: const InputDecoration(
									labelText: 'Nuevo precio de venta (MXN)',
									border: OutlineInputBorder(),
									prefixText: '\$ ',
								),
								autofocus: true,
							),
							const SizedBox(height: 12.0),
							PanelCalculoUtilidad(
								costoUnitario: producto.costoUnitario,
								precioController: precioController,
							),
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(ctx, false),
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: () async {
						final precio = double.tryParse(
							precioController.text.replaceAll(',', '.'),
						);
						if (precio == null || precio <= 0) {
							ScaffoldMessenger.of(ctx).showSnackBar(
								const SnackBar(
									content: Text('Ingrese un precio valido'),
									backgroundColor: PosiaColors.cancelar,
								),
							);
							return;
						}
						if (!precioVentaEsValido(precio, producto.costoUnitario)) {
							ScaffoldMessenger.of(ctx).showSnackBar(
								SnackBar(
									content: Text(
										mensajePrecioMinimoInvalido(producto.costoUnitario),
									),
									backgroundColor: PosiaColors.cancelar,
								),
							);
							return;
						}
						try {
							final servicio = await obtenerServicio();
							await servicio.actualizarProducto(
								producto.copiarCon(precioBase: precio),
							);
							if (ctx.mounted) {
								Navigator.pop(ctx, true);
							}
						} catch (error) {
							if (ctx.mounted) {
								ScaffoldMessenger.of(ctx).showSnackBar(
									SnackBar(
										content: Text('$error'),
										backgroundColor: PosiaColors.cancelar,
									),
								);
							}
						}
					},
					child: const Text('Guardar'),
				),
			],
		),
	);
	precioController.dispose();
	return guardado ?? false;
}

/// Ofrece actualizar precios tras una compra que cambio costos.
Future<void> mostrarDialogoPreciosPostCompra({
	required BuildContext context,
	required List<({Producto producto, double nuevoCosto})> lineas,
	required Future<ServicioAdmin> Function() obtenerServicio,
}) async {
	if (lineas.isEmpty) {
		return;
	}
	final precioControllers = {
		for (final linea in lineas)
			linea.producto.id: TextEditingController(
				text: linea.producto.precioBase.toStringAsFixed(2),
			),
	};
	final guardado = await showDialog<bool>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text('Actualizar precios de venta'),
			content: SizedBox(
				width: 480.0,
				child: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							const Text(
								'Los costos cambiaron con esta compra. '
								'Revise y ajuste los precios de venta si lo necesita.',
							),
							const SizedBox(height: 12.0),
							...lineas.map((linea) {
								final ctrl = precioControllers[linea.producto.id]!;
								return Padding(
									padding: const EdgeInsets.only(bottom: 12.0),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											Text(
												linea.producto.nombre,
												style: const TextStyle(fontWeight: FontWeight.bold),
											),
											Text(
												'Costo: ${formatearMoneda(linea.nuevoCosto)} · '
												'Precio actual: ${formatearMoneda(linea.producto.precioBase)}',
											),
											const SizedBox(height: 8.0),
											TextField(
												controller: ctrl,
												keyboardType: const TextInputType.numberWithOptions(
													decimal: true,
												),
												decoration: const InputDecoration(
													labelText: 'Precio de venta (MXN)',
													border: OutlineInputBorder(),
													prefixText: '\$ ',
													isDense: true,
												),
											),
											const SizedBox(height: 8.0),
											PanelCalculoUtilidad(
												costoUnitario: linea.nuevoCosto,
												precioController: ctrl,
											),
										],
									),
								);
							}),
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(ctx, false),
					child: const Text('Omitir'),
				),
				FilledButton(
					onPressed: () async {
						try {
							final servicio = await obtenerServicio();
							for (final linea in lineas) {
								final ctrl = precioControllers[linea.producto.id]!;
								final precio = double.tryParse(
									ctrl.text.replaceAll(',', '.'),
								);
								if (precio == null || precio <= 0) {
									throw StateError(
										'Precio invalido para ${linea.producto.nombre}',
									);
								}
								if (!precioVentaEsValido(precio, linea.nuevoCosto)) {
									throw StateError(
										'${linea.producto.nombre}: '
										'${mensajePrecioMinimoInvalido(linea.nuevoCosto)}',
									);
								}
								if ((precio - linea.producto.precioBase).abs() < 0.001) {
									continue;
								}
								await servicio.actualizarProducto(
									linea.producto.copiarCon(
										precioBase: precio,
										costoUnitario: linea.nuevoCosto,
									),
								);
							}
							if (ctx.mounted) {
								Navigator.pop(ctx, true);
							}
						} catch (error) {
							if (ctx.mounted) {
								ScaffoldMessenger.of(ctx).showSnackBar(
									SnackBar(
										content: Text('$error'),
										backgroundColor: PosiaColors.cancelar,
									),
								);
							}
						}
					},
					child: const Text('Guardar precios'),
				),
			],
		),
	);
	for (final ctrl in precioControllers.values) {
		ctrl.dispose();
	}
	if (guardado == true && context.mounted) {
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Precios de venta actualizados')),
		);
	}
}
