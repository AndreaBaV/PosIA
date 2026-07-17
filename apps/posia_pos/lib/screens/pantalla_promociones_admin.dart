/// Admin de promociones: lotes de mayoreo cruzado y combos de precio fijo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

class PantallaPromocionesAdmin extends ConsumerStatefulWidget {
	const PantallaPromocionesAdmin({super.key});

	@override
	ConsumerState<PantallaPromocionesAdmin> createState() =>
		_PantallaPromocionesAdminState();
}

class _PantallaPromocionesAdminState extends ConsumerState<PantallaPromocionesAdmin>
	with SingleTickerProviderStateMixin {
	late final TabController _tabController;

	@override
	void initState() {
		super.initState();
		_tabController = TabController(length: 2, vsync: this);
	}

	@override
	void dispose() {
		_tabController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Promociones'),
				bottom: TabBar(
					controller: _tabController,
					tabs: const [
						Tab(text: 'Lotes de mayoreo'),
						Tab(text: 'Combos'),
					],
				),
			),
			body: TabBarView(
				controller: _tabController,
				children: const [_VistaLotes(), _VistaCombos()],
			),
		);
	}
}

// ============================== LOTES ==============================

class _VistaLotes extends ConsumerWidget {
	const _VistaLotes();

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final lotesAsync = ref.watch(lotesPromocionAdminProvider);
		return Scaffold(
			body: lotesAsync.when(
				data: (lotes) {
					if (lotes.isEmpty) {
						return const Center(
							child: Text(
								'Sin lotes de promoción.\n'
								'Ej: "20 sopas de cualquier sabor a precio de caja".',
								textAlign: TextAlign.center,
								style: TextStyle(color: Colors.grey),
							),
						);
					}
					return ListView.separated(
						padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 88.0),
						itemCount: lotes.length,
						separatorBuilder: (_, _) => const Divider(height: 1.0),
						itemBuilder: (context, i) {
							final lote = lotes[i];
							return ListTile(
								title: Text(
									lote.nombre.isNotEmpty ? lote.nombre : 'Lote ${lote.codigoExterno}',
									style: TextStyle(
										color: lote.activo ? null : Colors.grey,
									),
								),
								subtitle: Text(
									'Desde ${lote.cantidadMinima.toStringAsFixed(0)} piezas → '
									'${formatearMoneda(lote.precioUnitario)} c/u · '
									'${lote.productoIds.length} producto${lote.productoIds.length == 1 ? '' : 's'}',
								),
								trailing: Switch(
									value: lote.activo,
									onChanged: (activo) => _cambiarActivo(context, ref, lote, activo),
								),
								onTap: () => _editarLote(context, ref, lote),
							);
						},
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () => _editarLote(context, ref, null),
				icon: const Icon(Icons.add),
				label: const Text('Nuevo lote'),
			),
		);
	}

	Future<void> _cambiarActivo(
		BuildContext context,
		WidgetRef ref,
		LotePromocion lote,
		bool activo,
	) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		if (activo) {
			await servicio.guardarLotePromocion(
				id: lote.id,
				nombre: lote.nombre,
				cantidadMinima: lote.cantidadMinima,
				precioUnitario: lote.precioUnitario,
				productoIds: lote.productoIds,
				activo: true,
			);
		} else {
			await servicio.eliminarLotePromocion(lote.id);
		}
		invalidarPromociones(ref);
	}

	Future<void> _editarLote(
		BuildContext context,
		WidgetRef ref,
		LotePromocion? lote,
	) async {
		final guardado = await showDialog<bool>(
			context: context,
			builder: (_) => _DialogoLotePromocion(lote: lote),
		);
		if (guardado == true) {
			invalidarPromociones(ref);
		}
	}
}

class _DialogoLotePromocion extends ConsumerStatefulWidget {
	const _DialogoLotePromocion({this.lote});

	final LotePromocion? lote;

	@override
	ConsumerState<_DialogoLotePromocion> createState() => _DialogoLotePromocionState();
}

class _DialogoLotePromocionState extends ConsumerState<_DialogoLotePromocion> {
	late final _nombreController = TextEditingController(text: widget.lote?.nombre ?? '');
	late final _cantidadController = TextEditingController(
		text: widget.lote != null ? widget.lote!.cantidadMinima.toStringAsFixed(0) : '',
	);
	late final _precioController = TextEditingController(
		text: widget.lote != null ? widget.lote!.precioUnitario.toStringAsFixed(2) : '',
	);
	List<MiembroPromocion> _miembros = const [];
	bool _cargando = true;

