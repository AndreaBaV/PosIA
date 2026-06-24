/// Gestion de almacenes (centros de distribucion).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaAlmacenesAdmin extends ConsumerStatefulWidget {
	const PantallaAlmacenesAdmin({super.key});

	@override
	ConsumerState<PantallaAlmacenesAdmin> createState() =>
		_PantallaAlmacenesAdminState();
}

class _PantallaAlmacenesAdminState extends ConsumerState<PantallaAlmacenesAdmin> {
	@override
	Widget build(BuildContext context) {
		final almacenesAsync = ref.watch(_almacenesProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Almacenes'),
				actions: [
					IconButton(
						icon: const Icon(Icons.add),
						onPressed: _crearAlmacen,
					),
				],
			),
			body: almacenesAsync.when(
				data: (lista) => lista.isEmpty
					? const Center(child: Text('Sin almacenes'))
					: ListView.builder(
						itemCount: lista.length,
						itemBuilder: (context, i) {
							final alm = lista[i];
							return ListTile(
								leading: const Icon(Icons.warehouse),
								title: Text(alm.nombre),
								subtitle: Text(
									alm.tiendaId == null
										? 'Central independiente'
										: 'Vinculado a tienda',
								),
								trailing: alm.activo
									? const Icon(Icons.check_circle, color: PosiaColors.cobrar)
									: const Icon(Icons.cancel, color: Colors.grey),
							);
						},
					),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _crearAlmacen() async {
		final controller = TextEditingController();
		final nombre = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Nuevo almacén'),
				content: TextField(
					controller: controller,
					decoration: const InputDecoration(
						labelText: 'Nombre',
						border: OutlineInputBorder(),
					),
					autofocus: true,
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, controller.text.trim()),
						child: const Text('Guardar'),
					),
				],
			),
		);
		controller.dispose();
		if (nombre == null || nombre.isEmpty || !mounted) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarAlmacen(nombre);
		ref.invalidate(_almacenesProvider);
	}
}

final _almacenesProvider = FutureProvider<List<Almacen>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarAlmacenes();
});
