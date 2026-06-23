/// Entradas, salidas y ajustes de inventario.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaMovimientosInventario extends ConsumerStatefulWidget {
	const PantallaMovimientosInventario({super.key});

	@override
	ConsumerState<PantallaMovimientosInventario> createState() =>
		_PantallaMovimientosInventarioState();
}

class _PantallaMovimientosInventarioState
	extends ConsumerState<PantallaMovimientosInventario> {
	TipoMovimientoInventario _tipo = TipoMovimientoInventario.salida;
	String? _productoId;
	final _cantidadController = TextEditingController(text: '10');
	final _busquedaController = TextEditingController();
	String _filtro = '';
	bool _formularioExpandido = false;
	String? _tiendaOperacionId;
	String _motivoSeleccionado = motivoInventarioPredeterminado(TipoMovimientoInventario.salida);

	@override
	void dispose() {
		_cantidadController.dispose();
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(_movimientosDatosProvider(_tiendaOperacionId));
		return Scaffold(
			appBar: AppBar(title: const Text('Salidas y ajustes')),
			body: datosAsync.when(
				data: (datos) {
					final filtrados = datos.movimientos.where((m) {
						if (_filtro.isEmpty) {
							return true;
						}
						final nombre = datos.nombresProducto[m.productoId] ?? '';
						return nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
							m.motivo.toLowerCase().contains(_filtro.toLowerCase());
					}).toList();
					return Column(
						children: [
							if (datos.tiendas.length > 1)
								Padding(
									padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
									child: DropdownButtonFormField<String>(
										initialValue: datos.tiendaId,
										decoration: const InputDecoration(
											labelText: 'Tienda',
											border: OutlineInputBorder(),
										),
										items: datos.tiendas
											.map(
												(t) => DropdownMenuItem(
													value: t.id,
													child: Text(t.nombre),
												),
											)
											.toList(),
										onChanged: (v) => setState(() => _tiendaOperacionId = v),
									),
								),
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar movimiento...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							Expanded(
								child: filtrados.isEmpty
									? const Center(child: Text('Sin movimientos'))
									: ListView.builder(
										itemCount: filtrados.length,
										itemBuilder: (_, i) {
											final m = filtrados[i];
											final nombre = datos.nombresProducto[m.productoId] ?? m.productoId;
											return ListTile(
												leading: Icon(_iconoTipo(m.tipo)),
												title: Text('$nombre · ${etiquetaTipoMovimiento(m.tipo)}'),
												subtitle: Text(
													'${m.cantidadAnterior.toStringAsFixed(0)} → '
													'${m.cantidadNueva.toStringAsFixed(0)} · ${m.motivo}',
												),
												trailing: Text(
													m.creadoEn.toLocal().toString().substring(0, 16),
													style: const TextStyle(fontSize: 11.0),
												),
											);
										},
									),
							),
							ExpansionTile(
								title: const Text('Registrar movimiento'),
								initiallyExpanded: _formularioExpandido,
								onExpansionChanged: (v) => setState(() => _formularioExpandido = v),
								children: [
									Padding(
										padding: const EdgeInsets.all(12.0),
										child: Column(
											children: [
												DropdownButtonFormField<TipoMovimientoInventario>(
													initialValue: _tipo,
													items: const [
														TipoMovimientoInventario.salida,
														TipoMovimientoInventario.ajuste,
													]
														.map(
															(t) => DropdownMenuItem(
																value: t,
																child: Text(etiquetaTipoMovimiento(t)),
															),
														)
														.toList(),
													onChanged: (v) => setState(() {
														_tipo = v!;
														_motivoSeleccionado = motivoInventarioPredeterminado(_tipo);
													}),
													decoration: const InputDecoration(labelText: 'Tipo'),
												),
												DropdownButtonFormField<String>(
													initialValue: _productoId ?? datos.productos.firstOrNull?.id,
													items: datos.productos
														.map(
															(p) => DropdownMenuItem(
																value: p.id,
																child: Text(p.nombre),
															),
														)
														.toList(),
													onChanged: (v) => setState(() => _productoId = v),
													decoration: const InputDecoration(labelText: 'Producto'),
												),
												TextField(
													controller: _cantidadController,
													keyboardType: TextInputType.number,
													decoration: InputDecoration(
														labelText: _tipo == TipoMovimientoInventario.ajuste
															? 'Cantidad final deseada'
															: 'Cantidad',
													),
												),
												SelectorMotivoInventario(
													tipo: _tipo,
													valor: _motivoSeleccionado,
													alCambiar: (motivo) => setState(() => _motivoSeleccionado = motivo),
												),
												FilledButton(
													onPressed: _registrar,
													child: const Text('Registrar movimiento'),
												),
											],
										),
									),
								],
							),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	IconData _iconoTipo(TipoMovimientoInventario tipo) {
		switch (tipo) {
			case TipoMovimientoInventario.entrada:
			case TipoMovimientoInventario.traspasoEntrada:
				return Icons.arrow_downward;
			case TipoMovimientoInventario.salida:
			case TipoMovimientoInventario.traspasoSalida:
				return Icons.arrow_upward;
			default:
				return Icons.tune;
		}
	}

	Future<void> _registrar() async {
		final productoId = _productoId;
		if (productoId == null) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final operador = ref.read(sesionUsuarioProvider);
			await servicio.registrarMovimientoInventario(
				productoId: productoId,
				tipo: _tipo,
				cantidad: double.tryParse(_cantidadController.text) ?? 0.0,
				motivo: _motivoSeleccionado,
				tiendaId: _tiendaOperacionId,
				operador: operador,
			);
			ref.invalidate(_movimientosDatosProvider(_tiendaOperacionId));
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
		}
	}
}

class _DatosMovimientos {
	const _DatosMovimientos({
		required this.movimientos,
		required this.productos,
		required this.nombresProducto,
		required this.tiendas,
		required this.tiendaId,
	});

	final List<MovimientoInventario> movimientos;
	final List<Producto> productos;
	final Map<String, String> nombresProducto;
	final List<Tienda> tiendas;
	final String tiendaId;
}

final _movimientosDatosProvider = FutureProvider.family<_DatosMovimientos, String?>(
	(ref, tiendaOperacionId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final operador = ref.watch(sesionUsuarioProvider);
		final tiendas = await servicio.obtenerTiendasPermitidas(operador: operador);
		final tiendaId = tiendaOperacionId ?? operador?.tiendaId ?? servicio.tiendaActivaId;
		final movimientos = await servicio.listarMovimientosInventario(
			tiendaId: tiendaId,
			operador: operador,
		);
		final productos = await servicio.listarProductos();
		final nombres = {for (final p in productos) p.id: p.nombre};
		return _DatosMovimientos(
			movimientos: movimientos,
			productos: productos,
			nombresProducto: nombres,
			tiendas: tiendas,
			tiendaId: tiendaId,
		);
	},
);
