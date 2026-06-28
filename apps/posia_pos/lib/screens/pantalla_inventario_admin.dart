/// Pantalla de inventario agrupado por producto con ajustes rapidos.

library;



import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:posia_core/posia_core.dart';

import 'package:posia_database/posia_database.dart';

import 'package:posia_ui/posia_ui.dart';



import '../providers/admin_providers.dart';
import '../providers/inventario_admin_providers.dart';
import 'pantalla_compras_admin.dart';



class PantallaInventarioAdmin extends ConsumerStatefulWidget {

	const PantallaInventarioAdmin({super.key});



	@override

	ConsumerState<PantallaInventarioAdmin> createState() => _PantallaInventarioAdminState();

}



class _PantallaInventarioAdminState extends ConsumerState<PantallaInventarioAdmin> {

	final _busquedaController = TextEditingController();

	String _filtro = '';

	bool _soloBajoMinimo = false;

	String? _tiendaOperacionId;



	@override

	void dispose() {

		_busquedaController.dispose();

		super.dispose();

	}



	@override
	Widget build(BuildContext context) {
		final tiendasAsync = ref.watch(tiendasInventarioProvider);
		final tiendaGestionId = _tiendaOperacionId ?? tiendasAsync.asData?.value.firstOrNull?.id;
		final inventarioAsync = ref.watch(inventarioAgrupadoProvider(tiendaGestionId));
		return Scaffold(
			appBar: AppBar(title: const Text('Existencias')),
			body: Column(
				children: [
					tiendasAsync.when(
						data: (tiendas) {
							if (tiendas.isEmpty) {
								return const SizedBox.shrink();
							}
							final seleccionada = _tiendaOperacionId ?? tiendas.first.id;
							return Padding(
								padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
								child: DropdownButtonFormField<String>(
									initialValue: seleccionada,
									decoration: const InputDecoration(
										labelText: 'Tienda a gestionar',
										border: OutlineInputBorder(),
									),
									items: tiendas
										.map(
											(t) => DropdownMenuItem(
												value: t.id,
												child: Text(t.nombre),
											),
										)
										.toList(),
									onChanged: (v) => setState(() => _tiendaOperacionId = v),
								),
							);
						},
						loading: () => const LinearProgressIndicator(),
						error: (_, _) => const SizedBox.shrink(),
					),

					CampoBusqueda(

						controlador: _busquedaController,

						sugerencia: 'Buscar producto...',

						alCambiar: (v) => setState(() => _filtro = v.trim()),

					),

					SwitchListTile(

						title: const Text('Solo bajo mínimo'),

						value: _soloBajoMinimo,

						onChanged: (v) => setState(() => _soloBajoMinimo = v),

					),

					Expanded(

						child: inventarioAsync.when(

							data: (datos) {
								final tiendaId = tiendaGestionId ?? datos.tiendaReferenciaId;

								final filtrados = datos.registros.where((r) {

									if (_soloBajoMinimo && !r.bajoMinimoEn(tiendaId)) {

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

								final nombreTienda = datos.nombresTienda[tiendaId] ?? 'Tienda';
								final totalTiendas = filtrados.fold<double>(
									0.0,
									(s, r) => s + r.totalGlobal,
								);
								final totalAlmacenes = filtrados.fold<double>(
									0.0,
									(s, r) => s + r.totalAlmacenes,
								);

								return ListView.builder(
									itemCount: filtrados.length + 1,
									itemBuilder: (_, i) {
										if (i == 0) {
											return Card(
												margin: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
												color: PosiaColors.tarjeta,
												child: Padding(
													padding: const EdgeInsets.all(16.0),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.stretch,
														children: [
															Text(
																'Resumen general',
																style: Theme.of(context).textTheme.titleSmall,
															),
															const SizedBox(height: 8.0),
															Row(
																children: [
																	Expanded(
																		child: _KpiExistencia(
																			etiqueta: 'En tiendas',
																			valor: totalTiendas,
																			icono: Icons.storefront,
																			color: PosiaColors.cobrar,
																		),
																	),
																	const SizedBox(width: 8.0),
																	Expanded(
																		child: _KpiExistencia(
																			etiqueta: 'En almacenes',
																			valor: totalAlmacenes,
																			icono: Icons.warehouse,
																			color: PosiaColors.neutro,
																		),
																	),
																],
															),
															const SizedBox(height: 8.0),
															_KpiExistencia(
																etiqueta: 'Total empresa',
																valor: totalTiendas + totalAlmacenes,
																icono: Icons.inventory_2,
																color: Theme.of(context).colorScheme.primary,
															),
														],
													),
												),
											);
										}

										final reg = filtrados[i - 1];

										final cantidadTienda = reg.cantidadEn(tiendaId);

										final bajoMinimo = reg.bajoMinimoEn(tiendaId);

										return Card(

											margin: const EdgeInsets.symmetric(

												horizontal: 12.0,

												vertical: 4.0,

											),

											color: bajoMinimo ? Colors.red.shade50 : null,

											child: ExpansionTile(

												leading: Icon(

													bajoMinimo ? Icons.warning : Icons.inventory,

													color: bajoMinimo

														? PosiaColors.cancelar

														: PosiaColors.cobrar,

												),

												title: Text(reg.nombreProducto),

												subtitle: Text(
													'$nombreTienda: ${cantidadTienda.toStringAsFixed(1)} · '
													'Almacenes: ${reg.totalAlmacenes.toStringAsFixed(1)} · '
													'Total: ${reg.totalEmpresa.toStringAsFixed(1)}',
												),

												children: [
													if (reg.existenciasPorTienda.isNotEmpty) ...[
														const ListTile(
															dense: true,
															title: Text(
																'Tiendas',
																style: TextStyle(fontWeight: FontWeight.w600),
															),
														),
														...reg.existenciasPorTienda.entries.map(
															(e) => ListTile(
																dense: true,
																leading: const Icon(Icons.storefront, size: 18.0),
																title: Text(e.key),
																trailing: Text(e.value.toStringAsFixed(1)),
															),
														),
														ListTile(
															dense: true,
															title: const Text(
																'Subtotal tiendas',
																style: TextStyle(fontWeight: FontWeight.w500),
															),
															trailing: Text(
																reg.totalGlobal.toStringAsFixed(1),
																style: const TextStyle(fontWeight: FontWeight.bold),
															),
														),
													],
													if (reg.existenciasPorAlmacen.isNotEmpty) ...[
														const Divider(height: 8.0),
														const ListTile(
															dense: true,
															title: Text(
																'Almacenes',
																style: TextStyle(fontWeight: FontWeight.w600),
															),
														),
														...reg.existenciasPorAlmacen.entries.map(
															(e) => ListTile(
																dense: true,
																leading: const Icon(Icons.warehouse, size: 18.0),
																title: Text(e.key),
																trailing: Text(e.value.toStringAsFixed(1)),
															),
														),
														ListTile(
															dense: true,
															title: const Text(
																'Subtotal almacenes',
																style: TextStyle(fontWeight: FontWeight.w500),
															),
															trailing: Text(
																reg.totalAlmacenes.toStringAsFixed(1),
																style: const TextStyle(fontWeight: FontWeight.bold),
															),
														),
													],
													ListTile(
														dense: true,
														title: const Text(
															'Total general',
															style: TextStyle(fontWeight: FontWeight.bold),
														),
														trailing: Text(
															reg.totalEmpresa.toStringAsFixed(1),
															style: const TextStyle(fontWeight: FontWeight.bold),
														),
													),

													OverflowBar(

														children: [

															TextButton.icon(
																onPressed: () => Navigator.of(context).push(
																	MaterialPageRoute<void>(
																		builder: (_) => const PantallaComprasAdmin(),
																	),
																),
																icon: const Icon(Icons.shopping_cart),
																label: const Text('Comprar'),
															),

															TextButton.icon(

																onPressed: () => _ajustar(

																	reg,

																	tiendaId,

																	TipoMovimientoInventario.salida,

																	cantidadTienda,

																),

																icon: const Icon(Icons.remove),

																label: const Text('Salida'),

															),

															TextButton.icon(

																onPressed: () => _ajustar(

																	reg,

																	tiendaId,

																	TipoMovimientoInventario.ajuste,

																	cantidadTienda,

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



	Future<void> _ajustar(
		InventarioAgrupado reg,
		String tiendaId,
		TipoMovimientoInventario tipo,
		double cantidadActual,
	) async {
		final controller = TextEditingController(
			text: tipo == TipoMovimientoInventario.ajuste
				? cantidadActual.toStringAsFixed(1)
				: '1',
		);
		var motivoSeleccionado = motivoInventarioPredeterminado(tipo);
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setDialog) => AlertDialog(
					title: Text('${etiquetaTipoMovimiento(tipo)}: ${reg.nombreProducto}'),
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
							const SizedBox(height: 12.0),
							SelectorMotivoInventario(
								tipo: tipo,
								valor: motivoSeleccionado,
								alCambiar: (motivo) => setDialog(() => motivoSeleccionado = motivo),
							),
						],
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
						FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
					],
				),
			),
		);
		if (confirmar != true) {
			controller.dispose();
			return;
		}
		final cantidad = double.tryParse(controller.text.trim().replaceAll(',', '.'));
		controller.dispose();
		if (cantidad == null) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Cantidad inválida'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final operador = ref.read(sesionUsuarioProvider);
			await servicio.registrarMovimientoInventario(
				productoId: reg.productoId,
				tipo: tipo,
				cantidad: cantidad,
				motivo: motivoSeleccionado,
				tiendaId: tiendaId,
				operador: operador,
			);
			ref.invalidate(inventarioAgrupadoProvider);
			await ref.read(inventarioAgrupadoProvider(tiendaId).future);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						tipo == TipoMovimientoInventario.ajuste
							? 'Existencia ajustada a ${cantidad.toStringAsFixed(1)}'
							: 'Movimiento registrado',
					),
				),
			);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}

class _KpiExistencia extends StatelessWidget {
	const _KpiExistencia({
		required this.etiqueta,
		required this.valor,
		required this.icono,
		required this.color,
	});

	final String etiqueta;
	final double valor;
	final IconData icono;
	final Color color;

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12.0),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(8.0),
				border: Border.all(color: color.withValues(alpha: 0.3)),
			),
			child: Row(
				children: [
					Icon(icono, color: color, size: 22.0),
					const SizedBox(width: 8.0),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
								Text(
									valor.toStringAsFixed(1),
									style: Theme.of(context).textTheme.titleMedium?.copyWith(
										fontWeight: FontWeight.bold,
										color: color,
									),
								),
							],
						),
					),
				],
			),
		);
	}
}

