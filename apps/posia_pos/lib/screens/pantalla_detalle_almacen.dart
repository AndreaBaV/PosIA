/// Detalle de existencias en un almacén con ajustes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/inventario_admin_providers.dart';

class PantallaDetalleAlmacen extends ConsumerStatefulWidget {
	const PantallaDetalleAlmacen({
		required this.almacenId,
		required this.nombreAlmacen,
		super.key,
	});

	final String almacenId;
	final String nombreAlmacen;

	@override
	ConsumerState<PantallaDetalleAlmacen> createState() => _PantallaDetalleAlmacenState();
}

class _PantallaDetalleAlmacenState extends ConsumerState<PantallaDetalleAlmacen> {
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final inventarioAsync = ref.watch(inventarioAlmacenProvider(widget.almacenId));
		return Scaffold(
			appBar: AppBar(title: Text(widget.nombreAlmacen)),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: _registrarEntrada,
				icon: const Icon(Icons.add),
				label: const Text('Entrada'),
			),
			body: Column(
				children: [
					CampoBusqueda(
						controlador: _busquedaController,
						sugerencia: 'Buscar producto...',
						alCambiar: (v) => setState(() => _filtro = v.trim().toLowerCase()),
					),
					Expanded(
						child: inventarioAsync.when(
							data: (lineas) {
								final filtradas = lineas.where((l) {
									if (_filtro.isEmpty) {
										return true;
									}
									return l.nombreProducto.toLowerCase().contains(_filtro);
								}).toList();
								final totalUnidades = filtradas.fold<double>(
									0.0,
									(s, l) => s + l.cantidad,
								);
								if (filtradas.isEmpty) {
									return const Center(
										child: Padding(
											padding: EdgeInsets.all(24.0),
											child: Text(
												'Sin existencias registradas.\n'
												'Use "Entrada" para cargar productos.',
												textAlign: TextAlign.center,
											),
										),
									);
								}
								return Column(
									children: [
										Padding(
											padding: const EdgeInsets.symmetric(
												horizontal: 16.0,
												vertical: 8.0,
											),
											child: Row(
												children: [
													Chip(
														avatar: const Icon(Icons.inventory_2, size: 18.0),
														label: Text('${filtradas.length} productos'),
													),
													const SizedBox(width: 8.0),
													Chip(
														avatar: const Icon(Icons.scale, size: 18.0),
														label: Text('${totalUnidades.toStringAsFixed(1)} u.'),
													),
												],
											),
										),
										Expanded(
											child: ListView.builder(
												padding: const EdgeInsets.only(bottom: 88.0),
												itemCount: filtradas.length,
												itemBuilder: (_, i) {
													final linea = filtradas[i];
													return Card(
														margin: const EdgeInsets.symmetric(
															horizontal: 12.0,
															vertical: 4.0,
														),
														child: ListTile(
															title: Text(linea.nombreProducto),
															subtitle: Text(
																'Actualizado: ${linea.actualizadoEn.toLocal().toString().substring(0, 16)}',
															),
															trailing: Text(
																linea.cantidad.toStringAsFixed(1),
																style: const TextStyle(
																	fontWeight: FontWeight.bold,
																	fontSize: 16.0,
																),
															),
															onTap: () => _ajustar(linea, TipoMovimientoInventario.ajuste),
															onLongPress: () => _mostrarAcciones(linea),
														),
													);
												},
											),
										),
									],
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

	Future<void> _mostrarAcciones(StockPorAlmacen linea) async {
		await showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			builder: (ctx) => SafeArea(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ListTile(
							title: Text(linea.nombreProducto),
							subtitle: Text('${linea.cantidad.toStringAsFixed(1)} en almacén'),
						),
						ListTile(
							leading: const Icon(Icons.add),
							title: const Text('Entrada'),
							onTap: () {
								Navigator.pop(ctx);
								_ajustar(linea, TipoMovimientoInventario.entrada);
							},
						),
						ListTile(
							leading: const Icon(Icons.remove),
							title: const Text('Salida'),
							onTap: () {
								Navigator.pop(ctx);
								_ajustar(linea, TipoMovimientoInventario.salida);
							},
						),
						ListTile(
							leading: const Icon(Icons.tune),
							title: const Text('Ajustar cantidad'),
							onTap: () {
								Navigator.pop(ctx);
								_ajustar(linea, TipoMovimientoInventario.ajuste);
							},
						),
					],
				),
			),
		);
	}

	Future<void> _ajustar(StockPorAlmacen linea, TipoMovimientoInventario tipo) async {
		final controller = TextEditingController(
			text: tipo == TipoMovimientoInventario.ajuste
				? linea.cantidad.toStringAsFixed(1)
				: '1',
		);
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text('${etiquetaTipoMovimiento(tipo)}: ${linea.nombreProducto}'),
				content: TextField(
					controller: controller,
					keyboardType: const TextInputType.numberWithOptions(decimal: true),
					decoration: InputDecoration(
						labelText: tipo == TipoMovimientoInventario.ajuste
							? 'Cantidad final'
							: 'Cantidad',
					),
					autofocus: true,
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
				],
			),
		);
		if (confirmar != true) {
			controller.dispose();
			return;
		}
		final cantidad = double.tryParse(controller.text.trim().replaceAll(',', '.'));
		controller.dispose();
		if (cantidad == null || cantidad < 0) {
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
			await servicio.ajustarStockAlmacen(
				productoId: linea.productoId,
				almacenId: widget.almacenId,
				tipo: tipo,
				cantidad: cantidad,
			);
			ref.invalidate(inventarioAlmacenProvider(widget.almacenId));
			ref.invalidate(resumenAlmacenesProvider);
			ref.invalidate(inventarioAgrupadoProvider);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Existencia actualizada')),
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

	Future<void> _registrarEntrada() async {
		if (!mounted) {
			return;
		}
		final messenger = ScaffoldMessenger.of(context);
		final productos = await ref.read(productosAlmacenProvider.future);
		if (!mounted) {
			return;
		}
		final producto = await showDialog<Producto>(
			context: context,
			builder: (ctx) {
				var filtro = '';
				return StatefulBuilder(
					builder: (ctx, setDialog) {
						final filtrados = productos.where((p) {
							if (filtro.isEmpty) {
								return true;
							}
							final f = filtro.toLowerCase();
							return p.nombre.toLowerCase().contains(f) ||
								p.codigoBarras.contains(f);
						}).take(30).toList();
						return AlertDialog(
							title: const Text('Producto a ingresar'),
							content: SizedBox(
								width: double.maxFinite,
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										TextField(
											decoration: const InputDecoration(
												labelText: 'Buscar',
												border: OutlineInputBorder(),
												prefixIcon: Icon(Icons.search),
											),
											onChanged: (v) => setDialog(() => filtro = v.trim()),
										),
										const SizedBox(height: 8.0),
										Flexible(
											child: ListView.builder(
												shrinkWrap: true,
												itemCount: filtrados.length,
												itemBuilder: (_, i) {
													final p = filtrados[i];
													return ListTile(
														title: Text(p.nombre),
														subtitle: Text(formatearMoneda(p.precioBase)),
														onTap: () => Navigator.pop(ctx, p),
													);
												},
											),
										),
									],
								),
							),
							actions: [
								TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
							],
						);
					},
				);
			},
		);
		if (producto == null || !mounted) {
			return;
		}
		final controller = TextEditingController(text: '1');
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text('Entrada: ${producto.nombre}'),
				content: TextField(
					controller: controller,
					keyboardType: const TextInputType.numberWithOptions(decimal: true),
					decoration: const InputDecoration(labelText: 'Cantidad'),
					autofocus: true,
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
				],
			),
		);
		if (confirmar != true) {
			controller.dispose();
			return;
		}
		final cantidad = double.tryParse(controller.text.trim().replaceAll(',', '.'));
		controller.dispose();
		if (cantidad == null || cantidad <= 0) {
			messenger.showSnackBar(
				const SnackBar(
					content: Text('Cantidad inválida'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.ajustarStockAlmacen(
				productoId: producto.id,
				almacenId: widget.almacenId,
				tipo: TipoMovimientoInventario.entrada,
				cantidad: cantidad,
			);
			ref.invalidate(inventarioAlmacenProvider(widget.almacenId));
			ref.invalidate(resumenAlmacenesProvider);
			ref.invalidate(inventarioAgrupadoProvider);
			if (!mounted) {
				return;
			}
			messenger.showSnackBar(
				SnackBar(content: Text('Entrada registrada: ${cantidad.toStringAsFixed(1)} u.')),
			);
		} on StateError catch (e) {
			messenger.showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}
