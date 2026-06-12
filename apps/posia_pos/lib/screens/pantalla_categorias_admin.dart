/// Administracion de categorias personalizables.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaCategoriasAdmin extends ConsumerStatefulWidget {
	const PantallaCategoriasAdmin({super.key});

	@override
	ConsumerState<PantallaCategoriasAdmin> createState() =>
		_PantallaCategoriasAdminState();
}

class _PantallaCategoriasAdminState extends ConsumerState<PantallaCategoriasAdmin> {
	final _nombreController = TextEditingController();
	final _busquedaController = TextEditingController();
	String _filtro = '';
	String _iconoNuevo = 'shopping_basket';
	String _colorNuevo = '#4CAF50';

	@override
	void dispose() {
		_nombreController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final categoriasAsync = ref.watch(_categoriasProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Categorias')),
			body: categoriasAsync.when(
				data: (categorias) {
					final filtradas = categorias.where((c) {
						if (_filtro.isEmpty) {
							return true;
						}
						return c.nombre.toLowerCase().contains(_filtro.toLowerCase());
					}).toList();
					return ListView(
						padding: const EdgeInsets.only(bottom: 24.0),
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar categoria...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							...filtradas.asMap().entries.map((entry) {
								final indice = entry.key;
								final c = entry.value;
								final color = IconosCategoria.resolverColor(c.colorHex);
								return Card(
									margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
									child: ListTile(
										leading: CircleAvatar(
											backgroundColor: color.withValues(alpha: 0.2),
											child: Icon(
												IconosCategoria.resolver(c.icono),
												color: color,
											),
										),
										title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
										subtitle: Text('Orden ${c.orden + 1}'),
										trailing: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												IconButton(
													icon: const Icon(Icons.arrow_upward),
													onPressed: indice > 0
														? () => _mover(categorias, c.id, -1)
														: null,
												),
												IconButton(
													icon: const Icon(Icons.arrow_downward),
													onPressed: indice < categorias.length - 1
														? () => _mover(categorias, c.id, 1)
														: null,
												),
												Switch(
													value: c.activa,
													onChanged: (activa) async {
														final servicio =
															await ref.read(servicioAdminProvider.future);
														await servicio.actualizarCategoria(c.copiarCon(activa: activa));
														ref.invalidate(_categoriasProvider);
													},
												),
											],
										),
										onTap: () => _editar(c),
									),
								);
							}),
							const Divider(height: 32.0),
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 16.0),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text(
											'Nueva categoria',
											style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
										),
										const SizedBox(height: 12.0),
										TextField(
											controller: _nombreController,
											decoration: const InputDecoration(
												labelText: 'Nombre',
												border: OutlineInputBorder(),
											),
										),
										const SizedBox(height: 12.0),
										const Text('Icono'),
										const SizedBox(height: 4.0),
										Wrap(
											spacing: 8.0,
											children: IconosCategoria.opciones.entries.map((e) {
												final seleccionado = _iconoNuevo == e.key;
												return ChoiceChip(
													selected: seleccionado,
													label: Icon(e.value),
													onSelected: (_) => setState(() => _iconoNuevo = e.key),
												);
											}).toList(),
										),
										const SizedBox(height: 12.0),
										const Text('Color'),
										const SizedBox(height: 4.0),
										Wrap(
											spacing: 8.0,
											children: IconosCategoria.colores.entries.map((e) {
												final seleccionado = _colorNuevo == e.value;
												return ChoiceChip(
													selected: seleccionado,
													label: Text(e.key),
													avatar: CircleAvatar(
														backgroundColor: IconosCategoria.resolverColor(e.value),
														radius: 8.0,
													),
													onSelected: (_) => setState(() => _colorNuevo = e.value),
												);
											}).toList(),
										),
										const SizedBox(height: 16.0),
										FilledButton.icon(
											onPressed: _agregarCategoria,
											icon: const Icon(Icons.add),
											label: const Text('Agregar categoria'),
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

	Future<void> _mover(List<Categoria> categorias, String id, int delta) async {
		final ids = categorias.map((c) => c.id).toList();
		final indice = ids.indexOf(id);
		final nuevoIndice = indice + delta;
		if (nuevoIndice < 0 || nuevoIndice >= ids.length) {
			return;
		}
		final temp = ids[indice];
		ids[indice] = ids[nuevoIndice];
		ids[nuevoIndice] = temp;
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.reordenarCategorias(ids);
		ref.invalidate(_categoriasProvider);
		ref.invalidate(contenedorServiciosProvider);
	}

	Future<void> _editar(Categoria categoria) async {
		final nombreController = TextEditingController(text: categoria.nombre);
		var icono = categoria.icono;
		var color = categoria.colorHex;
		final guardar = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (context, setDialogState) => AlertDialog(
					title: const Text('Editar categoria'),
					content: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								TextField(
									controller: nombreController,
									decoration: const InputDecoration(labelText: 'Nombre'),
								),
								const SizedBox(height: 12.0),
								Wrap(
									spacing: 6.0,
									children: IconosCategoria.opciones.entries.map((e) {
										return ChoiceChip(
											selected: icono == e.key,
											label: Icon(e.value, size: 20.0),
											onSelected: (_) => setDialogState(() => icono = e.key),
										);
									}).toList(),
								),
								const SizedBox(height: 8.0),
								Wrap(
									spacing: 6.0,
									children: IconosCategoria.colores.entries.map((e) {
										return ChoiceChip(
											selected: color == e.value,
											label: Text(e.key, style: const TextStyle(fontSize: 11.0)),
											onSelected: (_) => setDialogState(() => color = e.value),
										);
									}).toList(),
								),
							],
						),
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
						FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
					],
				),
			),
		);
		if (guardar != true) {
			nombreController.dispose();
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarCategoria(
			categoria.copiarCon(
				nombre: nombreController.text.trim(),
				icono: icono,
				colorHex: color,
			),
		);
		nombreController.dispose();
		ref.invalidate(_categoriasProvider);
		ref.invalidate(contenedorServiciosProvider);
	}

	Future<void> _agregarCategoria() async {
		final nombre = _nombreController.text.trim();
		if (nombre.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarCategoria(
			nombre: nombre,
			icono: _iconoNuevo,
			colorHex: _colorNuevo,
		);
		_nombreController.clear();
		ref.invalidate(_categoriasProvider);
		ref.invalidate(contenedorServiciosProvider);
	}
}

final _categoriasProvider = FutureProvider<List<Categoria>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCategorias();
});
