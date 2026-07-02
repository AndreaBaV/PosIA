/// Ficha detallada de proveedor con productos vinculados.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaFichaProveedor extends ConsumerStatefulWidget {
	const PantallaFichaProveedor({required this.proveedor, super.key});

	final Proveedor proveedor;

	@override
	ConsumerState<PantallaFichaProveedor> createState() => _PantallaFichaProveedorState();
}

class _PantallaFichaProveedorState extends ConsumerState<PantallaFichaProveedor>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	late final TextEditingController _nombreController;
	late final TextEditingController _contactoController;
	late final TextEditingController _telefonoController;
	late final TextEditingController _emailController;
	late final TextEditingController _rfcController;
	late final TextEditingController _direccionController;
	late final TextEditingController _notasController;
	late final TextEditingController _diasCreditoController;

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 2, vsync: this);
		final p = widget.proveedor;
		_nombreController = TextEditingController(text: p.nombre);
		_contactoController = TextEditingController(text: p.contacto);
		_telefonoController = TextEditingController(text: p.telefono);
		_emailController = TextEditingController(text: p.email);
		_rfcController = TextEditingController(text: p.rfc);
		_direccionController = TextEditingController(text: p.direccion);
		_notasController = TextEditingController(text: p.notas);
		_diasCreditoController = TextEditingController(text: '${p.diasCredito}');
	}

	@override
	void dispose() {
		_tabs.dispose();
		_nombreController.dispose();
		_contactoController.dispose();
		_telefonoController.dispose();
		_emailController.dispose();
		_rfcController.dispose();
		_direccionController.dispose();
		_notasController.dispose();
		_diasCreditoController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final productosAsync = ref.watch(_productosProveedorProvider(widget.proveedor.id));
		final catalogoAsync = ref.watch(_catalogoVinculoProvider);
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.proveedor.nombre),
				bottom: TabBar(
					controller: _tabs,
					tabs: const [
						Tab(text: 'Datos'),
						Tab(text: 'Productos'),
					],
				),
				actions: [
					IconButton(
						icon: const Icon(Icons.delete_outline),
						color: PosiaColors.cancelar,
						tooltip: 'Eliminar proveedor',
						onPressed: _confirmarEliminar,
					),
					IconButton(icon: const Icon(Icons.save), onPressed: _guardar),
				],
			),
			body: TabBarView(
				controller: _tabs,
				children: [
					ListView(
						padding: const EdgeInsets.all(16.0),
						children: [
							TextField(
								controller: _nombreController,
								decoration: const InputDecoration(
									labelText: 'Nombre',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _contactoController,
								decoration: const InputDecoration(
									labelText: 'Contacto',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _telefonoController,
								decoration: const InputDecoration(
									labelText: 'Teléfono',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _emailController,
								decoration: const InputDecoration(
									labelText: 'Email',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _rfcController,
								decoration: const InputDecoration(
									labelText: 'RFC',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _direccionController,
								maxLines: 2,
								decoration: const InputDecoration(
									labelText: 'Dirección',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _diasCreditoController,
								keyboardType: TextInputType.number,
								decoration: const InputDecoration(
									labelText: 'Días de crédito',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _notasController,
								maxLines: 3,
								decoration: const InputDecoration(
									labelText: 'Notas',
									border: OutlineInputBorder(),
								),
							),
						],
					),
					Column(
						children: [
							Padding(
								padding: const EdgeInsets.all(12.0),
								child: catalogoAsync.when(
									data: (productos) => FilledButton.icon(
										onPressed: productos.isEmpty
											? null
											: () => _vincularProducto(productos),
										icon: const Icon(Icons.link),
										label: const Text('Vincular producto'),
									),
									loading: () => const SizedBox(),
									error: (_, _) => const SizedBox(),
								),
							),
							Expanded(
								child: productosAsync.when(
									data: (productos) {
										if (productos.isEmpty) {
											return const Center(
												child: Text('Sin productos vinculados'),
											);
										}
										return ListView.builder(
											itemCount: productos.length,
											itemBuilder: (_, i) {
												final p = productos[i];
												return ListTile(
													leading: const Icon(Icons.inventory_2),
													title: Text(p.nombre),
													subtitle: Text(p.codigoBarras),
													trailing: Text(formatearMoneda(p.precioBase)),
												);
											},
										);
									},
									loading: () => const Center(child: CircularProgressIndicator()),
									error: (e, _) => Center(child: Text('$e')),
								),
							),
						],
					),
				],
			),
		);
	}

	Future<void> _guardar() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarProveedor(
			widget.proveedor.copiarCon(
				nombre: _nombreController.text.trim(),
				contacto: _contactoController.text.trim(),
				telefono: _telefonoController.text.trim(),
				email: _emailController.text.trim(),
				rfc: _rfcController.text.trim(),
				direccion: _direccionController.text.trim(),
				notas: _notasController.text.trim(),
				diasCredito: int.tryParse(_diasCreditoController.text) ?? 0,
				activo: true,
			),
		);
		ref.invalidate(proveedoresAdminProvider);
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('Proveedor actualizado')),
		);
	}

	Future<void> _confirmarEliminar() async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar proveedor'),
				content: Text(
					'¿Eliminar permanentemente a "${widget.proveedor.nombre}"?\n\n'
					'Los productos vinculados quedarán sin proveedor. '
					'No es posible si tiene compras registradas.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (confirmar != true || !mounted) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.eliminarProveedor(widget.proveedor.id);
			if (!mounted) {
				return;
			}
			Navigator.of(context).pop();
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text(e.message),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}

	Future<void> _vincularProducto(List<Producto> productos) async {
		final seleccion = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Vincular producto'),
				content: SizedBox(
					width: 360.0,
					height: 320.0,
					child: ListView(
						children: productos
							.map(
								(p) => ListTile(
									title: Text(p.nombre),
									onTap: () => Navigator.pop(ctx, p.id),
								),
							)
							.toList(),
					),
				),
			),
		);
		if (seleccion == null) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.vincularProductoProveedor(seleccion, widget.proveedor.id);
		ref.invalidate(_productosProveedorProvider(widget.proveedor.id));
	}
}

final _productosProveedorProvider = FutureProvider.family<List<Producto>, String>((ref, id) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductosPorProveedor(id);
});

final _catalogoVinculoProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductos();
});
