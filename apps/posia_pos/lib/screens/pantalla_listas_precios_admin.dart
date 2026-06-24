/// Admin de listas de precios: seleccionar lista y gestionar sus productos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import 'pantalla_formulario_producto.dart';

class PantallaListasPreciosAdmin extends ConsumerStatefulWidget {
	const PantallaListasPreciosAdmin({super.key});

	@override
	ConsumerState<PantallaListasPreciosAdmin> createState() =>
		_PantallaListasPreciosAdminState();
}

class _PantallaListasPreciosAdminState extends ConsumerState<PantallaListasPreciosAdmin> {
	String? _listaId;
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final listasAsync = ref.watch(_listasProvider);

		return Scaffold(
			appBar: AppBar(title: const Text('Listas de precios')),
			body: listasAsync.when(
				data: (listas) {
					final listaId = _listaId ?? (listas.isNotEmpty ? listas.first.id : null);
					return _contenido(context, listas, listaId);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
			floatingActionButton: listasAsync.maybeWhen(
				data: (listas) {
					final listaId = _listaId ?? (listas.isNotEmpty ? listas.first.id : null);
					if (listaId == null) {
						return null;
					}
					return FloatingActionButton.extended(
						onPressed: () => _agregarProducto(context, listaId),
						icon: const Icon(Icons.add),
						label: const Text('Agregar producto'),
					);
				},
				orElse: () => null,
			),
		);
	}

	Widget _contenido(BuildContext context, List<ListaPrecios> listas, String? listaId) {
		final detalleAsync = listaId == null
			? const AsyncValue<_DetalleLista?>.data(null)
			: ref.watch(_detalleListaProvider(listaId));

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Padding(
					padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 8.0),
					child: Row(
						children: [
							Expanded(
								child: listas.isEmpty
									? const Text('Sin listas. Cree una para comenzar.')
									: DropdownButtonFormField<String>(
										initialValue: listaId,
										isExpanded: true,
										decoration: const InputDecoration(
											labelText: 'Lista de precios',
											border: OutlineInputBorder(),
											isDense: true,
										),
										items: listas
											.map(
												(l) => DropdownMenuItem(
													value: l.id,
													child: Text(l.nombre),
												),
											)
											.toList(),
										onChanged: (v) => setState(() {
											_listaId = v;
											_filtro = '';
											_busquedaController.clear();
										}),
									),
							),
							IconButton(
								tooltip: 'Nueva lista',
								icon: const Icon(Icons.add),
								onPressed: () => _crearLista(context),
							),
							if (listaId != null)
								IconButton(
									tooltip: 'Eliminar lista',
									icon: const Icon(Icons.delete_outline),
									onPressed: () {
										final lista = listas.firstWhere((l) => l.id == listaId);
										_eliminarLista(context, lista);
									},
								),
						],
					),
				),
				if (listaId == null)
					const Expanded(
						child: Center(
							child: Text(
								'Seleccione o cree una lista de precios.',
								style: TextStyle(color: Colors.grey),
							),
						),
					)
				else
					Expanded(
						child: detalleAsync.when(
							data: (detalle) {
								if (detalle == null) {
									return const SizedBox.shrink();
								}
								return _vistaLista(context, detalle, listaId);
							},
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(child: Text('$e')),
						),
					),
			],
		);
	}

	Widget _vistaLista(BuildContext context, _DetalleLista detalle, String listaId) {
		final filtrados = detalle.items.where((item) {
			if (_filtro.isEmpty) {
				return true;
			}
			final q = _filtro.toLowerCase();
			return item.producto.nombre.toLowerCase().contains(q) ||
				item.producto.codigoBarras.toLowerCase().contains(q);
		}).toList();

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								'Clientes con esta lista',
								style: Theme.of(context).textTheme.titleSmall,
							),
							const SizedBox(height: 6.0),
							if (detalle.clientes.isEmpty)
								Text(
									'Ningun cliente asignado. Asigne la lista en la ficha del cliente.',
									style: Theme.of(context).textTheme.bodySmall?.copyWith(
										color: Colors.grey.shade700,
									),
								)
							else
								Wrap(
									spacing: 6.0,
									runSpacing: 4.0,
									children: detalle.clientes
										.map(
											(c) => Chip(
												avatar: const Icon(Icons.person, size: 16.0),
												label: Text(c.nombre),
												visualDensity: VisualDensity.compact,
											),
										)
										.toList(),
								),
						],
					),
				),
				const SizedBox(height: 12.0),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16.0),
					child: CampoBusqueda(
						controlador: _busquedaController,
						sugerencia: 'Buscar en esta lista...',
						alCambiar: (v) => setState(() => _filtro = v.trim()),
					),
				),
				Padding(
					padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
					child: Text(
						'${filtrados.length} producto${filtrados.length == 1 ? '' : 's'}',
						style: Theme.of(context).textTheme.bodySmall,
					),
				),
				Expanded(
					child: filtrados.isEmpty
						? Center(
							child: Text(
								detalle.items.isEmpty
									? 'Esta lista no tiene productos.\nUse "Agregar producto".'
									: 'Sin coincidencias para la busqueda.',
								textAlign: TextAlign.center,
								style: const TextStyle(color: Colors.grey),
							),
						)
						: ListView.separated(
							padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 88.0),
							itemCount: filtrados.length,
							separatorBuilder: (_, _) => const Divider(height: 1.0),
							itemBuilder: (context, i) {
								final item = filtrados[i];
								return _FilaProductoLista(
									item: item,
									onEditarPrecio: () => _editarPrecio(context, listaId, item),
									onEditarProducto: () => _editarProducto(context, listaId, item.producto),
									onQuitar: () => _quitarProducto(context, listaId, item),
								);
							},
						),
				),
			],
		);
	}

	Future<void> _crearLista(BuildContext context) async {
		final ctrl = TextEditingController();
		final nombre = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Nueva lista'),
				content: TextField(
					controller: ctrl,
					autofocus: true,
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
		final lista = await servicio.registrarListaPrecios(nombre);
		ref.invalidate(_listasProvider);
		setState(() => _listaId = lista.id);
	}

	Future<void> _eliminarLista(BuildContext context, ListaPrecios lista) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar lista'),
				content: Text(
					'Eliminar "${lista.nombre}" y todos sus precios?\n'
					'Los clientes quedaran sin lista asignada.',
				),
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
		if (_listaId == lista.id) {
			setState(() => _listaId = null);
		}
	}

	Future<void> _agregarProducto(BuildContext context, String listaId) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final productos = await servicio.listarProductos();
		final enLista = await servicio.listarItemsListaPrecios(listaId);
		final idsEnLista = enLista.map((i) => i.producto.id).toSet();
		final disponibles = productos
			.where((p) => p.activo && !idsEnLista.contains(p.id))
			.toList()
		  ..sort((a, b) => a.nombre.compareTo(b.nombre));

		if (!context.mounted) {
			return;
		}
		if (disponibles.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Todos los productos ya estan en esta lista')),
			);
			return;
		}

		final resultado = await showDialog<_ProductoPrecioNuevo>(
			context: context,
			builder: (ctx) => _DialogoAgregarProductoLista(productos: disponibles),
		);
		if (resultado == null) {
			return;
		}
		try {
			await servicio.guardarPrecioLista(
				listaId,
				resultado.productoId,
				resultado.precio,
			);
			ref.invalidate(_detalleListaProvider(listaId));
			if (!context.mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Producto agregado a la lista')),
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

	Future<void> _editarPrecio(
		BuildContext context,
		String listaId,
		ItemListaPrecios item,
	) async {
		final precioController = TextEditingController(
			text: item.precioLista.toStringAsFixed(2),
		);
		final guardado = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text(item.producto.nombre),
				content: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							TextField(
								controller: precioController,
								autofocus: true,
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								decoration: InputDecoration(
									labelText: 'Precio en esta lista',
									helperText:
										'Minimo: ${formatearMoneda(calcularPrecioMinimoVenta(item.producto.costoUnitario))}',
									border: const OutlineInputBorder(),
								),
							),
							PanelCalculoUtilidad(
								costoUnitario: item.producto.costoUnitario,
								precioController: precioController,
							),
						],
					),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Guardar'),
					),
				],
			),
		);
		final precio = double.tryParse(precioController.text.replaceAll(',', '.'));
		precioController.dispose();
		if (guardado != true || precio == null) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.guardarPrecioLista(listaId, item.producto.id, precio);
			ref.invalidate(_detalleListaProvider(listaId));
			if (!context.mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Precio actualizado')),
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

	Future<void> _editarProducto(
		BuildContext context,
		String listaId,
		Producto producto,
	) async {
		final ok = await Navigator.push<bool>(
			context,
			MaterialPageRoute<bool>(
				builder: (_) => PantallaFormularioProducto(productoExistente: producto),
			),
		);
		if (ok == true) {
			ref.invalidate(_detalleListaProvider(listaId));
		}
	}

	Future<void> _quitarProducto(
		BuildContext context,
		String listaId,
		ItemListaPrecios item,
	) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Quitar de la lista'),
				content: Text(
					'Quitar "${item.producto.nombre}" de esta lista?\n'
					'El producto seguira en el catalogo.',
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
				],
			),
		);
		if (ok != true) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.eliminarProductoDeLista(listaId, item.producto.id);
		ref.invalidate(_detalleListaProvider(listaId));
		if (!context.mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Producto quitado de la lista')),
		);
	}
}

