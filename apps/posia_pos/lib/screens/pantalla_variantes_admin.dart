/// Administracion de presentaciones (variantes) de un producto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaVariantesAdmin extends ConsumerStatefulWidget {
	const PantallaVariantesAdmin({required this.producto, super.key});

	final Producto producto;

	@override
	ConsumerState<PantallaVariantesAdmin> createState() =>
		_PantallaVariantesAdminState();
}

class _PantallaVariantesAdminState extends ConsumerState<PantallaVariantesAdmin> {
	@override
	Widget build(BuildContext context) {
		final variantesAsync = ref.watch(_variantesProvider(widget.producto.id));
		return Scaffold(
			appBar: AppBar(title: Text('Variantes: ${widget.producto.nombre}')),
			body: variantesAsync.when(
				data: (variantes) => ListView(
					padding: const EdgeInsets.all(16.0),
					children: [
						if (variantes.isEmpty)
							const Center(child: Text('Sin presentaciones. Agrega una abajo.')),
						...variantes.map(
							(v) => ListTile(
								title: Text(v.nombre),
								subtitle: Text('SKU ${v.sku} · ${v.codigoBarras}'),
								trailing: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									crossAxisAlignment: CrossAxisAlignment.end,
									children: [
										Text(
											formatearMoneda(v.precioBase),
											style: const TextStyle(fontWeight: FontWeight.bold),
										),
										Switch(
											value: v.activo,
											onChanged: (activo) async {
												final servicio =
													await ref.read(servicioAdminProvider.future);
												await servicio.actualizarVariante(
													v.copiarCon(activo: activo),
												);
												ref.invalidate(_variantesProvider(widget.producto.id));
												ref.invalidate(carritoNotifierProvider);
											},
										),
									],
								),
								onTap: () => _editarVariante(v),
							),
						),
						const Divider(),
						FilledButton.icon(
							onPressed: _agregarVariante,
							icon: const Icon(Icons.add),
							label: const Text('Agregar presentación'),
						),
					],
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _agregarVariante() async {
		final nombreController = TextEditingController();
		final skuController = TextEditingController();
		final codigoController = TextEditingController();
		final precioController = TextEditingController(text: '0');
		final guardar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Nueva presentación'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							controller: nombreController,
							decoration: const InputDecoration(labelText: 'Nombre (ej. 600ml)'),
						),
						TextField(
							controller: skuController,
							decoration: const InputDecoration(labelText: 'SKU'),
						),
						TextField(
							controller: codigoController,
							decoration: const InputDecoration(labelText: 'Código de barras'),
						),
						TextField(
							controller: precioController,
							keyboardType: TextInputType.number,
							decoration: const InputDecoration(labelText: 'Precio'),
						),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Guardar'),
					),
				],
			),
		);
		if (guardar != true) {
			nombreController.dispose();
			skuController.dispose();
			codigoController.dispose();
			precioController.dispose();
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarVariante(
			productoPadreId: widget.producto.id,
			nombre: nombreController.text.trim(),
			sku: skuController.text.trim(),
			codigoBarras: codigoController.text.trim(),
			precioBase: double.tryParse(precioController.text) ?? 0.0,
		);
		nombreController.dispose();
		skuController.dispose();
		codigoController.dispose();
		precioController.dispose();
		ref.invalidate(_variantesProvider(widget.producto.id));
		ref.invalidate(carritoNotifierProvider);
	}

	Future<void> _editarVariante(VarianteProducto variante) async {
		final nombreController = TextEditingController(text: variante.nombre);
		final skuController = TextEditingController(text: variante.sku);
		final codigoController = TextEditingController(text: variante.codigoBarras);
		final precioController = TextEditingController(text: variante.precioBase.toString());
		final guardar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Editar presentación'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							controller: nombreController,
							decoration: const InputDecoration(labelText: 'Nombre'),
						),
						TextField(
							controller: skuController,
							decoration: const InputDecoration(labelText: 'SKU'),
						),
						TextField(
							controller: codigoController,
							decoration: const InputDecoration(labelText: 'Código de barras'),
						),
						TextField(
							controller: precioController,
							keyboardType: TextInputType.number,
							decoration: const InputDecoration(labelText: 'Precio'),
						),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Guardar'),
					),
				],
			),
		);
		if (guardar != true) {
			nombreController.dispose();
			skuController.dispose();
			codigoController.dispose();
			precioController.dispose();
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarVariante(
			variante.copiarCon(
				nombre: nombreController.text.trim(),
				sku: skuController.text.trim(),
				codigoBarras: codigoController.text.trim(),
				precioBase: double.tryParse(precioController.text) ?? variante.precioBase,
			),
		);
		nombreController.dispose();
		skuController.dispose();
		codigoController.dispose();
		precioController.dispose();
		ref.invalidate(_variantesProvider(widget.producto.id));
		ref.invalidate(carritoNotifierProvider);
	}
}

final _variantesProvider = FutureProvider.family<List<VarianteProducto>, String>(
	(ref, productoId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		return servicio.listarVariantes(productoId);
	},
);
