/// Administracion de tiendas / sucursales.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaTiendasAdmin extends ConsumerStatefulWidget {
	const PantallaTiendasAdmin({super.key});

	@override
	ConsumerState<PantallaTiendasAdmin> createState() => _PantallaTiendasAdminState();
}

class _PantallaTiendasAdminState extends ConsumerState<PantallaTiendasAdmin> {
	final _nombreController = TextEditingController();
	final _direccionController = TextEditingController();
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_nombreController.dispose();
		_direccionController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final tiendasAsync = ref.watch(_tiendasAdminProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Tiendas'),
			),
			body: tiendasAsync.when(
				data: (tiendas) {
					final filtradas = tiendas.where((t) {
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						return t.nombre.toLowerCase().contains(q) ||
							t.direccion.toLowerCase().contains(q);
					}).toList();
					final activas = tiendas.where((t) => t.activa).length;
					return ListView(
						padding: const EdgeInsets.only(bottom: 24.0),
						children: [
							Padding(
								padding: const EdgeInsets.all(16.0),
								child: Text(
									'$activas de $LIMITE_MAX_TIENDAS tiendas activas',
									style: Theme.of(context).textTheme.titleMedium,
								),
							),
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar tienda...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							...filtradas.map((tienda) => Card(
								margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
								child: ListTile(
									leading: Icon(
										Icons.store,
										color: tienda.activa ? PosiaColors.cobrar : Colors.grey,
									),
									title: Text(tienda.nombre),
									subtitle: Text(tienda.direccion),
									trailing: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Switch(
												value: tienda.activa,
												onChanged: (activa) => _cambiarEstado(tienda, activa),
											),
											IconButton(
												icon: const Icon(Icons.delete_outline, color: PosiaColors.cancelar),
												onPressed: () => _eliminar(tienda),
											),
										],
									),
									onTap: () => _editar(tienda),
								),
							)),
							const Divider(height: 32.0),
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 16.0),
								child: Column(
									children: [
										TextField(
											controller: _nombreController,
											decoration: const InputDecoration(
												labelText: 'Nombre de tienda',
												border: OutlineInputBorder(),
											),
										),
										const SizedBox(height: 8.0),
										TextField(
											controller: _direccionController,
											decoration: const InputDecoration(
												labelText: 'Direccion',
												border: OutlineInputBorder(),
											),
										),
										const SizedBox(height: 12.0),
										FilledButton.icon(
											onPressed: activas >= LIMITE_MAX_TIENDAS ? null : _agregar,
											icon: const Icon(Icons.add),
											label: const Text('Agregar tienda'),
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

	Future<void> _agregar() async {
		final nombre = _nombreController.text.trim();
		if (nombre.isEmpty) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.registrarTienda(
				nombre: nombre,
				direccion: _direccionController.text.trim(),
			);
			_nombreController.clear();
			_direccionController.clear();
			ref.invalidate(_tiendasAdminProvider);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _cambiarEstado(Tienda tienda, bool activa) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		if (activa) {
			final todas = await servicio.listarTodasLasTiendas();
			final activas = todas.where((t) => t.activa).length;
			if (activas >= LIMITE_MAX_TIENDAS) {
				if (!mounted) {
					return;
				}
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Limite de $LIMITE_MAX_TIENDAS tiendas activas'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
			await servicio.actualizarTienda(
				Tienda(
					id: tienda.id,
					nombre: tienda.nombre,
					direccion: tienda.direccion,
					activa: true,
				),
			);
		} else {
			await servicio.desactivarTienda(tienda.id);
		}
		ref.invalidate(_tiendasAdminProvider);
	}

	Future<void> _editar(Tienda tienda) async {
		final nombreController = TextEditingController(text: tienda.nombre);
		final direccionController = TextEditingController(text: tienda.direccion);
		final guardar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Editar tienda'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							controller: nombreController,
							decoration: const InputDecoration(labelText: 'Nombre'),
						),
						TextField(
							controller: direccionController,
							decoration: const InputDecoration(labelText: 'Direccion'),
						),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
				],
			),
		);
		if (guardar != true) {
			nombreController.dispose();
			direccionController.dispose();
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarTienda(
			Tienda(
				id: tienda.id,
				nombre: nombreController.text.trim(),
				direccion: direccionController.text.trim(),
				activa: tienda.activa,
			),
		);
		nombreController.dispose();
		direccionController.dispose();
		ref.invalidate(_tiendasAdminProvider);
	}

	Future<void> _eliminar(Tienda tienda) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar tienda'),
				content: Text('Se eliminara "${tienda.nombre}" permanentemente.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (confirmar != true) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final ok = await servicio.eliminarTienda(tienda.id);
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(ok ? 'Tienda eliminada' : 'No se puede eliminar (tienda activa o con ventas)'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(_tiendasAdminProvider);
	}
}

final _tiendasAdminProvider = FutureProvider<List<Tienda>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarTodasLasTiendas();
});