class _FilaProductoLista extends StatelessWidget {
	const _FilaProductoLista({
		required this.item,
		required this.onEditarPrecio,
		required this.onEditarProducto,
		required this.onQuitar,
	});

	final ItemListaPrecios item;
	final VoidCallback onEditarPrecio;
	final VoidCallback onEditarProducto;
	final VoidCallback onQuitar;

	@override
	Widget build(BuildContext context) {
		final p = item.producto;
		return ListTile(
			title: Text(p.nombre),
			subtitle: Text(
				'Generico ${formatearMoneda(p.precioBase)} · Costo ${formatearMoneda(p.costoUnitario)}',
			),
			trailing: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					TextButton(
						onPressed: onEditarPrecio,
						child: Text(
							formatearMoneda(item.precioLista),
							style: const TextStyle(fontWeight: FontWeight.bold),
						),
					),
					PopupMenuButton<String>(
						onSelected: (accion) {
							switch (accion) {
								case 'precio':
									onEditarPrecio();
								case 'producto':
									onEditarProducto();
								case 'quitar':
									onQuitar();
							}
						},
						itemBuilder: (_) => const [
							PopupMenuItem(value: 'precio', child: Text('Modificar precio')),
							PopupMenuItem(value: 'producto', child: Text('Editar producto')),
							PopupMenuItem(value: 'quitar', child: Text('Quitar de la lista')),
						],
					),
				],
			),
			onTap: onEditarPrecio,
		);
	}
}

