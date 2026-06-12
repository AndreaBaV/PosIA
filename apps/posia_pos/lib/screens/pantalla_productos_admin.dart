/// Pantalla de administracion de catalogo de productos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import 'pantalla_formulario_producto.dart';
import 'pantalla_variantes_admin.dart';

class PantallaProductosAdmin extends ConsumerStatefulWidget {
	const PantallaProductosAdmin({super.key});

	@override
	ConsumerState<PantallaProductosAdmin> createState() => _PantallaProductosAdminState();
}

class _PantallaProductosAdminState extends ConsumerState<PantallaProductosAdmin> {
	final _busquedaController = TextEditingController();
	String _filtro = '';
	String? _categoriaFiltro;

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final productosAsync = ref.watch(_productosCatalogoProvider);
		final categoriasAsync = ref.watch(_categoriasProductosProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Productos'),
				actions: [
					IconButton(
						icon: const Icon(Icons.add_circle, color: PosiaColors.cobrar),
						iconSize: 32.0,
						onPressed: () => _abrirFormulario(context),
					),
				],
			),
			body: productosAsync.when(
				data: (productos) {
					final categorias = categoriasAsync.value ?? [];
					final nombresCat = {for (final c in categorias) c.id: c.nombre};
					final filtrados = productos.where((p) {
						if (_categoriaFiltro != null && p.categoriaId != _categoriaFiltro) {
							return false;
						}
						if (_filtro.isEmpty) {
							return true;
						}
						final q = _filtro.toLowerCase();
						final cat = p.categoriaId == null
							? ''
							: nombresCat[p.categoriaId]?.toLowerCase() ?? '';
						return p.nombre.toLowerCase().contains(q) ||
							p.codigoBarras.toLowerCase().contains(q) ||
							cat.contains(q);
					}).toList();
					return Column(
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: 'Buscar producto...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							if (categorias.isNotEmpty)
								SizedBox(
									height: 48.0,
									child: ListView(
										scrollDirection: Axis.horizontal,
										padding: const EdgeInsets.symmetric(horizontal: 12.0),
										children: [
											Padding(
												padding: const EdgeInsets.only(right: 8.0),
												child: FilterChip(
													label: const Text('Todas'),
													selected: _categoriaFiltro == null,
													onSelected: (_) =>
														setState(() => _categoriaFiltro = null),
												),
											),
											...categorias.where((c) => c.activa).map(
												(c) => Padding(
													padding: const EdgeInsets.only(right: 8.0),
													child: FilterChip(
														label: Text(c.nombre),
														selected: _categoriaFiltro == c.id,
														onSelected: (_) => setState(
															() => _categoriaFiltro = c.id,
														),
													),
												),
											),
										],
									),
								),
							Expanded(
								child: filtrados.isEmpty
									? const Center(child: Text('Sin productos'))
									: ListView.builder(
										itemCount: filtrados.length,
										itemBuilder: (context, indice) {
											final producto = filtrados[indice];
											final catNombre = producto.categoriaId == null
												? 'Sin categoria'
												: nombresCat[producto.categoriaId] ?? 'Categoria';
											return Card(
												margin: const EdgeInsets.symmetric(
													horizontal: 12.0,
													vertical: 4.0,
												),
												child: ListTile(
													leading: CircleAvatar(
														backgroundColor: producto.activo
															? PosiaColors.cobrar.withValues(alpha: 0.15)
															: Colors.grey.shade200,
														child: Icon(
															Icons.inventory_2,
															color: producto.activo
																? PosiaColors.cobrar
																: Colors.grey,
														),
													),
													title: Text(
														producto.nombre,
														style: TextStyle(
															decoration: producto.activo
																? null
																: TextDecoration.lineThrough,
														),
													),
													subtitle: Text('$catNombre · ${producto.codigoBarras}'),
													trailing: Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															Text(
																formatearMoneda(producto.precioBase),
																style: const TextStyle(
																	fontWeight: FontWeight.bold,
																),
															),
															PopupMenuButton<String>(
																onSelected: (accion) =>
																	_accionProducto(context, accion, producto),
																itemBuilder: (_) => const [
																	PopupMenuItem(
																		value: 'editar',
																		child: Text('Editar'),
																	),
																	PopupMenuItem(
																		value: 'variantes',
																		child: Text('Variantes'),
																	),
																	PopupMenuItem(
																		value: 'eliminar',
																		child: Text('Desactivar'),
																	),
																],
															),
														],
													),
													onTap: () => _abrirFormulario(context, producto),
												),
											);
										},
									),
							),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (error, _) => Center(child: Text(error.toString())),
			),
		);
	}

	Future<void> _abrirFormulario(BuildContext context, [Producto? producto]) async {
		final ok = await Navigator.push<bool>(
			context,
			MaterialPageRoute<bool>(
				builder: (_) => PantallaFormularioProducto(productoExistente: producto),
			),
		);
		if (ok == true) {
			ref.invalidate(_productosCatalogoProvider);
		}
	}

	Future<void> _accionProducto(
		BuildContext context,
		String accion,
		Producto producto,
	) async {
		if (accion == 'editar') {
			await _abrirFormulario(context, producto);
			return;
		}
		if (accion == 'variantes') {
			await Navigator.push(
				context,
				MaterialPageRoute<void>(
					builder: (_) => PantallaVariantesAdmin(producto: producto),
				),
			);
			return;
		}
		if (accion == 'eliminar') {
			final confirmar = await showDialog<bool>(
				context: context,
				builder: (ctx) => AlertDialog(
					title: const Text('Desactivar producto'),
					content: Text('Desactivar "${producto.nombre}"?'),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
						FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desactivar')),
					],
				),
			);
			if (confirmar != true) {
				return;
			}
			final servicio = await ref.read(servicioAdminProvider.future);
			final ok = await servicio.eliminarProducto(producto.id);
			if (!context.mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						ok ? 'Producto desactivado' : 'No se puede desactivar (hay stock)',
					),
					backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
				),
			);
			ref.invalidate(_productosCatalogoProvider);
		}
	}
}

final _productosCatalogoProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductosCatalogo();
});

final _categoriasProductosProvider = FutureProvider<List<Categoria>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCategorias();
});
