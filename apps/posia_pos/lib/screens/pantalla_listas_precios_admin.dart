/// Admin de listas de precios comerciales.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';

import '../providers/admin_providers.dart';

class PantallaListasPreciosAdmin extends ConsumerWidget {
	const PantallaListasPreciosAdmin({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final listasAsync = ref.watch(_listasProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Listas de precios'),
				actions: [
					IconButton(
						icon: const Icon(Icons.add),
						tooltip: 'Nueva lista',
						onPressed: () => _crearLista(context, ref),
					),
				],
			),
			body: listasAsync.when(
				data: (listas) => listas.isEmpty
					? const Center(
						child: Text('Sin listas. Cree una para precios mayoristas.'),
					)
					: ListView.builder(
						itemCount: listas.length,
						itemBuilder: (context, indice) {
							final lista = listas[indice];
							return ListTile(
								leading: const Icon(Icons.sell),
								title: Text(lista.nombre),
								subtitle: Text(lista.activa ? 'Activa' : 'Inactiva'),
								trailing: IconButton(
									icon: const Icon(Icons.delete_outline),
									onPressed: () => _eliminar(context, ref, lista),
								),
							);
						},
					),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _crearLista(BuildContext context, WidgetRef ref) async {
		final ctrl = TextEditingController();
		final nombre = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Nueva lista de precios'),
				content: TextField(
					controller: ctrl,
					decoration: const InputDecoration(
						labelText: 'Nombre',
						hintText: 'Mayoreo, Distribuidor...',
					),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
						child: const Text('Crear'),
					),
				],
			),
		);
		ctrl.dispose();
		if (nombre == null || nombre.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarListaPrecios(nombre);
		ref.invalidate(_listasProvider);
	}

	Future<void> _eliminar(BuildContext context, WidgetRef ref, ListaPrecios lista) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar lista'),
				content: Text('Eliminar "${lista.nombre}" y sus precios?'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Si')),
				],
			),
		);
		if (ok != true) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.eliminarListaPrecios(lista.id);
		ref.invalidate(_listasProvider);
	}
}

final _listasProvider = FutureProvider<List<ListaPrecios>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarListasPrecios();
});