class _ProductoPrecioNuevo {
	const _ProductoPrecioNuevo({required this.productoId, required this.precio});

	final String productoId;
	final double precio;
}

class _DialogoAgregarProductoLista extends StatefulWidget {
	const _DialogoAgregarProductoLista({required this.productos});

	final List<Producto> productos;

	@override
	State<_DialogoAgregarProductoLista> createState() => _DialogoAgregarProductoListaState();
}

class _DialogoAgregarProductoListaState extends State<_DialogoAgregarProductoLista> {
	final _busquedaController = TextEditingController();
	final _precioController = TextEditingController();
	String? _productoId;
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		_precioController.dispose();
		super.dispose();
	}

	Producto? get _productoSeleccionado {
		if (_productoId == null) {
			return null;
		}
		for (final p in widget.productos) {
			if (p.id == _productoId) {
				return p;
			}
		}
		return null;
	}

	List<Producto> get _filtrados {
		if (_filtro.isEmpty) {
			return widget.productos;
		}
		final q = _filtro.toLowerCase();
		return widget.productos
			.where(
				(p) =>
					p.nombre.toLowerCase().contains(q) ||
					p.codigoBarras.toLowerCase().contains(q),
			)
			.toList();
	}

	void _confirmar() {
		final producto = _productoSeleccionado;
		final precio = double.tryParse(_precioController.text.replaceAll(',', '.'));
		if (producto == null || precio == null) {
			return;
		}
		Navigator.pop(
			context,
			_ProductoPrecioNuevo(productoId: producto.id, precio: precio),
		);
	}

	@override
	Widget build(BuildContext context) {
		final producto = _productoSeleccionado;
		final filtrados = _filtrados;

		return AlertDialog(
			title: const Text('Agregar producto'),
			content: SizedBox(
				width: 420.0,
				child: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar producto...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							const SizedBox(height: 8.0),
							DropdownButtonFormField<String>(
								initialValue: filtrados.any((p) => p.id == _productoId) ? _productoId : null,
								isExpanded: true,
								decoration: const InputDecoration(
									labelText: 'Producto',
									border: OutlineInputBorder(),
								),
								items: filtrados
									.map(
										(p) => DropdownMenuItem(
											value: p.id,
											child: Text(p.nombre),
										),
									)
									.toList(),
								onChanged: (v) => setState(() {
									_productoId = v;
									final sel = _productoSeleccionado;
									if (sel != null && _precioController.text.isEmpty) {
										_precioController.text = sel.precioBase.toStringAsFixed(2);
									}
								}),
							),
							const SizedBox(height: 12.0),
							TextField(
								controller: _precioController,
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								decoration: const InputDecoration(
									labelText: 'Precio en esta lista',
									border: OutlineInputBorder(),
								),
							),
							if (producto != null) ...[
								const SizedBox(height: 8.0),
								PanelCalculoUtilidad(
									costoUnitario: producto.costoUnitario,
									precioController: _precioController,
								),
							],
						],
					),
				),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
				FilledButton(onPressed: _confirmar, child: const Text('Agregar')),
			],
		);
	}
}

class _DetalleLista {
	const _DetalleLista({required this.clientes, required this.items});

	final List<Cliente> clientes;
	final List<ItemListaPrecios> items;
}

final _listasProvider = FutureProvider<List<ListaPrecios>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarListasPrecios();
});

final _detalleListaProvider = FutureProvider.family<_DetalleLista, String>((ref, listaId) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final clientes = await servicio.listarClientesPorLista(listaId);
	final items = await servicio.listarItemsListaPrecios(listaId);
	return _DetalleLista(clientes: clientes, items: items);
});
