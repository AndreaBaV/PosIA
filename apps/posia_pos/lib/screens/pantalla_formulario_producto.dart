/// Formulario completo de alta/edicion de producto con pestañas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class PantallaFormularioProducto extends ConsumerStatefulWidget {
	const PantallaFormularioProducto({this.productoExistente, super.key});

	final Producto? productoExistente;

	@override
	ConsumerState<PantallaFormularioProducto> createState() =>
		_PantallaFormularioProductoState();
}

class _PantallaFormularioProductoState extends ConsumerState<PantallaFormularioProducto>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	final _nombreController = TextEditingController();
	final _codigoController = TextEditingController();
	final _precioController = TextEditingController();
	final _notasController = TextEditingController();
	final _piezasCajaController = TextEditingController();
	final _bultoController = TextEditingController();
	final _stockController = TextEditingController(text: '0');
	final _minimoController = TextEditingController(text: '0');
	String? _categoriaId;
	UnidadMedida _unidad = UnidadMedida.pieza;
	String? _proveedorId;
	bool _activo = true;
	final _escalas = <_EscalaEditable>[];
	bool _guardando = false;

	bool get _esEdicion => widget.productoExistente != null;

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 4, vsync: this);
		final p = widget.productoExistente;
		if (p != null) {
			_nombreController.text = p.nombre;
			_codigoController.text = p.codigoBarras;
			_precioController.text = p.precioBase.toStringAsFixed(2);
			_notasController.text = p.notas;
			_categoriaId = p.categoriaId;
			_unidad = p.unidadMedida;
			_proveedorId = p.proveedorId;
			_activo = p.activo;
			if (p.piezasPorCaja != null) {
				_piezasCajaController.text = '${p.piezasPorCaja}';
			}
			if (p.unidadesPorBulto != null) {
				_bultoController.text = '${p.unidadesPorBulto}';
			}
			WidgetsBinding.instance.addPostFrameCallback((_) {
				_cargarEscalas(p.id);
				_cargarStock(p.id);
			});
		}
	}

	Future<void> _cargarStock(String productoId) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final inventario = await servicio.obtenerInventarioConsolidado();
		for (final reg in inventario) {
			if (reg.productoId == productoId && reg.tiendaId == servicio.tiendaActivaId) {
				if (!mounted) {
					return;
				}
				setState(() {
					_minimoController.text = reg.stockMinimo.toStringAsFixed(0);
					_stockController.text = reg.cantidad.toStringAsFixed(0);
				});
				break;
			}
		}
	}

	Future<void> _cargarEscalas(String productoId) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final escalas = await servicio.listarEscalasMayoreo(productoId);
		if (!mounted) {
			return;
		}
		setState(() {
			_escalas.clear();
			for (final e in escalas) {
				_escalas.add(
					_EscalaEditable(
						cantidadController: TextEditingController(
							text: e.cantidadMinima.toStringAsFixed(0),
						),
						precioController: TextEditingController(
							text: e.precioUnitario.toStringAsFixed(2),
						),
					),
				);
			}
		});
	}

	@override
	void dispose() {
		_tabs.dispose();
		_nombreController.dispose();
		_codigoController.dispose();
		_precioController.dispose();
		_notasController.dispose();
		_piezasCajaController.dispose();
		_bultoController.dispose();
		_stockController.dispose();
		_minimoController.dispose();
		for (final e in _escalas) {
			e.dispose();
		}
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final categoriasAsync = ref.watch(_categoriasFormProvider);
		final proveedoresAsync = ref.watch(_proveedoresFormProvider);
		return Scaffold(
			appBar: AppBar(
				title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
				bottom: TabBar(
					controller: _tabs,
					tabs: const [
						Tab(text: 'General'),
						Tab(text: 'Precios'),
						Tab(text: 'Empaque'),
						Tab(text: 'Inventario'),
					],
				),
			),
			body: categoriasAsync.when(
				data: (categorias) {
					_categoriaId ??= categorias.firstOrNull?.id;
					return TabBarView(
						controller: _tabs,
						children: [
							_pestanaGeneral(categorias, proveedoresAsync),
							_pestanaPrecios(),
							_pestanaEmpaque(),
							_pestanaInventario(),
						],
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
			bottomNavigationBar: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(16.0),
					child: FilledButton.icon(
						onPressed: _guardando ? null : () => _guardar(categoriasAsync.value ?? []),
						icon: _guardando
							? const SizedBox(
								width: 18.0,
								height: 18.0,
								child: CircularProgressIndicator(strokeWidth: 2.0),
							)
							: const Icon(Icons.save),
						label: Text(_guardando ? 'Guardando...' : 'Guardar producto'),
					),
				),
			),
		);
	}

	Widget _pestanaGeneral(List<Categoria> categorias, AsyncValue<List<Proveedor>> proveedores) {
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				TextField(
					controller: _nombreController,
					decoration: const InputDecoration(
						labelText: 'Nombre *',
						border: OutlineInputBorder(),
					),
				),
				const SizedBox(height: 12.0),
				TextField(
					controller: _codigoController,
					decoration: const InputDecoration(
						labelText: 'Código de barras',
						border: OutlineInputBorder(),
					),
				),
				const SizedBox(height: 12.0),
				DropdownButtonFormField<String>(
					initialValue: _categoriaId,
					items: categorias
						.where((c) => c.activa)
						.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
						.toList(),
					onChanged: (v) => setState(() => _categoriaId = v),
					decoration: const InputDecoration(
						labelText: 'Categoría *',
						border: OutlineInputBorder(),
					),
				),
				const SizedBox(height: 12.0),
				DropdownButtonFormField<UnidadMedida>(
					initialValue: _unidad,
					items: UnidadMedida.values
						.map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
						.toList(),
					onChanged: (v) => setState(() => _unidad = v ?? UnidadMedida.pieza),
					decoration: const InputDecoration(
						labelText: 'Unidad de venta',
						border: OutlineInputBorder(),
					),
				),
				const SizedBox(height: 12.0),
				proveedores.when(
					data: (lista) => DropdownButtonFormField<String?>(
						initialValue: _proveedorId,
						items: [
							const DropdownMenuItem(value: null, child: Text('Sin proveedor')),
							...lista.map(
								(p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)),
							),
						],
						onChanged: (v) => setState(() => _proveedorId = v),
						decoration: const InputDecoration(
							labelText: 'Proveedor',
							border: OutlineInputBorder(),
						),
					),
					loading: () => const LinearProgressIndicator(),
					error: (e, _) => Text('$e'),
				),
				const SizedBox(height: 12.0),
				TextField(
					controller: _notasController,
					maxLines: 2,
					decoration: const InputDecoration(
						labelText: 'Notas',
						border: OutlineInputBorder(),
					),
				),
				SwitchListTile(
					title: const Text('Producto activo'),
					value: _activo,
					onChanged: (v) => setState(() => _activo = v),
				),
			],
		);
	}

	Widget _pestanaPrecios() {
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				TextField(
					controller: _precioController,
					keyboardType: TextInputType.number,
					decoration: const InputDecoration(
						labelText: 'Precio menudeo (MXN) *',
						border: OutlineInputBorder(),
						prefixText: '\$ ',
					),
				),
				const SizedBox(height: 16.0),
				Row(
					mainAxisAlignment: MainAxisAlignment.spaceBetween,
					children: [
						const Text('Escalas de mayoreo', style: TextStyle(fontWeight: FontWeight.bold)),
						TextButton.icon(
							onPressed: () => setState(
								() => _escalas.add(_EscalaEditable.vacia()),
							),
							icon: const Icon(Icons.add),
							label: const Text('Agregar'),
						),
					],
				),
				..._escalas.asMap().entries.map((entry) {
					final i = entry.key;
					final escala = entry.value;
					return Card(
						child: Padding(
							padding: const EdgeInsets.all(8.0),
							child: Row(
								children: [
									Expanded(
										child: TextField(
											controller: escala.cantidadController,
											keyboardType: TextInputType.number,
											decoration: const InputDecoration(
												labelText: 'Cant. mínima',
												isDense: true,
											),
										),
									),
									const SizedBox(width: 8.0),
									Expanded(
										child: TextField(
											controller: escala.precioController,
											keyboardType: TextInputType.number,
											decoration: const InputDecoration(
												labelText: 'Precio unit.',
												isDense: true,
											),
										),
									),
									IconButton(
										icon: const Icon(Icons.delete, color: PosiaColors.cancelar),
										onPressed: () => setState(() {
											escala.dispose();
											_escalas.removeAt(i);
										}),
									),
								],
							),
						),
					);
				}),
			],
		);
	}

	Widget _pestanaEmpaque() {
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				const Text(
					'Conversiones de empaque para venta por caja o bulto.',
					style: TextStyle(color: Colors.grey),
				),
				const SizedBox(height: 16.0),
				TextField(
					controller: _piezasCajaController,
					keyboardType: TextInputType.number,
					decoration: const InputDecoration(
						labelText: 'Piezas por caja',
						border: OutlineInputBorder(),
						helperText: 'Ej. 12 leches = 1 caja',
					),
				),
				const SizedBox(height: 12.0),
				TextField(
					controller: _bultoController,
					keyboardType: TextInputType.number,
					decoration: const InputDecoration(
						labelText: 'Unidades por bulto',
						border: OutlineInputBorder(),
						helperText: 'Ej. 144 unidades = 1 bulto',
					),
				),
			],
		);
	}

	Widget _pestanaInventario() {
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				if (_esEdicion)
					const ListTile(
						leading: Icon(Icons.info_outline),
						title: Text('Stock inicial solo aplica al crear producto'),
					)
				else ...[
					TextField(
						controller: _stockController,
						keyboardType: TextInputType.number,
						decoration: const InputDecoration(
							labelText: 'Stock inicial',
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 12.0),
				],
				TextField(
					controller: _minimoController,
					keyboardType: TextInputType.number,
					decoration: const InputDecoration(
						labelText: 'Stock mínimo (alerta)',
						border: OutlineInputBorder(),
					),
				),
			],
		);
	}

	List<EscalaMayoreo> _parseEscalas(String productoId) {
		return _escalas
			.map((e) {
				final cant = double.tryParse(e.cantidadController.text) ?? 0.0;
				final precio = double.tryParse(e.precioController.text) ?? 0.0;
				return EscalaMayoreo(
					productoId: productoId,
					cantidadMinima: cant,
					precioUnitario: precio,
				);
			})
			.where((e) => e.cantidadMinima > 0.0 && e.precioUnitario > 0.0)
			.toList();
	}

	int? _parseInt(String texto) {
		final v = int.tryParse(texto.trim());
		return v == null || v <= 0 ? null : v;
	}

	Future<void> _guardar(List<Categoria> categorias) async {
		final nombre = _nombreController.text.trim();
		if (nombre.isEmpty || _categoriaId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Nombre y categoría son obligatorios'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		setState(() => _guardando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final precio = double.tryParse(_precioController.text) ?? 0.0;
			if (_esEdicion) {
				final base = widget.productoExistente!;
				final actualizado = base.copiarCon(
					nombre: nombre,
					codigoBarras: _codigoController.text.trim(),
					precioBase: precio,
					categoriaId: _categoriaId,
					unidadMedida: _unidad,
					piezasPorCaja: _parseInt(_piezasCajaController.text),
					unidadesPorBulto: _parseInt(_bultoController.text),
					proveedorId: _proveedorId,
					notas: _notasController.text.trim(),
					activo: _activo,
				);
				await servicio.actualizarProducto(
					actualizado,
					escalasMayoreo: _parseEscalas(actualizado.id),
				);
				final minimo = double.tryParse(_minimoController.text) ?? 0.0;
				await servicio.configurarStockMinimo(actualizado.id, minimo);
			} else {
				final escalasNuevas = _escalas
					.map((e) {
						final cant = double.tryParse(e.cantidadController.text) ?? 0.0;
						final precioE = double.tryParse(e.precioController.text) ?? 0.0;
						return EscalaMayoreo(
							productoId: '',
							cantidadMinima: cant,
							precioUnitario: precioE,
						);
					})
					.where((e) => e.cantidadMinima > 0.0 && e.precioUnitario > 0.0)
					.toList();
				await servicio.registrarProductoCompleto(
					AltaProductoRequest(
						nombre: nombre,
						codigoBarras: _codigoController.text.trim(),
						precioBase: precio,
						categoriaId: _categoriaId!,
						unidadMedida: _unidad,
						piezasPorCaja: _parseInt(_piezasCajaController.text),
						unidadesPorBulto: _parseInt(_bultoController.text),
						proveedorId: _proveedorId,
						notas: _notasController.text.trim(),
						activo: _activo,
						stockInicial: double.tryParse(_stockController.text) ?? 0.0,
						stockMinimo: double.tryParse(_minimoController.text) ?? 0.0,
						escalasMayoreo: escalasNuevas,
					),
				);
			}
			ref.invalidate(contenedorServiciosProvider);
			if (!mounted) {
				return;
			}
			Navigator.pop(context, true);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _guardando = false);
			}
		}
	}
}

class _EscalaEditable {
	_EscalaEditable({
		required this.cantidadController,
		required this.precioController,
	});

	factory _EscalaEditable.vacia() {
		return _EscalaEditable(
			cantidadController: TextEditingController(),
			precioController: TextEditingController(),
		);
	}

	final TextEditingController cantidadController;
	final TextEditingController precioController;

	void dispose() {
		cantidadController.dispose();
		precioController.dispose();
	}
}

final _categoriasFormProvider = FutureProvider<List<Categoria>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCategorias();
});

final _proveedoresFormProvider = FutureProvider<List<Proveedor>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProveedores();
});