	@override
	void initState() {
		super.initState();
		_cargarMiembros();
	}

	Future<void> _cargarMiembros() async {
		final lote = widget.lote;
		if (lote == null || lote.productoIds.isEmpty) {
			setState(() => _cargando = false);
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final miembros = await servicio.nombresDeMiembrosPromocion(lote.productoIds);
		if (!mounted) {
			return;
		}
		setState(() {
			_miembros = miembros;
			_cargando = false;
		});
	}

	@override
	void dispose() {
		_nombreController.dispose();
		_cantidadController.dispose();
		_precioController.dispose();
		super.dispose();
	}

	Future<void> _agregarProductos() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final productos = await servicio.listarProductos();
		final yaAgregados = _miembros.map((m) => m.productoId).toSet();
		if (!mounted) {
			return;
		}
		final seleccion = await showDialog<List<Producto>>(
			context: context,
			builder: (_) => _DialogoSeleccionarProductos(
				productos: productos.where((p) => !yaAgregados.contains(p.id)).toList(),
			),
		);
		if (seleccion == null || seleccion.isEmpty) {
			return;
		}
		setState(() {
			_miembros = [
				..._miembros,
				...seleccion.map((p) => MiembroPromocion(productoId: p.id, nombre: p.nombre)),
			];
		});
	}

	Future<void> _sugerirPorFamilia() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final productos = await servicio.listarProductos();
		if (!mounted) {
			return;
		}
		final padre = await showDialog<Producto>(
			context: context,
			builder: (_) => _DialogoSeleccionarProductos(
				productos: productos,
				unaSelecicon: true,
				titulo: 'Elegir producto de la familia',
			),
		);
		if (padre == null) {
			return;
		}
		final sugeridos = await servicio.sugerirMiembrosDeFamilia(padre.id);
		if (!mounted) {
			return;
		}
		final yaAgregados = _miembros.map((m) => m.productoId).toSet();
		setState(() {
			_miembros = [
				..._miembros,
				...sugeridos.where((m) => !yaAgregados.contains(m.productoId)),
			];
		});
	}

	void _quitarMiembro(String productoId) {
		setState(() {
			_miembros = _miembros.where((m) => m.productoId != productoId).toList();
		});
	}

	Future<void> _guardar() async {
		final nombre = _nombreController.text.trim();
		final cantidad = double.tryParse(_cantidadController.text.trim());
		final precio = parsearPrecioTexto(_precioController.text);
		if (nombre.isEmpty) {
			_mostrarError('Ingrese un nombre');
			return;
		}
		if (cantidad == null || cantidad <= 0) {
			_mostrarError('Ingrese la cantidad mínima de piezas');
			return;
		}
		if (precio == null || precio <= 0) {
			_mostrarError('Ingrese el precio por pieza');
			return;
		}
		if (_miembros.length < 2) {
			_mostrarError('Agregue al menos 2 productos');
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarLotePromocion(
			id: widget.lote?.id,
			nombre: nombre,
			cantidadMinima: cantidad,
			precioUnitario: precio,
			productoIds: _miembros.map((m) => m.productoId).toList(),
		);
		if (mounted) {
			Navigator.pop(context, true);
		}
	}

	void _mostrarError(String mensaje) {
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text(mensaje), backgroundColor: PosiaColors.cancelar),
		);
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: Text(widget.lote == null ? 'Nuevo lote de mayoreo' : 'Editar lote'),
			content: SizedBox(
				width: 480.0,
				height: 520.0,
				child: _cargando
					? const Center(child: CircularProgressIndicator())
					: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							TextField(
								controller: _nombreController,
								decoration: const InputDecoration(
									labelText: 'Nombre',
									hintText: 'Ej. Sopas La Moderna',
								),
							),
							const SizedBox(height: 8.0),
							Row(
								children: [
									Expanded(
										child: TextField(
											controller: _cantidadController,
											keyboardType: TextInputType.number,
											decoration: const InputDecoration(
												labelText: 'Piezas mínimas',
												hintText: '20',
											),
										),
									),
									const SizedBox(width: 8.0),
									Expanded(
										child: TextField(
											controller: _precioController,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
											decoration: const InputDecoration(
												labelText: 'Precio c/u',
												hintText: '7.60',
											),
										),
									),
								],
							),
							const SizedBox(height: 12.0),
							Row(
								children: [
									Text(
										'Productos (${_miembros.length})',
										style: Theme.of(context).textTheme.titleSmall,
									),
									const Spacer(),
									TextButton.icon(
										onPressed: _sugerirPorFamilia,
										icon: const Icon(Icons.auto_awesome, size: 18.0),
										label: const Text('Por familia'),
									),
									TextButton.icon(
										onPressed: _agregarProductos,
										icon: const Icon(Icons.add, size: 18.0),
										label: const Text('Agregar'),
									),
								],
							),
							Expanded(
								child: _miembros.isEmpty
									? const Center(
										child: Text(
											'Sin productos. Use "Por familia" o "Agregar".',
											style: TextStyle(color: Colors.grey),
										),
									)
									: ListView.builder(
										itemCount: _miembros.length,
										itemBuilder: (context, i) {
											final m = _miembros[i];
											return ListTile(
												dense: true,
												title: Text(m.nombre),
												trailing: IconButton(
													icon: const Icon(Icons.close, size: 18.0),
													onPressed: () => _quitarMiembro(m.productoId),
												),
											);
										},
									),
							),
						],
					),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
				FilledButton(onPressed: _guardar, child: const Text('Guardar')),
			],
		);
	}
}

