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
	/// Clave de ubicación global (modo simple): `tipo:id`.
	String? _ubicacionClave;
	bool _subdividir = false;
	/// Por producto: lista de (clave ubicación, cantidad).
	final _subdivisiones = <String, List<_ParticionUbicacion>>{};
	String? _proveedorId;
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
		for (final partes in _subdivisiones.values) {
			for (final p in partes) {
				p.cantidadController.dispose();
			}
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

	UbicacionMercanciaCompra _ubicacionSeleccionada(DatosComprasAdmin datos) {
		final clave = _ubicacionClave;
		if (clave != null) {
			for (final u in datos.ubicaciones) {
				if (u.clave == clave) {
					return u;
				}
			}
		}
		return datos.ubicacionPorDefecto;
	}

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(comprasDatosAdminProvider);
		return Scaffold(
			resizeToAvoidBottomInset: true,
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

	Widget _buildNuevaCompra(DatosComprasAdmin datos) {
		final proveedorId = _proveedorIdSeleccionado(datos.proveedores);
		final productos = _productosFiltrados(datos.productos, proveedorId);
		final productosVisibles = productos.where((p) {
			if (_filtroProducto.isEmpty) {
				return true;
			}
			final q = _filtroProducto.toLowerCase();
			return p.nombre.toLowerCase().contains(q) ||
				p.codigoBarras.toLowerCase().contains(q);
		}).toList();
		final margenTeclado = _margenInferiorTeclado(context);
		final ubicacion = _ubicacionSeleccionada(datos);

		return Column(
			children: [
				Expanded(
					child: CustomScrollView(
						keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
						slivers: [
							SliverPadding(
								padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
								sliver: SliverList(
									delegate: SliverChildListDelegate([
										InputDecorator(
											decoration: const InputDecoration(
												labelText: 'Entidad',
												border: OutlineInputBorder(),
											),
											child: Text(
												NOMBRE_COMERCIAL_APP,
												style: Theme.of(context).textTheme.titleMedium,
											),
										),
										const SizedBox(height: 8.0),
										DropdownButtonFormField<String>(
											key: ValueKey(
												datos.proveedores.map((p) => p.id).join(','),
											),
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
										OutlinedButton.icon(
											onPressed: () => _elegirFecha(context),
											icon: const Icon(Icons.calendar_today),
											label: Text(_formatearFecha(_fechaCompra)),
										),
										const SizedBox(height: 8.0),
										SwitchListTile(
											contentPadding: EdgeInsets.zero,
											title: const Text('Subdividir mercancía'),
											subtitle: const Text(
												'Reparte cantidades entre almacenes y tiendas',
											),
											value: _subdividir,
											onChanged: (v) => setState(() => _subdividir = v),
										),
										if (!_subdividir) ...[
											DropdownButtonFormField<String>(
												key: ValueKey(datos.ubicaciones.map((u) => u.clave).join(',')),
												initialValue: ubicacion.clave,
												decoration: const InputDecoration(
													labelText: 'Ubicación de mercancía',
													border: OutlineInputBorder(),
													helperText:
														'Si no elige, se usa el almacén por defecto',
												),
												items: datos.ubicaciones
													.map(
														(u) => DropdownMenuItem(
															value: u.clave,
															child: Text(u.etiqueta),
														),
													)
													.toList(),
												onChanged: datos.ubicaciones.isEmpty
													? null
													: (v) => setState(() => _ubicacionClave = v),
											),
										],
									]),
								),
							),
							SliverPadding(
								padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
								sliver: SliverToBoxAdapter(
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
							),
							SliverToBoxAdapter(
								child: CampoBusqueda(
									controlador: _busquedaProductoController,
									sugerencia: 'Buscar producto...',
									alCambiar: (v) => setState(() => _filtroProducto = v.trim()),
								),
							),
							if (datos.proveedores.isEmpty)
								const SliverFillRemaining(
									hasScrollBody: false,
									child: Center(child: Text('Registre proveedores primero')),
								)
							else if (productosVisibles.isEmpty)
								const SliverFillRemaining(
									hasScrollBody: false,
									child: Center(child: Text('Sin productos disponibles')),
								)
							else
								SliverList(
									delegate: SliverChildBuilderDelegate(
										(_, i) => _tileProductoCompra(productosVisibles[i], datos),
										childCount: productosVisibles.length,
									),
								),
							SliverPadding(
								padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 0.0),
								sliver: SliverToBoxAdapter(
									child: TextField(
										controller: _notasController,
										onTap: () => _desplazarCampoEnfocado(),
										decoration: const InputDecoration(
											labelText: 'Notas (opcional)',
											border: OutlineInputBorder(),
										),
									),
								),
							),
							SliverPadding(
								padding: EdgeInsets.only(bottom: margenTeclado),
							),
						],
					),
				),
				const Divider(height: 1.0),
				SafeArea(
					top: false,
					child: Padding(
						padding: const EdgeInsets.all(12.0),
						child: FilledButton.icon(
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
					),
				),
			],
		);
	}

	Widget _tileProductoCompra(Producto producto, DatosComprasAdmin datos) {
		final seleccionado = _seleccionados.contains(producto.id);
		final cantCtrl = _controllerCantidad(producto.id, producto);
		final costoCtrl = _controllerCosto(producto.id, producto);
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				CheckboxListTile(
					value: seleccionado,
					onChanged: (v) {
						setState(() {
							if (v == true) {
								_seleccionados.add(producto.id);
								if (_subdividir) {
									_asegurarSubdivisionInicial(producto.id, datos);
								}
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
										onTap: () => _desplazarCampoEnfocado(),
										decoration: const InputDecoration(
											labelText: 'Cant.',
											isDense: true,
											border: OutlineInputBorder(),
										),
										onChanged: (_) => setState(() {
											if (_subdividir) {
												_sincronizarPrimeraParticion(producto.id);
											}
										}),
									),
								),
								const SizedBox(width: 8.0),
								Expanded(
									child: TextField(
										controller: costoCtrl,
										keyboardType: const TextInputType.numberWithOptions(
											decimal: true,
										),
										onTap: () => _desplazarCampoEnfocado(),
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
				),
				if (seleccionado && _subdividir)
					Padding(
						padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
						child: _buildSubdivisionProducto(producto.id, datos),
					),
			],
		);
	}

	void _asegurarSubdivisionInicial(String productoId, DatosComprasAdmin datos) {
		if (_subdivisiones.containsKey(productoId)) {
			return;
		}
		final cant = _cantidadControllers[productoId]?.text ?? '1';
		final def = datos.ubicacionPorDefecto;
		_subdivisiones[productoId] = [
			_ParticionUbicacion(
				ubicacionClave: def.clave,
				cantidadController: TextEditingController(text: cant),
			),
		];
	}

	void _sincronizarPrimeraParticion(String productoId) {
		final partes = _subdivisiones[productoId];
		if (partes == null || partes.isEmpty) {
			return;
		}
		if (partes.length == 1) {
			partes.first.cantidadController.text =
				_cantidadControllers[productoId]?.text ?? '1';
		}
	}

	Widget _buildSubdivisionProducto(String productoId, DatosComprasAdmin datos) {
		_asegurarSubdivisionInicial(productoId, datos);
		final partes = _subdivisiones[productoId]!;
		final totalLinea = double.tryParse(
			_cantidadControllers[productoId]?.text.replaceAll(',', '.') ?? '',
		) ?? 0.0;
		final suma = partes.fold<double>(0.0, (acc, p) {
			return acc +
				(double.tryParse(p.cantidadController.text.replaceAll(',', '.')) ?? 0.0);
		});
		final ok = (suma - totalLinea).abs() <= 0.0001;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				for (var i = 0; i < partes.length; i++)
					Padding(
						padding: const EdgeInsets.only(bottom: 8.0),
						child: Row(
							children: [
								Expanded(
									flex: 3,
									child: DropdownButtonFormField<String>(
										initialValue: partes[i].ubicacionClave,
										isExpanded: true,
										decoration: const InputDecoration(
											labelText: 'Ubicación',
											isDense: true,
											border: OutlineInputBorder(),
										),
										items: datos.ubicaciones
											.map(
												(u) => DropdownMenuItem(
													value: u.clave,
													child: Text(u.etiqueta, overflow: TextOverflow.ellipsis),
												),
											)
											.toList(),
										onChanged: (v) {
											if (v == null) {
												return;
											}
											setState(() => partes[i].ubicacionClave = v);
										},
									),
								),
								const SizedBox(width: 8.0),
								SizedBox(
									width: 72.0,
									child: TextField(
										controller: partes[i].cantidadController,
										keyboardType: const TextInputType.numberWithOptions(
											decimal: true,
										),
										decoration: const InputDecoration(
											labelText: 'Cant.',
											isDense: true,
											border: OutlineInputBorder(),
										),
										onChanged: (_) => setState(() {}),
									),
								),
								IconButton(
									onPressed: partes.length <= 1
										? null
										: () => setState(() {
											partes[i].cantidadController.dispose();
											partes.removeAt(i);
										}),
									icon: const Icon(Icons.remove_circle_outline),
								),
							],
						),
					),
				Row(
					children: [
						TextButton.icon(
							onPressed: () => setState(() {
								partes.add(
									_ParticionUbicacion(
										ubicacionClave: datos.ubicacionPorDefecto.clave,
										cantidadController: TextEditingController(text: '0'),
									),
								);
							}),
							icon: const Icon(Icons.add),
							label: const Text('Ubicación'),
						),
						const Spacer(),
						Text(
							ok
								? 'OK'
								: 'Suma ${suma.toStringAsFixed(2)} ≠ ${totalLinea.toStringAsFixed(2)}',
							style: TextStyle(
								color: ok ? Colors.green.shade700 : Colors.red.shade700,
								fontSize: 12.0,
								fontWeight: FontWeight.w600,
							),
						),
					],
				),
			],
		);
	}

	double _margenInferiorTeclado(BuildContext context) {
		if (MediaQuery.viewInsetsOf(context).bottom <= 0) {
			return 12.0;
		}
		return AccesorioTecladoMovil.alturaBarraListo +
			AccesorioTecladoMovil.margenInferiorDesplazamiento;
	}

	void _desplazarCampoEnfocado() {
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted) {
				AccesorioTecladoMovil.desplazarCampoEnfocado(context);
			}
		});
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

	String? _proveedorIdSeleccionado(List<Proveedor> proveedores) {
		if (proveedores.isEmpty) {
			return null;
		}
		if (_proveedorId != null && proveedores.any((p) => p.id == _proveedorId)) {
			return _proveedorId;
		}
		return proveedores.first.id;
	}

	Widget _buildHistorial(DatosComprasAdmin datos) {
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
											'${_formatearFecha(compra.fechaCompra.toLocal())}'
											'${_resumenUbicaciones(compra, datos)}',
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

	String _resumenUbicaciones(Compra compra, DatosComprasAdmin datos) {
		if (compra.asignaciones.isEmpty) {
			return '';
		}
		final claves = <String>{};
		for (final a in compra.asignaciones) {
			claves.add('${a.destinoTipo.name}:${a.destinoId}');
		}
		if (claves.length == 1) {
			final clave = claves.first;
			final nombre = datos.nombresUbicacion[clave] ?? clave;
			return ' · $nombre';
		}
		return ' · ${claves.length} ubicaciones';
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

	List<AsignacionCompraSolicitud>? _construirUbicaciones(DatosComprasAdmin datos) {
		if (!_subdividir) {
			final ubicacion = _ubicacionSeleccionada(datos);
			return _seleccionados.map((productoId) {
				final cantidad = double.tryParse(
					_cantidadControllers[productoId]?.text.replaceAll(',', '.') ?? '',
				) ?? 0.0;
				return AsignacionCompraSolicitud(
					productoId: productoId,
					destinoTipo: ubicacion.tipo,
					destinoId: ubicacion.id,
					cantidad: cantidad,
				);
			}).toList();
		}
		final resultado = <AsignacionCompraSolicitud>[];
		for (final productoId in _seleccionados) {
			final partes = _subdivisiones[productoId] ?? [];
			for (final parte in partes) {
				final cantidad = double.tryParse(
					parte.cantidadController.text.replaceAll(',', '.'),
				) ?? 0.0;
				if (cantidad <= 0) {
					continue;
				}
				final ubicacion = datos.ubicaciones.firstWhere(
					(u) => u.clave == parte.ubicacionClave,
					orElse: () => datos.ubicacionPorDefecto,
				);
				resultado.add(
					AsignacionCompraSolicitud(
						productoId: productoId,
						destinoTipo: ubicacion.tipo,
						destinoId: ubicacion.id,
						cantidad: cantidad,
					),
				);
			}
		}
		return resultado;
	}

	Future<void> _registrarCompra(DatosComprasAdmin datos, String proveedorId) async {
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
				ubicaciones: _construirUbicaciones(datos),
				operador: operador,
			);
			ref.invalidate(comprasDatosAdminProvider);
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
			ref.invalidate(comprasDatosAdminProvider);
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

	void _mostrarDetalle(Compra compra, DatosComprasAdmin datos) {
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
							if (compra.asignaciones.isNotEmpty) ...[
								const SizedBox(height: 8.0),
								Text(
									'Ubicaciones',
									style: Theme.of(context).textTheme.titleSmall,
								),
								...compra.asignaciones.map((a) {
									final clave = '${a.destinoTipo.name}:${a.destinoId}';
									final nombre = datos.nombresUbicacion[clave] ?? clave;
									return Text(
										'· $nombre: ${a.cantidad.toStringAsFixed(2)}',
									);
								}),
							],
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
										final digital = await obtenerTicketDigitalCompra(
											compra: compra,
											nombreProveedor: proveedor,
											servicio: servicio,
										);
										if (!context.mounted) {
											return;
										}
										await compartirDocumentoWhatsApp(
											context,
											contenido: digital,
										);
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

class _ParticionUbicacion {
	_ParticionUbicacion({
		required this.ubicacionClave,
		required this.cantidadController,
	});

	String ubicacionClave;
	final TextEditingController cantidadController;
}
