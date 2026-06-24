/// Catalogo de tipos de presentacion (caja, bulto, etc.).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';

import '../providers/admin_providers.dart';

class PantallaTiposPresentacionAdmin extends ConsumerStatefulWidget {
	const PantallaTiposPresentacionAdmin({super.key});

	@override
	ConsumerState<PantallaTiposPresentacionAdmin> createState() =>
		_PantallaTiposPresentacionAdminState();
}

class _PantallaTiposPresentacionAdminState
	extends ConsumerState<PantallaTiposPresentacionAdmin> {
	@override
	Widget build(BuildContext context) {
		final tiposAsync = ref.watch(_tiposPresentacionProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Tipos de presentación'),
				actions: [
					IconButton(icon: const Icon(Icons.add), onPressed: _crearTipo),
				],
			),
			body: tiposAsync.when(
				data: (tipos) => ListView.builder(
					itemCount: tipos.length,
					itemBuilder: (context, i) {
						final t = tipos[i];
						return ListTile(
							title: Text(t.nombre),
							subtitle: Text('Unidad: ${t.unidad}'),
						);
					},
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Future<void> _crearTipo() async {
		final nombreController = TextEditingController();
		var unidad = 'pieza';
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setLocal) => AlertDialog(
					title: const Text('Nuevo tipo'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							TextField(
								controller: nombreController,
								decoration: const InputDecoration(
									labelText: 'Nombre (ej. Bulto 25kg)',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 12),
							DropdownButtonFormField<String>(
								initialValue: unidad,
								items: const [
									DropdownMenuItem(value: 'pieza', child: Text('Pieza')),
									DropdownMenuItem(value: 'kilogramo', child: Text('Kilogramo')),
									DropdownMenuItem(value: 'caja', child: Text('Caja')),
									DropdownMenuItem(value: 'bulto', child: Text('Bulto')),
								],
								onChanged: (v) => setLocal(() => unidad = v ?? 'pieza'),
								decoration: const InputDecoration(
									labelText: 'Unidad',
									border: OutlineInputBorder(),
								),
							),
						],
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
						FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
					],
				),
			),
		);
		if (ok != true || !mounted) {
			nombreController.dispose();
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.registrarTipoPresentacion(
			nombre: nombreController.text,
			unidad: unidad,
		);
		nombreController.dispose();
		ref.invalidate(_tiposPresentacionProvider);
	}
}

final _tiposPresentacionProvider = FutureProvider<List<TipoPresentacion>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarTiposPresentacion();
});