// ============================== COMBOS ==============================

class _VistaCombos extends ConsumerWidget {
	const _VistaCombos();

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final combosAsync = ref.watch(combosAdminProvider);
		return Scaffold(
			body: combosAsync.when(
				data: (combos) {
					if (combos.isEmpty) {
						return const Center(
							child: Text(
								'Sin combos.\n'
								'Ej: "Shampoo + acondicionador a precio de kit".',
								textAlign: TextAlign.center,
								style: TextStyle(color: Colors.grey),
							),
						);
					}
					return ListView.separated(
						padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 88.0),
						itemCount: combos.length,
						separatorBuilder: (_, _) => const Divider(height: 1.0),
						itemBuilder: (context, i) {
							final combo = combos[i];
							return ListTile(
								title: Text(
									combo.nombre,
									style: TextStyle(color: combo.activo ? null : Colors.grey),
								),
								subtitle: Text(
									'${formatearMoneda(combo.precioCombo)} el set · '
									'${combo.miembros.length} producto${combo.miembros.length == 1 ? '' : 's'}',
								),
								trailing: Switch(
									value: combo.activo,
									onChanged: (activo) => _cambiarActivo(context, ref, combo, activo),
								),
								onTap: () => _editarCombo(context, ref, combo),
							);
						},
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () => _editarCombo(context, ref, null),
				icon: const Icon(Icons.add),
				label: const Text('Nuevo combo'),
			),
		);
	}

	Future<void> _cambiarActivo(
		BuildContext context,
		WidgetRef ref,
		Combo combo,
		bool activo,
	) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		if (activo) {
			await servicio.guardarCombo(
				id: combo.id,
				nombre: combo.nombre,
				precioCombo: combo.precioCombo,
				miembros: combo.miembros,
				activo: true,
			);
		} else {
			await servicio.eliminarCombo(combo.id);
		}
		invalidarPromociones(ref);
	}

	Future<void> _editarCombo(BuildContext context, WidgetRef ref, Combo? combo) async {
		final guardado = await showDialog<bool>(
			context: context,
			builder: (_) => _DialogoCombo(combo: combo),
		);
		if (guardado == true) {
			invalidarPromociones(ref);
		}
	}
}

class _DialogoCombo extends ConsumerStatefulWidget {
	const _DialogoCombo({this.combo});

	final Combo? combo;

	@override
	ConsumerState<_DialogoCombo> createState() => _DialogoComboState();
}

class _DialogoComboState extends ConsumerState<_DialogoCombo> {
	late final _nombreController = TextEditingController(text: widget.combo?.nombre ?? '');
	late final _precioController = TextEditingController(
		text: widget.combo != null ? widget.combo!.precioCombo.toStringAsFixed(2) : '',
	);
	List<MiembroPromocion> _nombres = const [];
	List<ComboMiembro> _miembros = const [];
	bool _cargando = true;

