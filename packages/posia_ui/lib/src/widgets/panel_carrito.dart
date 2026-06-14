/// Panel lateral del carrito activo con iconos de linea.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_module_butcher/posia_module_butcher.dart';

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
		this.alTocarLinea,
		super.key,
	});

	/// Lineas del carrito activo.
	final List<LineaCarrito> lineas;

	/// Accion al eliminar linea por indice.
	final ValueChanged<int> alEliminarLinea;

	/// Accion al tocar linea (ej. descuento).
	final ValueChanged<int>? alTocarLinea;

	@override
	Widget build(BuildContext context) {
		return Container(
			color: PosiaColors.tarjeta,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Padding(
						padding: const EdgeInsets.all(12.0),
						child: Row(
							children: [
								const Icon(Icons.shopping_cart, size: 28.0),
								const SizedBox(width: 8.0),
								Text(
									'Carrito',
									style: Theme.of(context).textTheme.titleLarge,
								),
							],
						),
					),
					const Divider(height: 1.0),
					Expanded(
						child: lineas.isEmpty
							? Center(
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										const Icon(
											Icons.remove_shopping_cart,
											size: 64.0,
											color: Colors.grey,
										),
										const SizedBox(height: 12.0),
										Text(
											'Carrito vacio',
											style: Theme.of(context).textTheme.titleMedium?.copyWith(
												color: Colors.grey,
											),
										),
										const SizedBox(height: 4.0),
										const Text(
											'Toca un producto o escanea',
											style: TextStyle(color: Colors.grey),
										),
									],
								),
							)
							: ListView.builder(
								itemCount: lineas.length,
								itemBuilder: (context, indice) {
									final linea = lineas[indice];
									return ListTile(
										onTap: alTocarLinea != null
											? () => alTocarLinea!(indice)
											: null,
										leading: CircleAvatar(
											backgroundColor: PosiaColors.cobrar,
											child: Text(
												'${linea.cantidad.toStringAsFixed(linea.cantidad == linea.cantidad.roundToDouble() ? 0 : 1)}',
												style: const TextStyle(color: Colors.white),
											),
										),
										title: Text(linea.producto.nombre),
										subtitle: Text(_construirSubtituloLinea(linea)),
										trailing: IconButton(
											icon: const Icon(Icons.delete, color: PosiaColors.cancelar),
											onPressed: () => alEliminarLinea(indice),
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
	///
	/// [linea] Linea del carrito activo.
	/// Retorna texto descriptivo para cajero.
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
