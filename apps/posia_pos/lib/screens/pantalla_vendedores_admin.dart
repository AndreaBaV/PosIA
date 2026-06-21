/// Administracion de vendedores con UI mejorada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaVendedoresAdmin extends ConsumerStatefulWidget {
	const PantallaVendedoresAdmin({super.key});

	@override
	ConsumerState<PantallaVendedoresAdmin> createState() =>
		_PantallaVendedoresAdminState();
}

class _PantallaVendedoresAdminState extends ConsumerState<PantallaVendedoresAdmin> {
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
		final vendedoresAsync = ref.watch(_vendedoresProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Vendedores')),
			body: vendedoresAsync.when(
				data: (vendedores) {
					final filtrados = vendedores.where((v) {
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						return v.nombre.toLowerCase().contains(q) ||
							v.codigo.toLowerCase().contains(q);
					}).toList();
					return ListView(
						padding: const EdgeInsets.only(bottom: 24.0),
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar vendedor...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							if (filtrados.isEmpty)
								const Padding(
									padding: EdgeInsets.all(24.0),
									child: Center(child: Text('Sin vendedores registrados')),
								),
							...filtrados.map(
								(v) => Card(
									margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
									child: ListTile(
										leading: CircleAvatar(
											backgroundColor: v.activo
												? PosiaColors.cobrar.withValues(alpha: 0.15)
												: Colors.grey.shade200,
											child: Icon(
												Icons.badge,
												color: v.activo ? PosiaColors.cobrar : Colors.grey,
											),
										),
										title: Text(
											v.nombre,
											style: TextStyle(
												fontWeight: FontWeight.w600,
												decoration: v.activo ? null : TextDecoration.lineThrough,
											),
										),
										subtitle: Text('Código: ${v.codigo}'),
										trailing: Switch(
											value: v.activo,
											onChanged: (activo) async {
												if (!activo) {
													final ok = await _confirmarDesactivar(v.nombre);
													if (!ok) {
														return;
													}
												}
												final servicio = await ref.read(servicioAdminProvider.future);
												await servicio.actualizarVendedor(
													v.copiarCon(activo: activo),
													operador: ref.read(sesionUsuarioProvider),
												);
												ref.invalidate(_vendedoresProvider);
											},
										),
										onTap: () => _editarVendedor(v),
									),
								),
							),
							const Divider(height: 32.0),
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 16.0),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text(
											'Nuevo vendedor',
											style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
										),
										const SizedBox(height: 4.0),
										Text(
											'El código se asigna automáticamente',
											style: Theme.of(context).textTheme.bodySmall,
										),
										const SizedBox(height: 12.0),
										TextField(
											controller: _nombreController,
											decoration: const InputDecoration(
												labelText: 'Nombre completo',
												border: OutlineInputBorder(),
												prefixIcon: Icon(Icons.person),
											),
										),
										const SizedBox(height: 12.0),
										FilledButton.icon(
											onPressed: _agregar,
											icon: const Icon(Icons.person_add),
											label: const Text('Agregar vendedor'),
										),
									],
								),
							),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<bool> _confirmarDesactivar(String nombre) async {
		final resultado = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Desactivar vendedor'),
				content: Text('Desactivar a $nombre?'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desactivar')),
				],
			),
		);
		return resultado ?? false;
	}

	Future<void> _editarVendedor(Vendedor vendedor) async {
		final nombreController = TextEditingController(text: vendedor.nombre);
		final guardar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Editar vendedor'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							'Código: ${vendedor.codigo}',
							style: Theme.of(context).textTheme.bodyMedium?.copyWith(
								color: Colors.grey.shade700,
							),
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: nombreController,
							decoration: const InputDecoration(labelText: 'Nombre'),
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
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarVendedor(
			vendedor.copiarCon(nombre: nombreController.text.trim()),
			operador: ref.read(sesionUsuarioProvider),
		);
		nombreController.dispose();
		ref.invalidate(_vendedoresProvider);
	}

	Future<void> _agregar() async {
		final nombre = _nombreController.text.trim();
		if (nombre.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Ingresa el nombre del vendedor')),
			);
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final operador = ref.read(sesionUsuarioProvider);
		final vendedor = await servicio.registrarVendedor(
			nombre: nombre,
			operador: operador,
		);
		_nombreController.clear();
		ref.invalidate(_vendedoresProvider);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text('${vendedor.nombre} registrado con código ${vendedor.codigo}'),
				backgroundColor: PosiaColors.cobrar,
			),
		);
	}
}

final _vendedoresProvider = FutureProvider<List<Vendedor>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarVendedores(operador: ref.watch(sesionUsuarioProvider));
});
