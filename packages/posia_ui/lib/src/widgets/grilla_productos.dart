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
		this.categoriaId,
		this.mensajeVacio = 'Sin productos en esta categoría',
		super.key,
	});

	/// Productos disponibles en catalogo.
	final List<Producto> productos;

	/// Categoria activa (para conservar scroll al cambiar filtro).
	final String? categoriaId;

	/// Mensaje cuando no hay productos visibles.
	final String mensajeVacio;

	/// Accion al seleccionar producto.
	final ValueChanged<Producto> alSeleccionar;

	@override
	Widget build(BuildContext context) {
		if (productos.isEmpty) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(Icons.inventory_2_outlined, size: 64.0, color: Colors.grey.shade400),
						const SizedBox(height: 12.0),
						Text(
							mensajeVacio,
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
								color: Colors.grey.shade600,
							),
							textAlign: TextAlign.center,
						),
					],
				),
			);
		}
		return GridView.builder(
			key: PageStorageKey<String>('grilla_${categoriaId ?? 'todos'}'),
			padding: const EdgeInsets.all(12.0),
			gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
				crossAxisCount: 3,
				mainAxisSpacing: 10.0,
				crossAxisSpacing: 10.0,
				childAspectRatio: 0.88,
			),
			itemCount: productos.length,
			itemBuilder: (context, indice) {
				final producto = productos[indice];
				return _TarjetaProducto(
					key: ValueKey(producto.id),
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
		super.key,
	});

	final Producto producto;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: PosiaColors.tarjeta,
			borderRadius: BorderRadius.circular(14.0),
			elevation: 1.0,
			shadowColor: Colors.black.withValues(alpha: 0.08),
			child: InkWell(
				onTap: alPresionar,
				borderRadius: BorderRadius.circular(14.0),
				child: Padding(
					padding: const EdgeInsets.all(10.0),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Container(
								padding: const EdgeInsets.all(10.0),
								decoration: BoxDecoration(
									color: PosiaColors.cobrar.withValues(alpha: 0.1),
									borderRadius: BorderRadius.circular(12.0),
								),
								child: Icon(
									_resolverIconoProducto(producto),
									size: 40.0,
									color: PosiaColors.cobrar,
								),
							),
							const SizedBox(height: 8.0),
							Text(
								formatearMoneda(producto.precioBase),
								style: Theme.of(context).textTheme.titleMedium?.copyWith(
									color: PosiaColors.cobrar,
									fontWeight: FontWeight.bold,
								),
							),
							if (producto.moduloVertical == ModuloVertical.carniceria)
								Text('/ kg', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.0)),
							const SizedBox(height: 4.0),
							Text(
								producto.nombre,
								textAlign: TextAlign.center,
								maxLines: 2,
								overflow: TextOverflow.ellipsis,
								style: Theme.of(context).textTheme.bodyMedium?.copyWith(
									fontWeight: FontWeight.w500,
								),
							),
						],
					),
				),
			),
		);
	}

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
