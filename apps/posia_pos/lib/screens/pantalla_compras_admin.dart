/// Registro de compras a proveedor con historial.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../utils/documento_ticket_util.dart';
import '../widgets/acciones_documento_ticket.dart';
import '../widgets/dialogo_actualizar_precio_venta.dart';

class PantallaComprasAdmin extends ConsumerStatefulWidget {
	const PantallaComprasAdmin({super.key});

	@override
	ConsumerState<PantallaComprasAdmin> createState() => _PantallaComprasAdminState();
}

class _PantallaComprasAdminState extends ConsumerState<PantallaComprasAdmin>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	final _notasController = TextEditingController();
	final _busquedaHistorialController = TextEditingController();
	final _busquedaProductoController = TextEditingController();
	final _cantidadControllers = <String, TextEditingController>{};
	final _costoControllers = <String, TextEditingController>{};
	final _seleccionados = <String>{};
	String? _proveedorId;
	String? _tiendaOperacionId;
	DateTime _fechaCompra = DateTime.now();
	String _filtroHistorial = '';
	String _filtroProducto = '';

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 2, vsync: this);
	}

	@override
	void dispose() {
		_tabs.dispose();
		_notasController.dispose();
		_busquedaHistorialController.dispose();
		_busquedaProductoController.dispose();
		for (final ctrl in _cantidadControllers.values) {
			ctrl.dispose();
		}
		for (final ctrl in _costoControllers.values) {
			ctrl.dispose();
		}
		super.dispose();
	}

	TextEditingController _controllerCantidad(String productoId, Producto producto) {
		return _cantidadControllers.putIfAbsent(
			productoId,
			() => TextEditingController(text: '1'),
		);
	}

	TextEditingController _controllerCosto(String productoId, Producto producto) {
		return _costoControllers.putIfAbsent(
			productoId,
			() => TextEditingController(
				text: producto.costoUnitario > 0
					? producto.costoUnitario.toStringAsFixed(2)
					: '',
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(_comprasDatosProvider(_tiendaOperacionId));
		return Scaffold(
			appBar: AppBar(
				title: const Text('Compras'),
				bottom: TabBar(
					controller: _tabs,
					tabs: const [
						Tab(text: 'Nueva compra'),
						Tab(text: 'Historial'),
					],
				),
			),
			body: datosAsync.when(
				data: (datos) => TabBarView(
					controller: _tabs,
					children: [
						_buildNuevaCompra(datos),
						_buildHistorial(datos),
					],
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Widget _buildNuevaCompra(_DatosCompras datos) {
		final proveedorId = _proveedorId ?? datos.proveedores.firstOrNull?.id;
		final productos = _productosFiltrados(datos.productos, proveedorId);
		final productosVisibles = productos.where((p) {
			if (_filtroProducto.isEmpty) {
				return true;
			}
			final q = _filtroProducto.toLowerCase();
			return p.nombre.toLowerCase().contains(q) ||
				p.codigoBarras.toLowerCase().contains(q);
		}).toList();

		return Column(
			children: [
				Padding(
					padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
					child: Column(
						children: [
							if (datos.tiendas.length > 1)
								DropdownButtonFormField<String>(
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
									onChanged: (v) => setState(() {
										_tiendaOperacionId = v;
										_seleccionados.clear();
									}),
								),
							if (datos.tiendas.length > 1) const SizedBox(height: 8.0),
							DropdownButtonFormField<String>(
								initialValue: proveedorId,
								decoration: const InputDecoration(
									labelText: 'Proveedor *',
									border: OutlineInputBorder(),
								),
								items: datos.proveedores
									.map(
										(p) => DropdownMenuItem(
											value: p.id,
											child: Text(p.nombre),
										),
									)
									.toList(),
								onChanged: datos.proveedores.isEmpty
									? null
									: (v) => setState(() {
										_proveedorId = v;
										_seleccionados.clear();
									}),
							),
							const SizedBox(height: 8.0),
							Row(
								children: [
									Expanded(
										child: OutlinedButton.icon(
											onPressed: () => _elegirFecha(context),
											icon: const Icon(Icons.calendar_today),
											label: Text(_formatearFecha(_fechaCompra)),
										),
									),
								],
							),
						],
					),
				),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
					child: Row(
						children: [
							Expanded(
								child: Text(
									'${_seleccionados.length} producto(s) · '
									'Total est.: ${formatearMoneda(_calcularTotalEstimado(productosVisibles))}',
									style: const TextStyle(fontWeight: FontWeight.w600),
								),
							),
							if (_seleccionados.isNotEmpty)
								TextButton(
									onPressed: () => setState(_seleccionados.clear),
									child: const Text('Limpiar'),
								),
						],
					),
				),
				CampoBusqueda(
					controlador: _busquedaProductoController,
					sugerencia: 'Buscar producto...',
					alCambiar: (v) => setState(() => _filtroProducto = v.trim()),
				),
				Expanded(
					child: datos.proveedores.isEmpty
						? const Center(child: Text('Registre proveedores primero'))
						: productosVisibles.isEmpty
							? const Center(child: Text('Sin productos disponibles'))
							: ListView.builder(
								itemCount: productosVisibles.length,
								itemBuilder: (_, i) {
									final producto = productosVisibles[i];
									final seleccionado = _seleccionados.contains(producto.id);
									final cantCtrl = _controllerCantidad(producto.id, producto);
									final costoCtrl = _controllerCosto(producto.id, producto);
									return CheckboxListTile(
										value: seleccionado,
										onChanged: (v) {
											setState(() {
												if (v == true) {
													_seleccionados.add(producto.id);
												} else {
													_seleccionados.remove(producto.id);
												}
											});
										},
										title: Text(producto.nombre),
										subtitle: seleccionado
											? Row(
												children: [
													SizedBox(
														width: 72.0,
														child: TextField(
															controller: cantCtrl,
															keyboardType: TextInputType.number,
															decoration: const InputDecoration(
																labelText: 'Cant.',
																isDense: true,
																border: OutlineInputBorder(),
															),
															onChanged: (_) => setState(() {}),
														),
													),
													const SizedBox(width: 8.0),
													Expanded(
														child: TextField(
															controller: costoCtrl,
															keyboardType: const TextInputType.numberWithOptions(
																decimal: true,
															),
															decoration: const InputDecoration(
																labelText: 'Costo u.',
																isDense: true,
																border: OutlineInputBorder(),
																prefixText: '\$ ',
															),
															onChanged: (_) => setState(() {}),
														),
													),
												],
											)
											: Text(
												'Costo actual: ${formatearMoneda(producto.costoUnitario)}',
												style: const TextStyle(fontSize: 12.0),
											),
									);
								},
							),
				),
				const Divider(height: 1.0),
				Padding(
					padding: const EdgeInsets.all(12.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							TextField(
								controller: _notasController,
								decoration: const InputDecoration(
									labelText: 'Notas (opcional)',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							FilledButton.icon(
								onPressed: proveedorId != null && _seleccionados.isNotEmpty
									? () => _registrarCompra(datos, proveedorId)
									: null,
								icon: const Icon(Icons.shopping_cart),
								label: Text(
									_seleccionados.isEmpty
										? 'Seleccione productos'
										: 'Registrar compra (${_seleccionados.length})',
								),
							),
						],
					),
				),
			],
		);
	}

	List<Producto> _productosFiltrados(List<Producto> todos, String? proveedorId) {
		if (proveedorId == null) {
			return todos;
		}
		final delProveedor = todos.where((p) => p.proveedorId == proveedorId).toList();
		return delProveedor.isNotEmpty ? delProveedor : todos;
	}

	double _calcularTotalEstimado(List<Producto> productos) {
		var total = 0.0;
		for (final id in _seleccionados) {
			final cant = double.tryParse(
				_cantidadControllers[id]?.text.replaceAll(',', '.') ?? '',
			) ?? 0.0;
			final costo = double.tryParse(
				_costoControllers[id]?.text.replaceAll(',', '.') ?? '',
			) ?? 0.0;
			total = total + (cant * costo);
		}
		return redondearMonto(total);
	}

	Widget _buildHistorial(_DatosCompras datos) {
		final filtradas = datos.compras.where((c) {
			if (_filtroHistorial.isEmpty) {
				return true;
			}
			final q = _filtroHistorial.toLowerCase();
			final proveedor = datos.nombresProveedor[c.proveedorId] ?? '';
			if (proveedor.toLowerCase().contains(q)) {
				return true;
			}
			for (final linea in c.lineas) {
				if (linea.nombreProducto.toLowerCase().contains(q)) {
					return true;
				}
			}
			return c.notas.toLowerCase().contains(q);
		}).toList();

		return Column(
			children: [
				CampoBusqueda(
					controlador: _busquedaHistorialController,
					sugerencia: 'Buscar por proveedor o producto...',
					alCambiar: (v) => setState(() => _filtroHistorial = v.trim()),
				),
				Expanded(
					child: filtradas.isEmpty
						? const Center(child: Text('Sin compras registradas'))
						: ListView.builder(
							itemCount: filtradas.length,
							itemBuilder: (_, i) {
								final compra = filtradas[i];
								final proveedor = datos.nombresProveedor[compra.proveedorId] ?? '?';
								return Card(
									margin: const EdgeInsets.symmetric(
										horizontal: 12.0,
										vertical: 4.0,
									),
									child: ListTile(
										leading: const Icon(Icons.receipt_long, color: Colors.brown),
										title: Text(proveedor),
										subtitle: Text(
											'${compra.lineas.length} productos · '
											'${_formatearFecha(compra.fechaCompra.toLocal())}',
										),
										trailing: Text(
											formatearMoneda(compra.total),
											style: const TextStyle(fontWeight: FontWeight.bold),
										),
										onTap: () => _mostrarDetalle(compra, datos),
									),
								);
							},
						),
				),
			],
		);
	}

	String _formatearFecha(DateTime fecha) {
		final d = fecha.day.toString().padLeft(2, '0');
		final m = fecha.month.toString().padLeft(2, '0');
		return '$d/$m/${fecha.year}';
	}

	Future<void> _elegirFecha(BuildContext context) async {
		final elegida = await showDatePicker(
			context: context,
			initialDate: _fechaCompra,
			firstDate: DateTime(2020),
			lastDate: DateTime.now().add(const Duration(days: 1)),
		);
		if (elegida != null) {
			setState(() => _fechaCompra = elegida);
		}
	}

	List<LineaCompraSolicitud> _construirLineas() {
		return _seleccionados.map((productoId) {
			final cantidad = double.tryParse(
				_cantidadControllers[productoId]?.text.replaceAll(',', '.') ?? '',
			) ?? 0.0;
			final costo = double.tryParse(
				_costoControllers[productoId]?.text.replaceAll(',', '.') ?? '',
			) ?? 0.0;
			return LineaCompraSolicitud(
				productoId: productoId,
				cantidad: cantidad,
				costoUnitario: costo,
			);
		}).toList();
	}

	Future<void> _registrarCompra(_DatosCompras datos, String proveedorId) async {
		try {
			final lineasPrecio = _seleccionados.map((productoId) {
				final producto = datos.productos.firstWhere((p) => p.id == productoId);
				final nuevoCosto = double.tryParse(
					_costoControllers[productoId]?.text.replaceAll(',', '.') ?? '',
				) ?? producto.costoUnitario;
				return (producto: producto, nuevoCosto: nuevoCosto);
			}).toList();
			final servicio = await ref.read(servicioAdminProvider.future);
			final operador = ref.read(sesionUsuarioProvider);
			final fechaLocal = DateTime(
				_fechaCompra.year,
				_fechaCompra.month,
				_fechaCompra.day,
			);
			await servicio.registrarCompra(
				proveedorId: proveedorId,
				lineas: _construirLineas(),
				fechaCompra: fechaLocal,
				notas: _notasController.text.trim(),
				tiendaId: datos.tiendaId,
				operador: operador,
			);
			ref.invalidate(_comprasDatosProvider(_tiendaOperacionId));
			setState(_seleccionados.clear);
			_notasController.clear();
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Compra registrada')),
			);
			await mostrarDialogoPreciosPostCompra(
				context: context,
				lineas: lineasPrecio,
				obtenerServicio: () => ref.read(servicioAdminProvider.future),
			);
			if (!mounted) {
				return;
			}
			ref.invalidate(_comprasDatosProvider(_tiendaOperacionId));
			_tabs.animateTo(1);
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	void _mostrarDetalle(Compra compra, _DatosCompras datos) {
		final proveedor = datos.nombresProveedor[compra.proveedorId] ?? '?';
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.55,
				maxChildSize: 0.9,
				builder: (context, scrollController) => Padding(
					padding: const EdgeInsets.all(20.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								proveedor,
								style: Theme.of(context).textTheme.titleLarge,
							),
							Text(
								'Folio ${compra.id.substring(0, 8).toUpperCase()} · '
								'${_formatearFecha(compra.fechaCompra.toLocal())}',
							),
							Text(
								'Total: ${formatearMoneda(compra.total)}',
								style: const TextStyle(fontWeight: FontWeight.bold),
							),
							if (compra.notas.isNotEmpty) Text('Notas: ${compra.notas}'),
							const SizedBox(height: 12.0),
							Expanded(
								child: ListView(
									controller: scrollController,
									children: compra.lineas.map((linea) {
										return ListTile(
											contentPadding: EdgeInsets.zero,
											title: Text(linea.nombreProducto),
											subtitle: Text(
												'${linea.cantidad.toStringAsFixed(0)} u. × '
												'${formatearMoneda(linea.costoUnitario)}',
											),
											trailing: Text(formatearMoneda(linea.subtotal)),
										);
									}).toList(),
								),
							),
							Align(
								alignment: Alignment.centerRight,
								child: AccionesDocumentoTicket(
									onWhatsApp: () async {
										final servicio = await ref.read(servicioAdminProvider.future);
										final texto = await construirTextoCompra(
											compra: compra,
											nombreProveedor: proveedor,
											servicio: servicio,
										);
										if (!context.mounted) {
											return;
										}
										await compartirDocumentoWhatsApp(context, texto: texto);
									},
									onCerrar: () => Navigator.pop(ctx),
								),
							),
						],
					),
				),
			),
		);
	}
}

class _DatosCompras {
	const _DatosCompras({
		required this.compras,
		required this.proveedores,
		required this.productos,
		required this.tiendas,
		required this.tiendaId,
		required this.nombresProveedor,
	});

	final List<Compra> compras;
	final List<Proveedor> proveedores;
	final List<Producto> productos;
	final List<Tienda> tiendas;
	final String tiendaId;
	final Map<String, String> nombresProveedor;
}

final _comprasDatosProvider = FutureProvider.family<_DatosCompras, String?>(
	(ref, tiendaOperacionId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final operador = ref.watch(sesionUsuarioProvider);
		final tiendas = await servicio.obtenerTiendasPermitidas(operador: operador);
		final tiendaId = tiendaOperacionId ?? operador?.tiendaId ?? servicio.tiendaActivaId;
		final compras = await servicio.listarCompras(tiendaId: tiendaId, operador: operador);
		final proveedores = await servicio.listarProveedores();
		final productos = await servicio.listarProductosActivosPorTienda(tiendaId);
		return _DatosCompras(
			compras: compras,
			proveedores: proveedores.where((p) => p.activo).toList(),
			productos: productos,
			tiendas: tiendas,
			tiendaId: tiendaId,
			nombresProveedor: {for (final p in proveedores) p.id: p.nombre},
		);
	},
);
