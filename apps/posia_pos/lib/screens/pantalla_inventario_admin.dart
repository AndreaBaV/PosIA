/// Pantalla de inventario agrupado por producto con ajustes rapidos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaInventarioAdmin extends ConsumerStatefulWidget {
	const PantallaInventarioAdmin({super.key});

	@override
	ConsumerState<PantallaInventarioAdmin> createState() => _PantallaInventarioAdminState();
}

class _PantallaInventarioAdminState extends ConsumerState<PantallaInventarioAdmin> {
	final _busquedaController = TextEditingController();
	String _filtro = '';
	bool _soloBajoMinimo = false;

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final inventarioAsync = ref.watch(_inventarioAgrupadoProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Existencias')),
			body: Column(
				children: [
					CampoBusqueda(
						controlador: _busquedaController,
						sugerencia: 'Buscar producto...',
						alCambiar: (v) => setState(() => _filtro = v.trim()),
					),
					SwitchListTile(
						title: const Text('Solo bajo minimo'),
						value: _soloBajoMinimo,
						onChanged: (v) => setState(() => _soloBajoMinimo = v),
					),
					Expanded(
						child: inventarioAsync.when(
							data: (registros) {
								final filtrados = registros.where((r) {
									if (_soloBajoMinimo && !r.bajoMinimo) {
										return false;
									}
									if (_filtro.isEmpty) {
										return true;
									}
									return r.nombreProducto.toLowerCase().contains(
										_filtro.toLowerCase(),
									);
								}).toList();
								if (filtrados.isEmpty) {
									return const Center(child: Text('Sin registros'));
								}
								return ListView.builder(
									itemCount: filtrados.length,
									itemBuilder: (_, i) {
										final reg = filtrados[i];
										return Card(
											margin: const EdgeInsets.symmetric(
												horizontal: 12.0,
												vertical: 4.0,
											),
											color: reg.bajoMinimo ? Colors.red.shade50 : null,
											child: ExpansionTile(
												leading: Icon(
													reg.bajoMinimo ? Icons.warning : Icons.inventory,
													color: reg.bajoMinimo
														? PosiaColors.cancelar
														: PosiaColors.cobrar,
												),
												title: Text(reg.nombreProducto),
												subtitle: Text(
													'Local: ${reg.cantidadLocal.toStringAsFixed(0)} · '
													'Total: ${reg.totalGlobal.toStringAsFixed(0)}',
												),
												children: [
													...reg.existenciasPorTienda.entries.map(
														(e) => ListTile(
															dense: true,
															title: Text(e.key),
															trailing: Text(e.value.toStringAsFixed(0)),
														),
													),
													OverflowBar(
														children: [
															TextButton.icon(
																onPressed: () => _ajustar(
																	reg,
																	TipoMovimientoInventario.entrada,
																),
																icon: const Icon(Icons.add),
																label: const Text('Entrada'),
															),
															TextButton.icon(
																onPressed: () => _ajustar(
																	reg,
																	TipoMovimientoInventario.salida,
																),
																icon: const Icon(Icons.remove),
																label: const Text('Salida'),
															),
															TextButton.icon(
																onPressed: () => _ajustar(
																	reg,
																	TipoMovimientoInventario.ajuste,
																),
																icon: const Icon(Icons.tune),
																label: const Text('Ajustar'),
															),
														],
													),
												],
											),
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
		);
	}

	Future<void> _ajustar(InventarioAgrupado reg, TipoMovimientoInventario tipo) async {
		final controller = TextEditingController(
			text: tipo == TipoMovimientoInventario.ajuste
				? reg.cantidadLocal.toStringAsFixed(0)
				: '1',
		);
		final motivoController = TextEditingController(
			text: tipo == TipoMovimientoInventario.entrada
				? 'Entrada manual'
				: tipo == TipoMovimientoInventario.salida
					? 'Salida manual'
					: 'Ajuste de inventario',
		);
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text('${tipo.name}: ${reg.nombreProducto}'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							controller: controller,
							keyboardType: TextInputType.number,
							decoration: InputDecoration(
								labelText: tipo == TipoMovimientoInventario.ajuste
									? 'Cantidad final'
									: 'Cantidad',
							),
						),
						TextField(
							controller: motivoController,
							decoration: const InputDecoration(labelText: 'Motivo'),
						),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
				],
			),
		);
		if (confirmar != true) {
			controller.dispose();
			motivoController.dispose();
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.registrarMovimientoInventario(
				productoId: reg.productoId,
				tipo: tipo,
				cantidad: double.tryParse(controller.text) ?? 0.0,
				motivo: motivoController.text.trim(),
			);
			ref.invalidate(_inventarioAgrupadoProvider);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Movimiento registrado')),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			controller.dispose();
			motivoController.dispose();
		}
	}
}

final _inventarioAgrupadoProvider = FutureProvider<List<InventarioAgrupado>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerInventarioAgrupado();
});
