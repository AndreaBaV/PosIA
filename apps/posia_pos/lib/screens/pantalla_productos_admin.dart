/// Pantalla de administracion de catalogo de productos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../widgets/dialogo_actualizar_precio_venta.dart';
import 'pantalla_formulario_producto.dart';
import 'pantalla_importar_productos_admin.dart';
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
	_FiltroEstadoProducto _estadoFiltro = _FiltroEstadoProducto.activos;

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final productosAsync = ref.watch(productosCatalogoAdminProvider);
		final categoriasAsync = ref.watch(_categoriasProductosProvider);
		final usuario = ref.watch(sesionUsuarioProvider);
		final rolPersonalizado = ref.watch(rolPersonalizadoSesionProvider);
		final puedeImportar = usuario != null &&
			tileAdminVisible(
				usuario,
				PermisosAdmin.importarProductos,
				rolPersonalizado: rolPersonalizado,
			);
		final categoriasPermitidas = usuario == null
			? null
			: PoliticaAccesoAdmin.categoriasProductoPermitidas(
				usuario,
				rolPersonalizado,
			);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Productos'),
				actions: [
					if (puedeImportar)
						IconButton(
							icon: const Icon(Icons.upload_file),
							tooltip: 'Importar por lote',
							onPressed: () => _abrirImportacion(context),
						),
					IconButton(
						icon: const Icon(Icons.add_circle, color: PosiaColors.cobrar),
						iconSize: 32.0,
						onPressed: () => _abrirFormulario(context),
					),
				],
			),
			body: productosAsync.when(
				data: (productos) {
					final categorias = (categoriasAsync.value ?? [])
						.where(
							(c) =>
								categoriasPermitidas == null ||
								categoriasPermitidas.contains(c.id),
						)
						.toList();
					final nombresCat = {for (final c in categorias) c.id: c.nombre};
					final filtrados = productos.where((p) {
						if (_estadoFiltro == _FiltroEstadoProducto.activos && !p.activo) {
							return false;
						}
						if (_estadoFiltro == _FiltroEstadoProducto.inactivos && p.activo) {
							return false;
						}
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
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 12.0),
								child: SegmentedButton<_FiltroEstadoProducto>(
									segments: const [
										ButtonSegment(
											value: _FiltroEstadoProducto.activos,
											label: Text('Activos'),
										),
										ButtonSegment(
											value: _FiltroEstadoProducto.inactivos,
											label: Text('Inactivos'),
										),
										ButtonSegment(
											value: _FiltroEstadoProducto.todos,
											label: Text('Todos'),
										),
									],
									selected: {_estadoFiltro},
									onSelectionChanged: (s) =>
										setState(() => _estadoFiltro = s.first),
								),
							),
							const SizedBox(height: 8.0),
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
												? 'Sin categoría'
												: nombresCat[producto.categoriaId] ?? 'Categoría';
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
															IconButton(
																icon: Icon(
																	producto.favoritoCaja
																		? Icons.star
																		: Icons.star_border,
																	color: producto.favoritoCaja
																		? Colors.amber
																		: null,
																),
																tooltip: 'Favorito en caja',
																onPressed: () async {
																	final servicio = await ref.read(
																		servicioAdminProvider.future,
																	);
																	await servicio.establecerFavoritoProducto(
																		producto.id,
																		!producto.favoritoCaja,
																	);
																	ref.invalidate(productosCatalogoAdminProvider);
																},
															),
															Text(
																formatearMoneda(producto.precioBase),
																style: const TextStyle(
																	fontWeight: FontWeight.bold,
																),
															),
															PopupMenuButton<String>(
																onSelected: (accion) =>
																	_accionProducto(context, accion, producto),
																itemBuilder: (_) => _menuProducto(producto),
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
		final usuario = ref.read(sesionUsuarioProvider);
		final rolPersonalizado = ref.read(rolPersonalizadoSesionProvider);
		if (usuario != null &&
			producto != null &&
			!PoliticaAccesoAdmin.puedeEditarProductoEnCategoria(
				usuario,
				rolPersonalizado,
				producto.categoriaId,
			)) {
			PosiaNotificaciones.mostrarSnackBar(
				context,
				const SnackBar(
					content: Text('Sin permiso para editar productos de esta categoría'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		final ok = await Navigator.push<bool>(
			context,
			MaterialPageRoute<bool>(
				builder: (_) => PantallaFormularioProducto(productoExistente: producto),
			),
		);
		if (ok == true) {
			ref.invalidate(productosCatalogoAdminProvider);
		}
	}

	Future<void> _abrirImportacion(BuildContext context) async {
		await Navigator.push<void>(
			context,
			MaterialPageRoute<void>(
				builder: (_) => const PantallaImportarProductosAdmin(),
			),
		);
		ref.invalidate(productosCatalogoAdminProvider);
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
		if (accion == 'precio') {
			final ok = await mostrarDialogoActualizarPrecioVenta(
				context: context,
				producto: producto,
				obtenerServicio: () => ref.read(servicioAdminProvider.future),
			);
			if (ok) {
				ref.invalidate(productosCatalogoAdminProvider);
			}
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
					title: const Text('Eliminar producto'),
					content: Text(
						'¿Eliminar permanentemente "${producto.nombre}"?\n\n'
						'Se borrará del catálogo junto con variantes y precios. '
						'No es posible si hay existencias en alguna tienda.',
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
						FilledButton(
							style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
							onPressed: () => Navigator.pop(ctx, true),
							child: const Text('Eliminar'),
						),
					],
				),
			);
			if (confirmar != true) {
				return;
			}
			final servicio = await ref.read(servicioAdminProvider.future);
			final ok = await servicio.eliminarProductoPermanente(producto.id);
			if (!context.mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text(
						ok
							? 'Producto eliminado'
							: 'No se puede eliminar: hay existencias en alguna tienda',
					),
					backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
				),
			);
			ref.invalidate(productosCatalogoAdminProvider);
			await refrescarDatosMaestros(ref);
		}
	}

	List<PopupMenuEntry<String>> _menuProducto(Producto producto) {
		return [
			const PopupMenuItem(value: 'editar', child: Text('Editar')),
			const PopupMenuItem(
				value: 'precio',
				child: Text('Actualizar precio'),
			),
			const PopupMenuItem(value: 'variantes', child: Text('Variantes')),
			PopupMenuItem(
				value: 'eliminar',
				child: Text(
					'Eliminar',
					style: TextStyle(color: PosiaColors.cancelar),
				),
			),
		];
	}
}

final _categoriasProductosProvider = FutureProvider<List<Categoria>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCategorias();
});

enum _FiltroEstadoProducto { activos, inactivos, todos }
