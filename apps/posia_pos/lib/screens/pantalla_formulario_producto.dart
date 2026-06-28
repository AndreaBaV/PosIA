/// Formulario completo de alta/edicion de producto con pestañas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../widgets/panel_empaques_producto.dart';

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
	final _costoController = TextEditingController(text: '0');
	final _notasController = TextEditingController();
	final _stockController = TextEditingController(text: '0');
	final _minimoController = TextEditingController(text: '0');
	String? _categoriaId;
	UnidadMedida _unidad = UnidadMedida.pieza;
	String? _proveedorId;
	bool _activo = true;
	bool _permiteStockNegativo = false;
	final _escalas = <_EscalaEditable>[];
	List<EmpaqueProductoDraft> _empaquesPendientes = [];
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
			_costoController.text = p.costoUnitario.toStringAsFixed(2);
			_notasController.text = p.notas;
			_categoriaId = p.categoriaId;
			_unidad = p.unidadMedida;
			_proveedorId = p.proveedorId;
			_activo = p.activo;
			_permiteStockNegativo = p.permiteStockNegativo;
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
		_costoController.dispose();
		_notasController.dispose();
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
					isScrollable: true,
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
					final categoriasActivas = categorias.where((c) => c.activa);
					_categoriaId ??= categoriasActivas.firstOrNull?.id;
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
		final costo = parsearPrecioTexto(_costoController.text) ?? 0.0;
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				TextField(
					controller: _costoController,
					keyboardType: const TextInputType.numberWithOptions(decimal: true),
					decoration: const InputDecoration(
						labelText: 'Costo de compra (MXN)',
						border: OutlineInputBorder(),
						prefixText: '\$ ',
						helperText: 'Precio al que compra el producto al proveedor',
					),
					onChanged: (_) => setState(() {}),
				),
				const SizedBox(height: 12.0),
				CampoPrecioVenta(
					controller: _precioController,
					costoUnitario: costo,
					labelText: 'Precio menudeo (MXN) *',
					onChanged: (_) => setState(() {}),
				),
				const SizedBox(height: 12.0),
				PanelCalculoUtilidad(
					costoUnitario: costo,
					precioController: _precioController,
					alCambiarPrecio: () => setState(() {}),
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
										child: CampoPrecioVenta(
											controller: escala.precioController,
											costoUnitario: costo,
											labelText: 'Precio unit.',
											isDense: true,
											prefixText: r'$ ',
											obligatorio: false,
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
		final costo = parsearPrecioTexto(_costoController.text) ??
			widget.productoExistente?.costoUnitario ??
			0.0;
		final precio = parsearPrecioTexto(_precioController.text) ??
			widget.productoExistente?.precioBase ??
			0.0;
		return PanelEmpaquesProducto(
			productoId: widget.productoExistente?.id,
			costoUnitario: costo,
			precioMenudeo: precio,
			unidadMedida: _unidad,
			empaquesPendientes: _empaquesPendientes,
			alCambiarEmpaquesPendientes: (lista) =>
				setState(() => _empaquesPendientes = lista),
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
				const SizedBox(height: 12.0),
				SwitchListTile(
					title: const Text('Permitir stock negativo'),
					subtitle: const Text('Vender aunque no haya existencia'),
					value: _permiteStockNegativo,
					onChanged: (v) => setState(() => _permiteStockNegativo = v),
				),
			],
		);
	}

	List<EscalaMayoreo> _parseEscalas(String productoId) {
		return _escalas
			.map((e) {
				final cant = parsearPrecioTexto(e.cantidadController.text) ?? 0.0;
				final precio = parsearPrecioTexto(e.precioController.text) ?? 0.0;
				return EscalaMayoreo(
					productoId: productoId,
					cantidadMinima: cant,
					precioUnitario: precio,
				);
			})
			.where((e) => e.cantidadMinima > 0.0 && e.precioUnitario > 0.0)
			.toList();
	}

	Future<({int? piezasPorCaja, int? unidadesPorBulto})> _resolverEmpaqueLegacy(
		ServicioAdmin servicio,
	) async {
		final tipos = await servicio.listarTiposPresentacion();
		if (_esEdicion) {
			final presentaciones = await servicio.listarPresentacionesProducto(
				widget.productoExistente!.id,
			);
			return derivarEmpaqueLegacy(
				presentaciones: presentaciones,
				tipos: tipos,
			);
		}
		final simuladas = _empaquesPendientes
			.map(
				(e) => PresentacionProducto(
					id: '',
					productoId: '',
					tipoPresentacionId: e.tipoPresentacionId,
					nombre: e.nombre,
					factorABase: e.factorABase,
					esPresentacionBase: false,
					codigoBarras: e.codigoBarras,
					precio: e.precio,
					activo: true,
				),
			)
			.toList();
		return derivarEmpaqueLegacy(presentaciones: simuladas, tipos: tipos);
	}

	Future<void> _guardar(List<Categoria> categorias) async {
		final nombre = _nombreController.text.trim();
		final categoriaValida = _categoriaId != null &&
			categorias.any((c) => c.activa && c.id == _categoriaId);
		if (nombre.isEmpty || !categoriaValida) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Nombre y categoría son obligatorios'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		final costo = parsearPrecioTexto(_costoController.text) ?? 0.0;
		final errorMenudeo = errorPrecioVentaDesdeTexto(
			_precioController.text,
			costoUnitario: costo,
		);
		if (errorMenudeo != null) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(errorMenudeo),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		for (final escala in _escalas) {
			if (escala.precioController.text.trim().isEmpty) {
				continue;
			}
			final errorEscala = errorPrecioVentaDesdeTexto(
				escala.precioController.text,
				costoUnitario: costo,
			);
			if (errorEscala != null) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Mayoreo: $errorEscala'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
		}
		setState(() => _guardando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final precio = parsearPrecioTexto(_precioController.text) ?? 0.0;
			final empaqueLegacy = await _resolverEmpaqueLegacy(servicio);
			if (_esEdicion) {
				final base = widget.productoExistente!;
				final actualizado = base.copiarCon(
					nombre: nombre,
					codigoBarras: _codigoController.text.trim(),
					precioBase: precio,
					costoUnitario: costo,
					categoriaId: _categoriaId,
					unidadMedida: _unidad,
					piezasPorCaja: empaqueLegacy.piezasPorCaja,
					unidadesPorBulto: empaqueLegacy.unidadesPorBulto,
					proveedorId: _proveedorId,
					notas: _notasController.text.trim(),
					activo: _activo,
					permiteStockNegativo: _permiteStockNegativo,
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
						final cant = parsearPrecioTexto(e.cantidadController.text) ?? 0.0;
						final precioE = parsearPrecioTexto(e.precioController.text) ?? 0.0;
						return EscalaMayoreo(
							productoId: '',
							cantidadMinima: cant,
							precioUnitario: precioE,
						);
					})
					.where((e) => e.cantidadMinima > 0.0 && e.precioUnitario > 0.0)
					.toList();
				final legacyAlta = _empaquesPendientes.isNotEmpty
					? (piezasPorCaja: null, unidadesPorBulto: null)
					: empaqueLegacy;
				final producto = await servicio.registrarProductoCompleto(
					AltaProductoRequest(
						nombre: nombre,
						codigoBarras: _codigoController.text.trim(),
						precioBase: precio,
						costoUnitario: costo,
						categoriaId: _categoriaId!,
						unidadMedida: _unidad,
						piezasPorCaja: legacyAlta.piezasPorCaja,
						unidadesPorBulto: legacyAlta.unidadesPorBulto,
						proveedorId: _proveedorId,
						notas: _notasController.text.trim(),
						activo: _activo,
						stockInicial: double.tryParse(_stockController.text) ?? 0.0,
						stockMinimo: double.tryParse(_minimoController.text) ?? 0.0,
						escalasMayoreo: escalasNuevas,
						permiteStockNegativo: _permiteStockNegativo,
					),
				);
				if (_empaquesPendientes.isNotEmpty) {
					await guardarEmpaquesPendientes(
						servicio: servicio,
						productoId: producto.id,
						empaques: _empaquesPendientes,
					);
					await servicio.actualizarProducto(
						producto.copiarCon(
							piezasPorCaja: empaqueLegacy.piezasPorCaja,
							unidadesPorBulto: empaqueLegacy.unidadesPorBulto,
						),
					);
				}
			}
			await refrescarDatosMaestros(ref);
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
