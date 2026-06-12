/// Grilla de productos con iconos grandes para seleccion tactil.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';

/// Muestra catalogo como grid de tarjetas con icono e imagen fallback.
class GrillaProductos extends StatelessWidget {
	/// Crea grilla de productos activos.
	///
	/// [productos] Lista de productos a mostrar.
	/// [alSeleccionar] Callback al tocar un producto.
	const GrillaProductos({
		required this.productos,
		required this.alSeleccionar,
		super.key,
	});

	/// Productos disponibles en catalogo.
	final List<Producto> productos;

	/// Accion al seleccionar producto.
	final ValueChanged<Producto> alSeleccionar;

	@override
	Widget build(BuildContext context) {
		if (productos.isEmpty) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						const Icon(Icons.inventory_2_outlined, size: 64.0, color: Colors.grey),
						const SizedBox(height: 12.0),
						Text(
							'Sin productos en esta categoria',
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
								color: Colors.grey,
							),
						),
					],
				),
			);
		}
		return GridView.builder(
			padding: const EdgeInsets.all(12.0),
			gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
				crossAxisCount: 3,
				mainAxisSpacing: 12.0,
				crossAxisSpacing: 12.0,
				childAspectRatio: 0.85,
			),
			itemCount: productos.length,
			itemBuilder: (context, indice) {
				final producto = productos[indice];
				return _TarjetaProducto(
					producto: producto,
					alPresionar: () => alSeleccionar(producto),
				);
			},
		);
	}
}

/// Tarjeta individual de producto con icono fallback.
class _TarjetaProducto extends StatelessWidget {
	const _TarjetaProducto({
		required this.producto,
		required this.alPresionar,
	});

	final Producto producto;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: PosiaColors.tarjeta,
			borderRadius: BorderRadius.circular(16.0),
			elevation: 2.0,
			child: InkWell(
				onTap: alPresionar,
				borderRadius: BorderRadius.circular(16.0),
				child: Padding(
					padding: const EdgeInsets.all(8.0),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(
								_resolverIconoProducto(producto),
								size: 56.0,
								color: PosiaColors.cobrar,
							),
							const SizedBox(height: 8.0),
							Text(
								formatearMoneda(producto.precioBase),
								style: Theme.of(context).textTheme.titleLarge?.copyWith(
									color: PosiaColors.cobrar,
								),
							),
							if (producto.moduloVertical == ModuloVertical.carniceria)
								const Text('/ kg', style: TextStyle(color: Colors.grey)),
							const SizedBox(height: 4.0),
							Text(
								producto.nombre,
								textAlign: TextAlign.center,
								maxLines: 2,
								overflow: TextOverflow.ellipsis,
								style: Theme.of(context).textTheme.bodyLarge,
							),
						],
					),
				),
			),
		);
	}

	/// Resuelve icono Material segun tipo de producto demo.
	///
	/// [producto] Producto a representar visualmente.
	/// Retorna icono apropiado cuando no hay imagen asset cargada.
	IconData _resolverIconoProducto(Producto producto) {
		final nombre = producto.nombre.toLowerCase();
		if (nombre.contains('coca')) {
			return Icons.local_drink;
		}
		if (nombre.contains('arroz')) {
			return Icons.rice_bowl;
		}
		if (nombre.contains('leche')) {
			return Icons.water_drop;
		}
		if (nombre.contains('huevo')) {
			return Icons.egg;
		}
		if (nombre.contains('aceite')) {
			return Icons.opacity;
		}
		if (nombre.contains('azucar')) {
			return Icons.grain;
		}
		if (nombre.contains('frijol')) {
			return Icons.grass;
		}
		if (nombre.contains('atun')) {
			return Icons.set_meal;
		}
		if (producto.moduloVertical == ModuloVertical.carniceria) {
			return Icons.set_meal;
		}
		if (producto.moduloVertical == ModuloVertical.farmacia) {
			return Icons.medication;
		}
		return Icons.shopping_basket;
	}
}
