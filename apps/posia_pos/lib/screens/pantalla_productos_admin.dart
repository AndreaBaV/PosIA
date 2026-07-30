/// Pantalla de administracion de catalogo de productos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/admin_providers.dart';
import '../util/exportador_faltantes.dart';
import '../utils/compartir_whatsapp_util.dart';
import '../widgets/dialogo_actualizar_precio_venta.dart';
import 'pantalla_formulario_producto.dart';
import 'pantalla_importar_productos_admin.dart';
import 'pantalla_variantes_admin.dart';

class PantallaProductosAdmin extends ConsumerStatefulWidget {
	const PantallaProductosAdmin({super.key});

	@override
	ConsumerState<PantallaProductosAdmin> createState() =>
		_PantallaProductosAdminState();
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

	bool get _esFaltantes => _estadoFiltro == _FiltroEstadoProducto.faltantes;

	@override
	Widget build(BuildContext context) {
		final productosAsync = ref.watch(productosCatalogoAdminProvider);
		final categoriasAsync = ref.watch(_categoriasProductosProvider);
		final alertasAsync = ref.watch(alertasFaltantesAdminProvider);
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
		final alertas = alertasAsync.value ?? const <AlertaFaltante>[];
		return Scaffold(
			appBar: AppBar(
				title: Text(_esFaltantes ? 'Faltantes' : 'Productos'),
				actions: [
					if (_esFaltantes && alertas.isNotEmpty) ...[
						IconButton(
							icon: const Icon(Icons.download),
							tooltip: 'Exportar CSV',
							onPressed: () => _exportarFaltantes(context, alertas),
						),
						IconButton(
							icon: const Icon(Icons.chat),
							tooltip: 'Enviar por WhatsApp',
							onPressed: () => _enviarFaltantesWhatsApp(context, alertas),
						),
					],
					if (!_esFaltantes && puedeImportar)
						IconButton(
							icon: const Icon(Icons.upload_file),
							tooltip: 'Importar por lote',
							onPressed: () => _abrirImportacion(context),
						),
					if (!_esFaltantes)
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
					final alertasPorId = {
						for (final a in alertas) a.productoId: a,
					};
					final filtrados = productos.where((p) {
						if (_estadoFiltro == _FiltroEstadoProducto.faltantes) {
							if (!alertasPorId.containsKey(p.id)) {
								return false;
							}
						} else {
							if (_estadoFiltro == _FiltroEstadoProducto.activos &&
								!p.activo) {
								return false;
							}
							if (_estadoFiltro == _FiltroEstadoProducto.inactivos &&
								p.activo) {
								return false;
							}
						}
						if (_categoriaFiltro != null &&
							p.categoriaId != _categoriaFiltro) {
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
					if (_esFaltantes) {
						filtrados.sort((a, b) {
							final aa = alertasPorId[a.id]!;
							final bb = alertasPorId[b.id]!;
							return aa.cantidadActual.compareTo(bb.cantidadActual);
						});
					}
					return Column(
						children: [
							CampoBusqueda(
								controlador: _busquedaController,
								sugerencia: _esFaltantes
									? 'Buscar faltante...'
									: 'Buscar producto...',
								alCambiar: (v) => setState(() => _filtro = v.trim()),
							),
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 12.0),
								child: Wrap(
									spacing: 8.0,
									runSpacing: 4.0,
									children: [
										ChoiceChip(
											label: const Text('Activos'),
											selected: _estadoFiltro ==
												_FiltroEstadoProducto.activos,
											onSelected: (_) => setState(
												() => _estadoFiltro =
													_FiltroEstadoProducto.activos,
											),
										),
										ChoiceChip(
											label: const Text('Inactivos'),
											selected: _estadoFiltro ==
												_FiltroEstadoProducto.inactivos,
											onSelected: (_) => setState(
												() => _estadoFiltro =
													_FiltroEstadoProducto.inactivos,
											),
										),
										ChoiceChip(
											label: const Text('Todos'),
											selected: _estadoFiltro ==
												_FiltroEstadoProducto.todos,
											onSelected: (_) => setState(
												() => _estadoFiltro =
													_FiltroEstadoProducto.todos,
											),
										),
										ChoiceChip(
											avatar: Icon(
												Icons.warning_amber,
												size: 18,
												color: _estadoFiltro ==
														_FiltroEstadoProducto.faltantes
													? PosiaColors.cancelar
													: null,
											),
											label: Text(
												alertas.isEmpty
													? 'Faltantes'
													: 'Faltantes (${alertas.length})',
											),
											selected: _estadoFiltro ==
												_FiltroEstadoProducto.faltantes,
											selectedColor: Colors.red.shade100,
											onSelected: (_) => setState(
												() => _estadoFiltro =
													_FiltroEstadoProducto.faltantes,
											),
										),
									],
								),
							),
							const SizedBox(height: 8.0),
							if (_esFaltantes)
								_barraFaltantes(
									context,
									alertas: alertas,
									cargando: alertasAsync.isLoading,
								)
							else if (categorias.isNotEmpty)
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
									? Center(
										child: Padding(
											padding: const EdgeInsets.all(24.0),
											child: Text(
												_esFaltantes
													? 'No hay productos en o bajo el stock mínimo.\n'
														'Configura el mínimo en la pestaña Inventario '
														'de cada producto.'
													: 'Sin productos',
												textAlign: TextAlign.center,
											),
										),
									)
									: ListView.builder(
										itemCount: filtrados.length,
										itemBuilder: (context, indice) {
											final producto = filtrados[indice];
											final alerta = alertasPorId[producto.id];
											final catNombre = producto.categoriaId == null
												? 'Sin categoría'
												: nombresCat[producto.categoriaId] ?? 'Categoría';
											final bajoMinimo = alerta != null;
											return Card(
												margin: const EdgeInsets.symmetric(
													horizontal: 12.0,
													vertical: 4.0,
												),
												color: bajoMinimo && _esFaltantes
													? Colors.red.shade50
													: null,
												child: ListTile(
													leading: CircleAvatar(
														backgroundColor: bajoMinimo && _esFaltantes
															? PosiaColors.cancelar.withValues(alpha: 0.15)
															: producto.activo
																? PosiaColors.cobrar.withValues(alpha: 0.15)
																: Colors.grey.shade200,
														child: Icon(
															bajoMinimo && _esFaltantes
																? Icons.warning_amber
																: Icons.inventory_2,
															color: bajoMinimo && _esFaltantes
																? PosiaColors.cancelar
																: producto.activo
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
													subtitle: Text(
														alerta != null && _esFaltantes
															? 'Hay ${ExportadorFaltantes.formatearCantidad(alerta.cantidadActual)}'
																' · Mínimo ${ExportadorFaltantes.formatearCantidad(alerta.stockMinimo)}'
																' · Pedir ${ExportadorFaltantes.formatearCantidad(ExportadorFaltantes.cantidadAPedir(alerta))}'
															: '$catNombre · ${producto.codigoBarras}',
													),
													trailing: _esFaltantes
														? IconButton(
															icon: const Icon(Icons.edit_outlined),
															tooltip: 'Editar producto',
															onPressed: () =>
																_abrirFormulario(context, producto),
														)
														: Row(
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
																		ref.invalidate(
																			productosCatalogoAdminProvider,
																		);
																	},
																),
																Text(
																	formatearMoneda(producto.precioBase),
																	style: const TextStyle(
																		fontWeight: FontWeight.bold,
																	),
																),
																PopupMenuButton<String>(
																	onSelected: (accion) => _accionProducto(
																		context,
																		accion,
																		producto,
																	),
																	itemBuilder: (_) =>
																		_menuProducto(producto),
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

	Widget _barraFaltantes(
		BuildContext context, {
		required List<AlertaFaltante> alertas,
		required bool cargando,
	}) {
		return Material(
			color: Colors.red.shade50,
			child: Padding(
				padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
				child: Row(
					children: [
						Icon(Icons.warning_amber, color: PosiaColors.cancelar),
						const SizedBox(width: 8.0),
						Expanded(
							child: Text(
								cargando
									? 'Cargando faltantes…'
									: alertas.isEmpty
										? 'Sin productos bajo el mínimo'
										: '${alertas.length} producto${alertas.length == 1 ? '' : 's'} '
											'para surtir',
								style: TextStyle(
									color: Colors.red.shade900,
									fontWeight: FontWeight.w600,
								),
							),
						),
						if (alertas.isNotEmpty) ...[
							TextButton.icon(
								onPressed: () => _exportarFaltantes(context, alertas),
								icon: const Icon(Icons.download, size: 18),
								label: const Text('CSV'),
							),
							FilledButton.icon(
								style: FilledButton.styleFrom(
									backgroundColor: const Color(0xFF25D366),
								),
								onPressed: () =>
									_enviarFaltantesWhatsApp(context, alertas),
								icon: const Icon(Icons.chat, size: 18),
								label: const Text('WhatsApp'),
							),
						],
					],
				),
			),
		);
	}

	Future<String> _nombreTiendaActiva() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final tienda = await servicio.obtenerTiendaActiva();
		final nombre = tienda?.nombre.trim() ?? '';
		return nombre.isEmpty ? 'Tienda' : nombre;
	}

	Future<void> _exportarFaltantes(
		BuildContext context,
		List<AlertaFaltante> alertas,
	) async {
		final nombreTienda = await _nombreTiendaActiva();
		final csv = ExportadorFaltantes.generarCsv(
			nombreTienda: nombreTienda,
			alertas: alertas,
		);
		final ruta = await ExportadorFaltantes.guardarCsv(csv);
		if (!context.mounted) {
			return;
		}
		if (ruta == null) {
			PosiaNotificaciones.mostrarSnackBar(
				context,
				const SnackBar(content: Text('No se pudo guardar el CSV')),
			);
			return;
		}
		await Share.shareXFiles(
			[XFile(ruta, mimeType: 'text/csv')],
			subject: 'Faltantes — $nombreTienda',
			text: 'Lista de faltantes ($nombreTienda)',
		);
		if (!context.mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text('Exportado: $ruta')),
		);
	}

	Future<void> _enviarFaltantesWhatsApp(
		BuildContext context,
		List<AlertaFaltante> alertas,
	) async {
		final nombreTienda = await _nombreTiendaActiva();
		final texto = ExportadorFaltantes.textoWhatsApp(
			nombreTienda: nombreTienda,
			alertas: alertas,
		);
		if (!context.mounted) {
			return;
		}
		await compartirTextoWhatsAppConAviso(context, texto: texto);
	}

	Future<void> _abrirFormulario(
		BuildContext context, [
		Producto? producto,
	]) async {
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
			ref.invalidate(alertasFaltantesAdminProvider);
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
		ref.invalidate(alertasFaltantesAdminProvider);
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
						TextButton(
							onPressed: () => Navigator.pop(ctx, false),
							child: const Text('Cancelar'),
						),
						FilledButton(
							style: FilledButton.styleFrom(
								backgroundColor: PosiaColors.cancelar,
							),
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
			PosiaNotificaciones.mostrarSnackBar(
				context,
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
			ref.invalidate(alertasFaltantesAdminProvider);
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

enum _FiltroEstadoProducto { activos, inactivos, todos, faltantes }
