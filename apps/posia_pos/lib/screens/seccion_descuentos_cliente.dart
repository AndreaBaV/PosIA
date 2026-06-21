/// Seccion de descuentos y precios especiales del cliente.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class SeccionDescuentosCliente extends ConsumerStatefulWidget {
	const SeccionDescuentosCliente({required this.clienteId, super.key});

	final String clienteId;

	@override
	ConsumerState<SeccionDescuentosCliente> createState() =>
		_SeccionDescuentosClienteState();
}

class _SeccionDescuentosClienteState extends ConsumerState<SeccionDescuentosCliente> {
	@override
	Widget build(BuildContext context) {
		final descuentosAsync = ref.watch(_descuentosClienteProvider(widget.clienteId));
		final preciosAsync = ref.watch(_preciosEspecialesClienteProvider(widget.clienteId));
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				const Text(
					'Descuentos y reglas',
					style: TextStyle(fontWeight: FontWeight.bold),
				),
				const SizedBox(height: 8.0),
				descuentosAsync.when(
					data: (descuentos) {
						if (descuentos.reglas.isEmpty) {
							return const Text('Sin descuentos configurados');
						}
						return Column(
							children: descuentos.reglas.map((d) {
								return Card(
									child: ListTile(
										title: Text(
											resumenDescuentoCliente(
												d,
												nombreProducto: descuentos.nombresProducto[d.productoId],
											),
										),
										subtitle: d.descripcion.isNotEmpty ? Text(d.descripcion) : null,
										trailing: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												Switch(
													value: d.activo,
													onChanged: (activo) => _cambiarActivo(d, activo),
												),
												IconButton(
													icon: const Icon(Icons.delete_outline),
													onPressed: () => _eliminarDescuento(d.id),
												),
											],
										),
									),
								);
							}).toList(),
						);
					},
					loading: () => const LinearProgressIndicator(),
					error: (e, _) => Text('$e'),
				),
				const SizedBox(height: 8.0),
				FilledButton.tonalIcon(
					onPressed: () => _mostrarDialogoDescuento(),
					icon: const Icon(Icons.add),
					label: const Text('Agregar descuento'),
				),
				const Divider(height: 32.0),
				const Text(
					'Precios especiales por producto',
					style: TextStyle(fontWeight: FontWeight.bold),
				),
				const SizedBox(height: 8.0),
				preciosAsync.when(
					data: (datos) {
						if (datos.precios.isEmpty) {
							return const Text('Sin precios especiales');
						}
						return Column(
							children: datos.precios.map((p) {
								final nombre = datos.nombresProducto[p.productoId] ?? p.productoId;
								return Card(
									child: ListTile(
										title: Text(nombre),
										subtitle: Text(formatearMoneda(p.precioUnitario)),
										trailing: IconButton(
											icon: const Icon(Icons.delete_outline),
											onPressed: () => _eliminarPrecioEspecial(p.productoId),
										),
									),
								);
							}).toList(),
						);
					},
					loading: () => const LinearProgressIndicator(),
					error: (e, _) => Text('$e'),
				),
				const SizedBox(height: 8.0),
				FilledButton.tonalIcon(
					onPressed: () => _mostrarDialogoPrecioEspecial(),
					icon: const Icon(Icons.sell),
					label: const Text('Agregar precio especial'),
				),
			],
		);
	}

	Future<void> _cambiarActivo(DescuentoCliente descuento, bool activo) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarDescuentoCliente(descuento.copiarCon(activo: activo));
		ref.invalidate(_descuentosClienteProvider(widget.clienteId));
	}

	Future<void> _eliminarDescuento(String id) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.eliminarDescuentoCliente(id);
		ref.invalidate(_descuentosClienteProvider(widget.clienteId));
	}

	Future<void> _eliminarPrecioEspecial(String productoId) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.eliminarPrecioEspecialCliente(widget.clienteId, productoId);
		ref.invalidate(_preciosEspecialesClienteProvider(widget.clienteId));
	}

	Future<void> _mostrarDialogoDescuento() async {
		final productos = await ref.read(_productosDescuentoProvider.future);
		var tipo = TipoDescuentoCliente.porcentajeGeneral;
		var condicion = CondicionDescuentoCliente.siempre;
		final valorController = TextEditingController(text: '10');
		final umbralController = TextEditingController();
		final descripcionController = TextEditingController();
		String? productoId = productos.firstOrNull?.id;
		if (!mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setLocal) => AlertDialog(
					title: const Text('Nuevo descuento'),
					content: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								DropdownButtonFormField<TipoDescuentoCliente>(
									initialValue: tipo,
									items: TipoDescuentoCliente.values
										.map(
											(t) => DropdownMenuItem(
												value: t,
												child: Text(etiquetaTipoDescuentoCliente(t)),
											),
										)
										.toList(),
									onChanged: (v) => setLocal(() {
										tipo = v!;
										if (tipo.esGeneral) {
											productoId = null;
										}
									}),
									decoration: const InputDecoration(labelText: 'Tipo'),
								),
								TextField(
									controller: valorController,
									keyboardType: TextInputType.number,
									decoration: InputDecoration(
										labelText: tipo == TipoDescuentoCliente.porcentajeGeneral ||
											tipo == TipoDescuentoCliente.porcentajeProducto
											? 'Porcentaje'
											: 'Monto (MXN)',
									),
								),
								if (tipo.esPorProducto)
									DropdownButtonFormField<String>(
										initialValue: productoId,
										items: productos
											.map(
												(p) => DropdownMenuItem(
													value: p.id,
													child: Text(p.nombre),
												),
											)
											.toList(),
										onChanged: (v) => setLocal(() => productoId = v),
										decoration: const InputDecoration(labelText: 'Producto'),
									),
								DropdownButtonFormField<CondicionDescuentoCliente>(
									initialValue: condicion,
									items: CondicionDescuentoCliente.values
										.where((c) {
											if (tipo.esGeneral) {
												return c != CondicionDescuentoCliente.cantidadMinima;
											}
											return c != CondicionDescuentoCliente.montoTicketMinimo;
										})
										.map(
											(c) => DropdownMenuItem(
												value: c,
												child: Text(etiquetaCondicionDescuentoCliente(c)),
											),
										)
										.toList(),
									onChanged: (v) => setLocal(() => condicion = v!),
									decoration: const InputDecoration(labelText: 'Condición'),
								),
								if (condicion != CondicionDescuentoCliente.siempre)
									TextField(
										controller: umbralController,
										keyboardType: TextInputType.number,
										decoration: InputDecoration(
											labelText: condicion == CondicionDescuentoCliente.montoTicketMinimo
												? 'Monto mínimo del ticket'
												: 'Cantidad mínima',
										),
									),
								TextField(
									controller: descripcionController,
									decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
								),
							],
						),
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
						FilledButton(
							onPressed: () async {
								try {
									final servicio = await ref.read(servicioAdminProvider.future);
									await servicio.registrarDescuentoCliente(
										clienteId: widget.clienteId,
										tipo: tipo,
										valor: double.tryParse(valorController.text) ?? 0.0,
										condicion: condicion,
										productoId: productoId,
										umbral: condicion == CondicionDescuentoCliente.siempre
											? null
											: double.tryParse(umbralController.text),
										descripcion: descripcionController.text,
									);
									ref.invalidate(_descuentosClienteProvider(widget.clienteId));
									if (ctx.mounted) {
										Navigator.pop(ctx);
									}
								} on StateError catch (e) {
									if (ctx.mounted) {
										ScaffoldMessenger.of(ctx).showSnackBar(
											SnackBar(
												content: Text(e.message),
												backgroundColor: PosiaColors.cancelar,
											),
										);
									}
								}
							},
							child: const Text('Guardar'),
						),
					],
				),
			),
		);
		valorController.dispose();
		umbralController.dispose();
		descripcionController.dispose();
	}

	Future<void> _mostrarDialogoPrecioEspecial() async {
		final productos = await ref.read(_productosDescuentoProvider.future);
		final precioController = TextEditingController();
		String? productoId = productos.firstOrNull?.id;
		if (!mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setLocal) => AlertDialog(
					title: const Text('Precio especial'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							DropdownButtonFormField<String>(
								initialValue: productoId,
								items: productos
									.map(
										(p) => DropdownMenuItem(
											value: p.id,
											child: Text(p.nombre),
										),
									)
									.toList(),
								onChanged: (v) => setLocal(() => productoId = v),
								decoration: const InputDecoration(labelText: 'Producto'),
							),
							TextField(
								controller: precioController,
								keyboardType: TextInputType.number,
								decoration: const InputDecoration(labelText: 'Precio unitario'),
							),
						],
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
						FilledButton(
							onPressed: () async {
								if (productoId == null) {
									return;
								}
								try {
									final servicio = await ref.read(servicioAdminProvider.future);
									await servicio.guardarPrecioEspecialCliente(
										clienteId: widget.clienteId,
										productoId: productoId!,
										precioUnitario: double.tryParse(precioController.text) ?? 0.0,
									);
									ref.invalidate(_preciosEspecialesClienteProvider(widget.clienteId));
									if (ctx.mounted) {
										Navigator.pop(ctx);
									}
								} on StateError catch (e) {
									if (ctx.mounted) {
										ScaffoldMessenger.of(ctx).showSnackBar(
											SnackBar(
												content: Text(e.message),
												backgroundColor: PosiaColors.cancelar,
											),
										);
									}
								}
							},
							child: const Text('Guardar'),
						),
					],
				),
			),
		);
		precioController.dispose();
	}
}