	@override
	void initState() {
		super.initState();
		_miembros = widget.combo?.miembros ?? const [];
		_cargarNombres();
	}

	Future<void> _cargarNombres() async {
		if (_miembros.isEmpty) {
			setState(() => _cargando = false);
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final nombres = await servicio.nombresDeMiembrosPromocion(
			_miembros.map((m) => m.productoId).toList(),
		);
		if (!mounted) {
			return;
		}
		setState(() {
			_nombres = nombres;
			_cargando = false;
		});
	}

	@override
	void dispose() {
		_nombreController.dispose();
		_precioController.dispose();
		super.dispose();
	}

	String _nombreDe(String productoId) {
		return _nombres.firstWhere(
			(m) => m.productoId == productoId,
			orElse: () => MiembroPromocion(productoId: productoId, nombre: productoId),
		).nombre;
	}

	Future<void> _agregarProductos() async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final productos = await servicio.listarProductos();
		final yaAgregados = _miembros.map((m) => m.productoId).toSet();
		if (!mounted) {
			return;
		}
		final seleccion = await showDialog<List<Producto>>(
			context: context,
			builder: (_) => _DialogoSeleccionarProductos(
				productos: productos.where((p) => !yaAgregados.contains(p.id)).toList(),
			),
		);
		if (seleccion == null || seleccion.isEmpty) {
			return;
		}
		setState(() {
			_miembros = [
				..._miembros,
				...seleccion.map((p) => ComboMiembro(productoId: p.id)),
			];
			_nombres = [
				..._nombres,
				...seleccion.map((p) => MiembroPromocion(productoId: p.id, nombre: p.nombre)),
			];
		});
	}

	void _quitarMiembro(String productoId) {
		setState(() {
			_miembros = _miembros.where((m) => m.productoId != productoId).toList();
		});
	}

	void _cambiarCantidad(String productoId, double cantidad) {
		if (cantidad <= 0) {
			return;
		}
		setState(() {
			_miembros = _miembros
				.map((m) => m.productoId == productoId ? m.copiarCon(cantidadRequerida: cantidad) : m)
				.toList();
		});
	}

	Future<void> _guardar() async {
		final nombre = _nombreController.text.trim();
		final precio = parsearPrecioTexto(_precioController.text);
		if (nombre.isEmpty) {
			_mostrarError('Ingrese un nombre');
			return;
		}
		if (precio == null || precio <= 0) {
			_mostrarError('Ingrese el precio del combo');
			return;
		}
		if (_miembros.length < 2) {
			_mostrarError('Agregue al menos 2 productos');
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarCombo(
			id: widget.combo?.id,
			nombre: nombre,
			precioCombo: precio,
			miembros: _miembros,
		);
		if (mounted) {
			Navigator.pop(context, true);
		}
	}

	void _mostrarError(String mensaje) {
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text(mensaje), backgroundColor: PosiaColors.cancelar),
		);
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: Text(widget.combo == null ? 'Nuevo combo' : 'Editar combo'),
			content: SizedBox(
				width: 480.0,
				height: 520.0,
				child: _cargando
					? const Center(child: CircularProgressIndicator())
					: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							TextField(
								controller: _nombreController,
								decoration: const InputDecoration(
									labelText: 'Nombre',
									hintText: 'Ej. Kit shampoo + acondicionador',
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _precioController,
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								decoration: const InputDecoration(
									labelText: 'Precio total del combo',
									hintText: '150.00',
								),
							),
							const SizedBox(height: 12.0),
							Row(
								children: [
									Text(
										'Productos requeridos (${_miembros.length})',
										style: Theme.of(context).textTheme.titleSmall,
									),
									const Spacer(),
									TextButton.icon(
										onPressed: _agregarProductos,
										icon: const Icon(Icons.add, size: 18.0),
										label: const Text('Agregar'),
									),
								],
							),
							Expanded(
								child: _miembros.isEmpty
									? const Center(
										child: Text(
											'Sin productos. Use "Agregar".',
											style: TextStyle(color: Colors.grey),
										),
									)
									: ListView.builder(
										itemCount: _miembros.length,
										itemBuilder: (context, i) {
											final m = _miembros[i];
											return ListTile(
												dense: true,
												title: Text(_nombreDe(m.productoId)),
												subtitle: Text('Cantidad requerida: ${m.cantidadRequerida.toStringAsFixed(0)}'),
												trailing: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														IconButton(
															icon: const Icon(Icons.remove, size: 18.0),
															onPressed: () => _cambiarCantidad(
																m.productoId,
																m.cantidadRequerida - 1,
															),
														),
														IconButton(
															icon: const Icon(Icons.add, size: 18.0),
															onPressed: () => _cambiarCantidad(
																m.productoId,
																m.cantidadRequerida + 1,
															),
														),
														IconButton(
															icon: const Icon(Icons.close, size: 18.0),
															onPressed: () => _quitarMiembro(m.productoId),
														),
													],
												),
											);
										},
									),
							),
						],
					),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
				FilledButton(onPressed: _guardar, child: const Text('Guardar')),
			],
		);
	}
}

