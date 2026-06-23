/// Administracion de proveedores.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import 'pantalla_ficha_proveedor.dart';

class PantallaProveedoresAdmin extends ConsumerStatefulWidget {
	const PantallaProveedoresAdmin({super.key});

	@override
	ConsumerState<PantallaProveedoresAdmin> createState() =>
		_PantallaProveedoresAdminState();
}

class _PantallaProveedoresAdminState extends ConsumerState<PantallaProveedoresAdmin> {
	final _nombreController = TextEditingController();
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_nombreController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final proveedoresAsync = ref.watch(_proveedoresProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Proveedores')),
			body: proveedoresAsync.when(
				data: (proveedores) {
					final filtrados = proveedores.where((p) {
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						return p.nombre.toLowerCase().contains(q) ||
							p.contacto.toLowerCase().contains(q);
					}).toList();
					return ListView(
					padding: const EdgeInsets.all(16.0),
					children: [
						CampoBusqueda(
							controlador: _busquedaController,
							sugerencia: 'Buscar proveedor...',
							alCambiar: (v) => setState(() => _filtro = v.trim()),
						),
						if (filtrados.isEmpty)
							const Center(child: Text('Sin proveedores registrados')),
						...filtrados.map(
							(p) => ListTile(
								title: Text(p.nombre),
								subtitle: Text('${p.contacto} · ${p.telefono}'),
								trailing: IconButton(
									icon: const Icon(Icons.delete_outline),
									color: PosiaColors.cancelar,
									tooltip: 'Eliminar proveedor',
									onPressed: () => _confirmarEliminar(p),
								),
								onTap: () => _abrirFicha(p),
							),
						),
						const Divider(),
						TextField(
							controller: _nombreController,
							decoration: const InputDecoration(labelText: 'Nombre proveedor'),
						),
						FilledButton(onPressed: _agregar, child: const Text('Agregar')),
					],
				);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _abrirFicha(Proveedor proveedor) async {
		await Navigator.of(context).push<void>(
			MaterialPageRoute<void>(
				builder: (_) => PantallaFichaProveedor(proveedor: proveedor),
			),
		);
		ref.invalidate(_proveedoresProvider);
	}

	Future<void> _agregar() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarProveedor(nombre: _nombreController.text.trim());
		_nombreController.clear();
		ref.invalidate(_proveedoresProvider);
	}

	Future<void> _confirmarEliminar(Proveedor proveedor) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar proveedor'),
				content: Text(
					'¿Eliminar permanentemente a "${proveedor.nombre}"?\n\n'
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
			await servicio.eliminarProveedor(proveedor.id);
			ref.invalidate(_proveedoresProvider);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Proveedor eliminado')),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(e.message),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}
}

final _proveedoresProvider = FutureProvider<List<Proveedor>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProveedores();
});
