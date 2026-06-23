/// Pantalla de inventario agrupado por producto con ajustes rapidos.

library;



import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:posia_core/posia_core.dart';

import 'package:posia_database/posia_database.dart';

import 'package:posia_ui/posia_ui.dart';



import '../providers/admin_providers.dart';
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

		final inventarioAsync = ref.watch(_inventarioAgrupadoProvider(_tiendaOperacionId));

		final tiendasAsync = ref.watch(_tiendasInventarioProvider);

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

							_tiendaOperacionId ??= seleccionada;

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

						error: (_, __) => const SizedBox.shrink(),

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

								final tiendaId = _tiendaOperacionId ?? datos.tiendaReferenciaId;

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

								return ListView.builder(

									itemCount: filtrados.length,

									itemBuilder: (_, i) {

										final reg = filtrados[i];

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

													'$nombreTienda: ${cantidadTienda.toStringAsFixed(0)} · '

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
				? cantidadActual.toStringAsFixed(0)
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
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final operador = ref.read(sesionUsuarioProvider);
			await servicio.registrarMovimientoInventario(
				productoId: reg.productoId,
				tipo: tipo,
				cantidad: double.tryParse(controller.text) ?? 0.0,
				motivo: motivoSeleccionado,
				tiendaId: tiendaId,
				operador: operador,
			);
			ref.invalidate(_inventarioAgrupadoProvider(_tiendaOperacionId));
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
		}
	}
}



class _DatosInventarioAgrupado {

	const _DatosInventarioAgrupado({

		required this.registros,

		required this.tiendaReferenciaId,

		required this.nombresTienda,

	});



	final List<InventarioAgrupado> registros;

	final String tiendaReferenciaId;

	final Map<String, String> nombresTienda;

}



final _tiendasInventarioProvider = FutureProvider<List<Tienda>>((ref) async {

	final servicio = await ref.watch(servicioAdminProvider.future);

	final operador = ref.watch(sesionUsuarioProvider);

	return servicio.obtenerTiendasPermitidas(operador: operador);

});



final _inventarioAgrupadoProvider = FutureProvider.family<_DatosInventarioAgrupado, String?>(

	(ref, tiendaReferenciaId) async {

		final servicio = await ref.watch(servicioAdminProvider.future);

		final tiendas = await servicio.obtenerTiendasPermitidas(

			operador: ref.watch(sesionUsuarioProvider),

		);

		final referencia = tiendaReferenciaId ?? tiendas.firstOrNull?.id ?? servicio.tiendaActivaId;

		final registros = await servicio.obtenerInventarioAgrupado(tiendaReferenciaId: referencia);

		return _DatosInventarioAgrupado(

			registros: registros,

			tiendaReferenciaId: referencia,

			nombresTienda: {for (final t in tiendas) t.id: t.nombre},

		);

	},

);


