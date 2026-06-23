/// Admin de precios: producto, alcance (generico/lista/cliente) y validacion de costo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaListasPreciosAdmin extends ConsumerStatefulWidget {
	const PantallaListasPreciosAdmin({super.key});

	@override
	ConsumerState<PantallaListasPreciosAdmin> createState() =>
		_PantallaListasPreciosAdminState();
}

class _PantallaListasPreciosAdminState extends ConsumerState<PantallaListasPreciosAdmin> {
	String? _productoId;
	AlcancePrecioVenta _alcance = AlcancePrecioVenta.generico;
	String? _listaPreciosId;
	String? _clienteId;
	final _precioController = TextEditingController();
	final _busquedaProductoController = TextEditingController();
	String _filtroProducto = '';

	@override
	void dispose() {
		_precioController.dispose();
		_busquedaProductoController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final catalogoAsync = ref.watch(_catalogoPreciosProvider);
		final resumenAsync = _productoId == null
			? const AsyncValue<ResumenPreciosProducto?>.data(null)
			: ref.watch(_resumenProductoProvider(_productoId!));

		if (_productoId != null) {
			ref.listen<AsyncValue<ResumenPreciosProducto?>>(
				_resumenProductoProvider(_productoId!),
				(previous, next) {
					if (next.hasValue && next.value != null) {
						_precargarPrecioSegunAlcance(next.value);
					}
				},
			);
		}

		return Scaffold(
			appBar: AppBar(
				title: const Text('Precios por producto'),
				actions: [
					IconButton(
						icon: const Icon(Icons.playlist_add),
						tooltip: 'Gestionar listas',
						onPressed: () => _mostrarGestionListas(context),
					),
				],
			),
			body: catalogoAsync.when(
				data: (catalogo) {
					final productosFiltrados = catalogo.productos.where((p) {
						if (_filtroProducto.isEmpty) {
							return true;
						}
						final q = _filtroProducto.toLowerCase();
						return p.nombre.toLowerCase().contains(q) ||
							p.codigoBarras.toLowerCase().contains(q);
					}).toList();
					return ListView(
						padding: const EdgeInsets.all(16.0),
						children: [
							const Text(
								'1. Seleccione el producto',
								style: TextStyle(fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							CampoBusqueda(
								controlador: _busquedaProductoController,
								sugerencia: 'Buscar producto...',
								alCambiar: (v) => setState(() => _filtroProducto = v.trim()),
							),
							const SizedBox(height: 8.0),
							DropdownButtonFormField<String>(
								value: productosFiltrados.any((p) => p.id == _productoId)
									? _productoId
									: null,
								isExpanded: true,
								decoration: const InputDecoration(
									labelText: 'Producto',
									border: OutlineInputBorder(),
								),
								items: productosFiltrados
									.map(
										(p) => DropdownMenuItem(
											value: p.id,
											child: Text(p.nombre),
										),
									)
									.toList(),
								onChanged: (v) {
									setState(() {
										_productoId = v;
										_precioController.clear();
									});
								},
							),
							if (resumenAsync.hasValue && resumenAsync.value != null) ...[
								const SizedBox(height: 12.0),
								_InfoCosto(resumen: resumenAsync.value!),
							],
							const Divider(height: 32.0),
							const Text(
								'2. A quien aplica el precio',
								style: TextStyle(fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							SegmentedButton<AlcancePrecioVenta>(
								segments: const [
									ButtonSegment(
										value: AlcancePrecioVenta.generico,
										label: Text('Generico'),
										icon: Icon(Icons.storefront),
									),
									ButtonSegment(
										value: AlcancePrecioVenta.listaPrecios,
										label: Text('Lista'),
										icon: Icon(Icons.sell),
									),
									ButtonSegment(
										value: AlcancePrecioVenta.clienteEspecifico,
										label: Text('Cliente'),
										icon: Icon(Icons.person),
									),
								],
								selected: {_alcance},
								onSelectionChanged: (s) {
									setState(() {
										_alcance = s.first;
										_precioController.clear();
									});
									_precargarPrecioSegunAlcance(resumenAsync.asData?.value);
								},
							),
							const SizedBox(height: 12.0),
							if (_alcance == AlcancePrecioVenta.listaPrecios)
								catalogo.listas.isEmpty
									? const Text(
										'Cree una lista comercial desde el icono superior.',
										style: TextStyle(color: Colors.grey),
									)
									: DropdownButtonFormField<String>(
									value: _listaPreciosId ?? catalogo.listas.first.id,
									isExpanded: true,
									decoration: const InputDecoration(
										labelText: 'Lista de precios',
										border: OutlineInputBorder(),
									),
									items: catalogo.listas
										.map(
											(l) => DropdownMenuItem(
												value: l.id,
												child: Text(l.nombre),
											),
										)
										.toList(),
									onChanged: (v) {
										setState(() {
											_listaPreciosId = v;
											_precioController.clear();
										});
										_precargarPrecioSegunAlcance(resumenAsync.asData?.value);
									},
								),
							if (_alcance == AlcancePrecioVenta.clienteEspecifico)
								catalogo.clientes.isEmpty
									? const Text(
										'Registre clientes para asignar precios especiales.',
										style: TextStyle(color: Colors.grey),
									)
									: DropdownButtonFormField<String>(
									value: _clienteId ?? catalogo.clientes.first.id,
									isExpanded: true,
									decoration: const InputDecoration(
										labelText: 'Cliente',
										border: OutlineInputBorder(),
									),
									items: catalogo.clientes
										.map(
											(c) => DropdownMenuItem(
												value: c.id,
												child: Text(c.nombre),
											),
										)
										.toList(),
									onChanged: (v) {
										setState(() {
											_clienteId = v;
											_precioController.clear();
										});
										_precargarPrecioSegunAlcance(resumenAsync.asData?.value);
									},
								),
							const SizedBox(height: 16.0),
							const Text(
								'3. Precio de venta',
								style: TextStyle(fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _precioController,
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								decoration: InputDecoration(
									labelText: 'Precio unitario (MXN)',
									border: const OutlineInputBorder(),
									helperText: resumenAsync.asData?.value == null
										? null
										: 'Minimo: ${formatearMoneda(resumenAsync.value!.precioMinimo)}',
								),
								onChanged: (_) => setState(() {}),
							),
							if (resumenAsync.hasValue && resumenAsync.value != null) ...[
								const SizedBox(height: 12.0),
								PanelCalculoUtilidad(
									costoUnitario: resumenAsync.value!.costoUnitario,
									precioController: _precioController,
									alCambiarPrecio: () => setState(() {}),
								),
							],
							const SizedBox(height: 16.0),
							FilledButton.icon(
								onPressed: _productoId == null ? null : () => _guardarPrecio(context),
								icon: const Icon(Icons.save),
								label: const Text('Guardar precio'),
							),
							if (resumenAsync.hasValue && resumenAsync.value != null) ...[
								const Divider(height: 32.0),
								const Text(
									'Precios configurados',
									style: TextStyle(fontWeight: FontWeight.bold),
								),
								const SizedBox(height: 8.0),
								_ResumenPreciosActuales(resumen: resumenAsync.value!),
							],
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	void _precargarPrecioSegunAlcance(ResumenPreciosProducto? resumen) {
		if (resumen == null) {
			return;
		}
		double? precio;
		switch (_alcance) {
			case AlcancePrecioVenta.generico:
				precio = resumen.precioGenerico;
			case AlcancePrecioVenta.listaPrecios:
				final listaId = _listaPreciosId ?? resumen.nombresListas.keys.firstOrNull;
				if (listaId != null) {
					precio = resumen.preciosPorLista[listaId];
				}
			case AlcancePrecioVenta.clienteEspecifico:
				final clienteId = _clienteId ?? resumen.nombresClientes.keys.firstOrNull;
				if (clienteId != null) {
					for (final p in resumen.preciosPorCliente) {
						if (p.clienteId == clienteId) {
							precio = p.precioUnitario;
							break;
						}
					}
				}
		}
		if (precio != null) {
			_precioController.text = precio.toStringAsFixed(2);
		}
	}

	Future<void> _guardarPrecio(BuildContext context) async {
		final precio = double.tryParse(_precioController.text.replaceAll(',', '.'));
		if (_productoId == null || precio == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Indique producto y precio valido')),
			);
			return;
		}
		if (_alcance == AlcancePrecioVenta.listaPrecios && _listaPreciosId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Seleccione una lista de precios')),
			);
			return;
		}
		if (_alcance == AlcancePrecioVenta.clienteEspecifico && _clienteId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Seleccione un cliente')),
			);
			return;
		}
		final listaId = _alcance == AlcancePrecioVenta.listaPrecios
			? (_listaPreciosId ?? ref.read(_catalogoPreciosProvider).value?.listas.firstOrNull?.id)
			: null;
		final clienteId = _alcance == AlcancePrecioVenta.clienteEspecifico
			? (_clienteId ?? ref.read(_catalogoPreciosProvider).value?.clientes.firstOrNull?.id)
			: null;
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.establecerPrecioProducto(
				productoId: _productoId!,
				precioUnitario: precio,
				alcance: _alcance,
				listaPreciosId: listaId,
				clienteId: clienteId,
			);
			ref.invalidate(_resumenProductoProvider(_productoId!));
			ref.invalidate(_catalogoPreciosProvider);
			if (!context.mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Precio guardado')),
			);
		} on StateError catch (e) {
			if (!context.mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _mostrarGestionListas(BuildContext context) async {
		await showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.55,
				maxChildSize: 0.85,
				builder: (context, scrollController) {
					return Consumer(
						builder: (context, ref, _) {
							final listasAsync = ref.watch(_listasProvider);
							return Padding(
								padding: const EdgeInsets.all(16.0),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(
											children: [
												const Expanded(
													child: Text(
														'Listas comerciales',
														style: TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: 18.0,
														),
													),
												),
												IconButton(
													icon: const Icon(Icons.add),
													onPressed: () => _crearLista(ctx, ref),
												),
											],
										),
										const SizedBox(height: 8.0),
										Expanded(
											child: listasAsync.when(
												data: (listas) => listas.isEmpty
													? const Center(
														child: Text(
															'Sin listas. Cree una para asignarla a clientes.',
														),
													)
													: ListView.builder(
														controller: scrollController,
														itemCount: listas.length,
														itemBuilder: (context, i) {
															final lista = listas[i];
															return ListTile(
																leading: const Icon(Icons.sell),
																title: Text(lista.nombre),
																subtitle: Text(
																	lista.activa ? 'Activa' : 'Inactiva',
																),
																trailing: IconButton(
																	icon: const Icon(Icons.delete_outline),
																	onPressed: () => _eliminarLista(ctx, ref, lista),
																),
															);
														},
													),
												loading: () =>
													const Center(child: CircularProgressIndicator()),
												error: (e, _) => Center(child: Text('$e')),
											),
										),
									],
								),
							);
						},
					);
				},
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
		ref.invalidate(_catalogoPreciosProvider);
	}

	Future<void> _eliminarLista(
		BuildContext context,
		WidgetRef ref,
		ListaPrecios lista,
	) async {
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
		ref.invalidate(_catalogoPreciosProvider);
		if (_listaPreciosId == lista.id) {
			setState(() => _listaPreciosId = null);
		}
	}
}

class _InfoCosto extends StatelessWidget {
	const _InfoCosto({required this.resumen});

	final ResumenPreciosProducto resumen;

	@override
	Widget build(BuildContext context) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text('Costo: ${formatearMoneda(resumen.costoUnitario)}'),
						Text('Precio generico actual: ${formatearMoneda(resumen.precioGenerico)}'),
						Text(
							'Precio minimo permitido: ${formatearMoneda(resumen.precioMinimo)}',
							style: const TextStyle(fontWeight: FontWeight.w600),
						),
					],
				),
			),
		);
	}
}

class _ResumenPreciosActuales extends StatelessWidget {
	const _ResumenPreciosActuales({required this.resumen});

	final ResumenPreciosProducto resumen;

	@override
	Widget build(BuildContext context) {
		final filas = <Widget>[
			ListTile(
				dense: true,
				leading: const Icon(Icons.storefront),
				title: const Text('Precio generico'),
				trailing: Text(formatearMoneda(resumen.precioGenerico)),
			),
		];
		for (final entry in resumen.preciosPorLista.entries) {
			final nombre = resumen.nombresListas[entry.key] ?? entry.key;
			filas.add(
				ListTile(
					dense: true,
					leading: const Icon(Icons.sell),
					title: Text('Lista: $nombre'),
					trailing: Text(formatearMoneda(entry.value)),
				),
			);
		}
		for (final precio in resumen.preciosPorCliente) {
			final nombre = resumen.nombresClientes[precio.clienteId] ?? precio.clienteId;
			filas.add(
				ListTile(
					dense: true,
					leading: const Icon(Icons.person),
					title: Text('Cliente: $nombre'),
					trailing: Text(formatearMoneda(precio.precioUnitario)),
				),
			);
		}
		if (filas.length == 1 &&
			resumen.preciosPorLista.isEmpty &&
			resumen.preciosPorCliente.isEmpty) {
			return const Text('Solo precio generico configurado');
		}
		return Column(children: filas);
	}
}

class _CatalogoPrecios {
	const _CatalogoPrecios({
		required this.productos,
		required this.listas,
		required this.clientes,
	});

	final List<Producto> productos;
	final List<ListaPrecios> listas;
	final List<Cliente> clientes;
}

final _catalogoPreciosProvider = FutureProvider<_CatalogoPrecios>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final productos = await servicio.listarProductos();
	final listas = await servicio.listarListasPrecios();
	final clientes = await servicio.listarClientes();
	return _CatalogoPrecios(
		productos: productos.where((p) => p.activo).toList(),
		listas: listas.where((l) => l.activa).toList(),
		clientes: clientes.where((c) => c.activo).toList(),
	);
});

final _resumenProductoProvider =
	FutureProvider.family<ResumenPreciosProducto?, String>((ref, productoId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		return servicio.obtenerResumenPreciosProducto(productoId);
	});

final _listasProvider = FutureProvider<List<ListaPrecios>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarListasPrecios();
});
