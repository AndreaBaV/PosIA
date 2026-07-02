/// Dialogo con existencias de un producto por tienda y almacen.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Muestra existencias del producto en la tienda actual y otras ubicaciones.
class DialogoExistenciasProducto extends StatelessWidget {
	const DialogoExistenciasProducto({
		required this.nombreProducto,
		required this.nombreTiendaActual,
		required this.cantidadTiendaActual,
		required this.existenciasPorTienda,
		required this.existenciasPorAlmacen,
		super.key,
	});

	final String nombreProducto;
	final String nombreTiendaActual;
	final double cantidadTiendaActual;
	final Map<String, double> existenciasPorTienda;
	final Map<String, double> existenciasPorAlmacen;

	/// Abre el dialogo de existencias.
	static Future<void> mostrar(
		BuildContext context, {
		required String nombreProducto,
		required String nombreTiendaActual,
		required double cantidadTiendaActual,
		required Map<String, double> existenciasPorTienda,
		required Map<String, double> existenciasPorAlmacen,
	}) {
		return showDialog<void>(
			context: context,
			builder: (ctx) => DialogoExistenciasProducto(
				nombreProducto: nombreProducto,
				nombreTiendaActual: nombreTiendaActual,
				cantidadTiendaActual: cantidadTiendaActual,
				existenciasPorTienda: existenciasPorTienda,
				existenciasPorAlmacen: existenciasPorAlmacen,
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final otrasTiendas = existenciasPorTienda.entries
			.where((e) => e.key != nombreTiendaActual)
			.toList()
		  ..sort((a, b) => a.key.compareTo(b.key));
		final almacenes = existenciasPorAlmacen.entries.toList()
		  ..sort((a, b) => a.key.compareTo(b.key));

		return AlertDialog(
			icon: const Icon(Icons.inventory_2_outlined, color: PosiaColors.neutro),
			title: Text('Existencias'),
			content: SizedBox(
				width: 420.0,
				child: SingleChildScrollView(
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								nombreProducto,
								style: Theme.of(context).textTheme.titleMedium?.copyWith(
									fontWeight: FontWeight.w600,
								),
							),
							const SizedBox(height: 16.0),
							_filaDestacada(
								context,
								etiqueta: 'En $nombreTiendaActual (actual)',
								cantidad: cantidadTiendaActual,
								destacada: true,
							),
							if (otrasTiendas.isNotEmpty) ...[
								const SizedBox(height: 16.0),
								Text(
									'Otras tiendas',
									style: Theme.of(context).textTheme.labelLarge?.copyWith(
										color: PosiaColors.neutro,
									),
								),
								const SizedBox(height: 8.0),
								for (final entrada in otrasTiendas)
									_filaDestacada(
										context,
										etiqueta: entrada.key,
										cantidad: entrada.value,
									),
							],
							if (almacenes.isNotEmpty) ...[
								const SizedBox(height: 16.0),
								Text(
									'Almacenes',
									style: Theme.of(context).textTheme.labelLarge?.copyWith(
										color: PosiaColors.neutro,
									),
								),
								const SizedBox(height: 8.0),
								for (final entrada in almacenes)
									_filaDestacada(
										context,
										etiqueta: entrada.key,
										cantidad: entrada.value,
										esAlmacen: true,
									),
							],
							if (otrasTiendas.isEmpty && almacenes.isEmpty)
								Padding(
									padding: const EdgeInsets.only(top: 8.0),
									child: Text(
										'Solo hay registro en la tienda actual.',
										style: TextStyle(color: Colors.grey.shade600),
									),
								),
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(context),
					child: const Text('Cerrar'),
				),
			],
		);
	}

	Widget _filaDestacada(
		BuildContext context, {
		required String etiqueta,
		required double cantidad,
		bool destacada = false,
		bool esAlmacen = false,
	}) {
		final sinStock = cantidad <= 0;
		final colorCantidad = sinStock
			? PosiaColors.sinExistencia
			: (destacada ? PosiaColors.cobrar : PosiaColors.neutro);
		return Container(
			margin: const EdgeInsets.only(bottom: 6.0),
			padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
			decoration: BoxDecoration(
				color: destacada
					? PosiaColors.cobrar.withValues(alpha: 0.08)
					: PosiaColors.fondo,
				borderRadius: BorderRadius.circular(10.0),
				border: destacada
					? Border.all(color: PosiaColors.cobrar.withValues(alpha: 0.35))
					: null,
			),
			child: Row(
				children: [
					Icon(
						esAlmacen ? Icons.warehouse_outlined : Icons.storefront_outlined,
						size: 18.0,
						color: Colors.grey.shade600,
					),
					const SizedBox(width: 8.0),
					Expanded(
						child: Text(
							etiqueta,
							style: Theme.of(context).textTheme.bodyMedium,
						),
					),
					Text(
						_formatearCantidad(cantidad),
						style: Theme.of(context).textTheme.titleSmall?.copyWith(
							color: colorCantidad,
							fontWeight: FontWeight.bold,
						),
					),
				],
			),
		);
	}

	String _formatearCantidad(double cantidad) {
		if (cantidad == cantidad.roundToDouble()) {
			return cantidad.toInt().toString();
		}
		return cantidad.toStringAsFixed(2);
	}
}