// ==================== PICKER COMPARTIDO DE PRODUCTOS ====================

/// Selector de productos por busqueda; multi-seleccion por defecto.
///
/// Con [unaSelecicon] retorna un solo `Producto` (usado para elegir el
/// producto padre al sugerir miembros por familia); si no, retorna
/// `List<Producto>` con la seleccion.
class _DialogoSeleccionarProductos extends StatefulWidget {
	const _DialogoSeleccionarProductos({
		required this.productos,
		this.unaSelecicon = false,
		this.titulo = 'Seleccionar productos',
	});

	final List<Producto> productos;
	final bool unaSelecicon;
	final String titulo;

	@override
	State<_DialogoSeleccionarProductos> createState() => _DialogoSeleccionarProductosState();
}

class _DialogoSeleccionarProductosState extends State<_DialogoSeleccionarProductos> {
	final _busquedaController = TextEditingController();
	final Set<String> _seleccionados = {};
	String _filtro = '';

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	List<Producto> get _filtrados {
		final activos = widget.productos.where((p) => p.activo).toList()
			..sort((a, b) => a.nombre.compareTo(b.nombre));
		if (_filtro.isEmpty) {
			return activos;
		}
		final q = _filtro.toLowerCase();
		return activos
			.where(
				(p) =>
					p.nombre.toLowerCase().contains(q) ||
					p.codigoBarras.toLowerCase().contains(q),
			)
			.toList();
	}

	void _tocar(Producto producto) {
		if (widget.unaSelecicon) {
			Navigator.pop(context, producto);
			return;
		}
		setState(() {
			if (_seleccionados.contains(producto.id)) {
				_seleccionados.remove(producto.id);
			} else {
				_seleccionados.add(producto.id);
			}
		});
	}

	void _confirmar() {
		final elegidos = widget.productos.where((p) => _seleccionados.contains(p.id)).toList();
		Navigator.pop(context, elegidos);
	}

	@override
	Widget build(BuildContext context) {
		final filtrados = _filtrados;
		return AlertDialog(
			title: Text(widget.titulo),
			content: SizedBox(
				width: 480.0,
				height: 480.0,
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						CampoBusqueda(
							padding: EdgeInsets.zero,
							autofocus: true,
							controlador: _busquedaController,
							sugerencia: 'Buscar por nombre o código',
							alCambiar: (v) => setState(() => _filtro = v.trim()),
						),
						const SizedBox(height: 8.0),
						Expanded(
							child: filtrados.isEmpty
								? const Center(child: Text('Sin coincidencias'))
								: ListView.separated(
									itemCount: filtrados.length,
									separatorBuilder: (_, _) => const Divider(height: 1.0),
									itemBuilder: (_, i) {
										final p = filtrados[i];
										final seleccionado = _seleccionados.contains(p.id);
										return ListTile(
											selected: seleccionado,
											leading: widget.unaSelecicon
												? null
												: Checkbox(
													value: seleccionado,
													onChanged: (_) => _tocar(p),
												),
											title: Text(p.nombre),
											subtitle: Text(
												p.codigoBarras.isNotEmpty
													? '${formatearMoneda(p.precioBase)} · ${p.codigoBarras}'
													: formatearMoneda(p.precioBase),
											),
											onTap: () => _tocar(p),
										);
									},
								),
						),
					],
				),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
				if (!widget.unaSelecicon)
					FilledButton(
						onPressed: _seleccionados.isEmpty ? null : _confirmar,
						child: Text('Agregar (${_seleccionados.length})'),
					),
			],
		);
	}
}