class _DatosDescuentosCliente {
	const _DatosDescuentosCliente({
		required this.reglas,
		required this.nombresProducto,
	});

	final List<DescuentoCliente> reglas;
	final Map<String, String> nombresProducto;
}

class _DatosPreciosEspeciales {
	const _DatosPreciosEspeciales({
		required this.precios,
		required this.nombresProducto,
	});

	final List<PrecioClienteProducto> precios;
	final Map<String, String> nombresProducto;
}

final _descuentosClienteProvider =
	FutureProvider.family<_DatosDescuentosCliente, String>((ref, clienteId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final reglas = await servicio.listarDescuentosCliente(clienteId);
		final productos = await servicio.listarProductos();
		return _DatosDescuentosCliente(
			reglas: reglas,
			nombresProducto: {for (final p in productos) p.id: p.nombre},
		);
	});

final _preciosEspecialesClienteProvider =
	FutureProvider.family<_DatosPreciosEspeciales, String>((ref, clienteId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final precios = await servicio.listarPreciosEspecialesCliente(clienteId);
		final productos = await servicio.listarProductos();
		return _DatosPreciosEspeciales(
			precios: precios,
			nombresProducto: {for (final p in productos) p.id: p.nombre},
		);
	});

final _productosDescuentoProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductos();
});
