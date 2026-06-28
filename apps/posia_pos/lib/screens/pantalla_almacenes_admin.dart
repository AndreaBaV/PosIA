/// Gestion de almacenes (centros de distribucion).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/inventario_admin_providers.dart';
import 'pantalla_detalle_almacen.dart';

class PantallaAlmacenesAdmin extends ConsumerStatefulWidget {
	const PantallaAlmacenesAdmin({super.key});

	@override
	ConsumerState<PantallaAlmacenesAdmin> createState() =>
		_PantallaAlmacenesAdminState();
}

class _PantallaAlmacenesAdminState extends ConsumerState<PantallaAlmacenesAdmin> {
	@override
	Widget build(BuildContext context) {
		final almacenesAsync = ref.watch(almacenesAdminProvider);
		final resumenAsync = ref.watch(resumenAlmacenesProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Almacenes'),
				actions: [
					IconButton(
						icon: const Icon(Icons.refresh),
						onPressed: () {
							ref.invalidate(almacenesAdminProvider);
							ref.invalidate(resumenAlmacenesProvider);
						},
					),
					IconButton(
						icon: const Icon(Icons.add),
						onPressed: _crearAlmacen,
					),
				],
			),
			body: almacenesAsync.when(
				data: (lista) {
					if (lista.isEmpty) {
						return const Center(child: Text('Sin almacenes'));
					}
					final resumenes = resumenAsync.asData?.value ?? [];
					final resumenPorId = {for (final r in resumenes) r.almacenId: r};
					return ListView(
						padding: const EdgeInsets.symmetric(vertical: 8.0),
						children: [
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
								child: Text(
									'Ubicaciones de inventario central. Toque un almacén para ver '
									'existencias por producto o registrar entradas.',
									style: Theme.of(context).textTheme.bodySmall?.copyWith(
										color: Colors.grey,
									),
								),
							),
							...lista.map((alm) {
								final resumen = resumenPorId[alm.id];
								return Card(
									margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
									child: ListTile(
										leading: CircleAvatar(
											backgroundColor: PosiaColors.neutro.withValues(alpha: 0.15),
											child: const Icon(Icons.warehouse, color: PosiaColors.neutro),
										),
										title: Text(alm.nombre),
										subtitle: Text(
											[
												alm.tiendaId == null
													? 'Central independiente'
													: 'Vinculado a tienda',
												if (resumen != null)
													'${resumen.productosConStock} productos · '
													'${resumen.totalUnidades.toStringAsFixed(1)} u.',
												if (resumen == null) 'Sin existencias registradas',
											].join(' · '),
										),
										trailing: alm.activo
											? const Icon(Icons.chevron_right)
											: const Icon(Icons.cancel, color: Colors.grey),
										onTap: alm.activo
											? () => Navigator.of(context).push<void>(
												MaterialPageRoute<void>(
													builder: (_) => PantallaDetalleAlmacen(
														almacenId: alm.id,
														nombreAlmacen: alm.nombre,
													),
												),
											)
											: null,
									),
								);
							}),
						],
					);
				},
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
						labelText: 'Nombre (ej. Norte, Sur, Centro)',
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
		ref.invalidate(almacenesAdminProvider);
		ref.invalidate(resumenAlmacenesProvider);
		ref.invalidate(inventarioAgrupadoProvider);
	}
}
