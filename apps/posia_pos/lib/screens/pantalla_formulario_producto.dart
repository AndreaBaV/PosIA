/// Formulario completo de alta/edicion de producto con pestañas.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:posia_voice/posia_voice.dart';

import '../providers/admin_providers.dart';
import '../voz/servicio_voz_dispositivo.dart';
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
	final _precioMedioController = TextEditingController();
	final _precioCuartoController = TextEditingController();
	List<EmpaqueProductoDraft> _empaquesPendientes = [];
	bool _guardando = false;
	final _interpretadorVoz = InterpretadorAltaProductoVoz();
	final _servicioVoz = ServicioVozDispositivo();
	bool _escuchandoVoz = false;
	bool _vozInicializada = false;
	bool _finalizandoVoz = false;
	String _transcripcionVoz = '';

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
			if (_vendePorPeso) {
				final cortes = extraerPreciosCorteDesdeEscalas(
					escalas: escalas.map(
						(e) => (
							cantidadMinima: e.cantidadMinima,
							precioUnitario: e.precioUnitario,
						),
					),
					precioBase: parsearPrecioTexto(_precioController.text) ??
						widget.productoExistente?.precioBase ??
						0.0,
				);
				if (cortes.precioKilo != null && cortes.precioKilo! > 0.0) {
					_precioController.text = cortes.precioKilo!.toStringAsFixed(2);
				}
				_precioMedioController.text = cortes.precioMedio != null
					? cortes.precioMedio!.toStringAsFixed(2)
					: '';
				_precioCuartoController.text = cortes.precioCuarto != null
					? cortes.precioCuarto!.toStringAsFixed(2)
					: '';
				return;
			}
			for (final e in escalas) {
				_escalas.add(
					_EscalaEditable(
						cantidadController: TextEditingController(
							text: _formatearCantidadEscala(e.cantidadMinima),
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
		unawaited(_servicioVoz.detener());
		_tabs.dispose();
		_nombreController.dispose();
		_codigoController.dispose();
		_precioController.dispose();
		_costoController.dispose();
		_notasController.dispose();
		_stockController.dispose();
		_minimoController.dispose();
		_precioMedioController.dispose();
		_precioCuartoController.dispose();
		for (final e in _escalas) {
			e.dispose();
		}
		super.dispose();
	}

	bool get _vendePorPeso => _unidad == UnidadMedida.kilogramo;

	String _formatearCantidadEscala(double cantidad) {
		if (cantidad == cantidad.roundToDouble()) {
			return cantidad.toStringAsFixed(0);
		}
		return cantidad
			.toStringAsFixed(3)
			.replaceAll(RegExp(r'0+$'), '')
			.replaceAll(RegExp(r'\.$'), '');
	}

	Widget _buildSeccionEscalas(double costo) {
		if (_vendePorPeso) {
			return _buildSeccionPreciosPorPeso(costo);
		}
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					mainAxisAlignment: MainAxisAlignment.spaceBetween,
					children: [
						const Text(
							'Escalas de mayoreo',
							style: TextStyle(fontWeight: FontWeight.bold),
						),
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
					final cantidad =
						parsearPrecioTexto(escala.cantidadController.text) ?? -1.0;
					final precioE =
						parsearPrecioTexto(escala.precioController.text) ?? 0.0;
					return Card(
						child: Padding(
							padding: const EdgeInsets.all(8.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
											Expanded(
												child: TextField(
													controller: escala.cantidadController,
													keyboardType:
														const TextInputType.numberWithOptions(
														decimal: true,
													),
													decoration: const InputDecoration(
														labelText: 'Cant. mínima',
														isDense: true,
													),
													onChanged: (_) => setState(() {}),
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
													onChanged: (_) => setState(() {}),
												),
											),
											IconButton(
												icon: const Icon(
													Icons.delete,
													color: PosiaColors.cancelar,
												),
												onPressed: () => setState(() {
													escala.dispose();
													_escalas.removeAt(i);
												}),
											),
										],
									),
									if (cantidad >= 0.0 && precioE > 0.0)
										Padding(
											padding: const EdgeInsets.only(left: 4.0, top: 4.0),
											child: Text(
												describirTramoPrecio(
													cantidadMinima: cantidad,
													precioUnitario: precioE,
													unidadMedida: _unidad,
												),
												style: TextStyle(
													color: Colors.grey.shade600,
													fontSize: 12.0,
												),
											),
										),
								],
							),
						),
					);
				}),
			],
		);
	}

	Widget _buildSeccionPreciosPorPeso(double costo) {
		final precioKilo = parsearPrecioTexto(_precioController.text) ?? 0.0;
		final precioMedio = parsearPrecioTexto(_precioMedioController.text);
		final precioCuarto = parsearPrecioTexto(_precioCuartoController.text);
		final vistaPrevia = precioKilo > 0.0
			? describirVistaPreviaPreciosPeso(
					precioKilo: precioKilo,
					precioMedio: precioMedio,
					precioCuarto: precioCuarto,
				)
			: '';
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				const Text(
					'Precios por fracción (opcional)',
					style: TextStyle(fontWeight: FontWeight.bold),
				),
				const SizedBox(height: 8.0),
				Text(
					'Capture lo que paga el cliente por cada corte, no el precio por kg. '
					'Ejemplo: kilo \$30, medio kilo \$20, cuarto \$22.',
					style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0),
				),
				const SizedBox(height: 12.0),
				CampoPrecioVenta(
					controller: _precioMedioController,
					costoUnitario: costo > 0.0 ? redondearMonto(costo * pesoMedioKilo) : 0.0,
					labelText: 'Precio del medio kilo (lo que paga el cliente)',
					obligatorio: false,
					onChanged: (_) => setState(() {}),
				),
				const SizedBox(height: 12.0),
				CampoPrecioVenta(
					controller: _precioCuartoController,
					costoUnitario:
						costo > 0.0 ? redondearMonto(costo * pesoCuartoKilo) : 0.0,
					labelText: 'Precio del cuarto de kilo (lo que paga el cliente)',
					obligatorio: false,
					onChanged: (_) => setState(() {}),
				),
				if (vistaPrevia.isNotEmpty) ...[
					const SizedBox(height: 12.0),
					Container(
						width: double.infinity,
						padding: const EdgeInsets.all(12.0),
						decoration: BoxDecoration(
							color: Colors.grey.shade100,
							borderRadius: BorderRadius.circular(8.0),
							border: Border.all(color: Colors.grey.shade300),
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									'Al vender en caja se cobrará:',
									style: TextStyle(
										fontWeight: FontWeight.w600,
										color: Colors.grey.shade800,
									),
								),
								const SizedBox(height: 6.0),
								Text(
									vistaPrevia,
									style: TextStyle(
										color: Colors.grey.shade700,
										height: 1.4,
									),
								),
							],
						),
					),
				],
			],
		);
	}

	@override
	Widget build(BuildContext context) {
		final categoriasAsync = ref.watch(categoriasFormularioAdminProvider);
		final proveedoresAsync = ref.watch(proveedoresFormularioAdminProvider);
		return Scaffold(
			appBar: AppBar(
				title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
				actions: [
					IconButton(
						tooltip: 'Cómo dictar un producto',
						onPressed: _mostrarAyudaVoz,
						icon: const Icon(Icons.help_outline),
					),
					IconButton(
						tooltip: _escuchandoVoz
							? 'Detener dictado'
							: 'Dictar producto por voz',
						onPressed: _guardando ? null : _alternarEscuchaVoz,
						icon: Icon(
							_escuchandoVoz ? Icons.mic : Icons.mic_none,
							color: _escuchandoVoz ? PosiaColors.cobrar : null,
						),
					),
				],
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
			body: Stack(
				children: [
					categoriasAsync.when(
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
					if (_escuchandoVoz) _overlayVoz(context),
				],
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

	Widget _overlayVoz(BuildContext context) {
		return Positioned(
			left: 12.0,
			right: 12.0,
			bottom: 12.0,
			child: Material(
				elevation: 8.0,
				borderRadius: BorderRadius.circular(16.0),
				color: Theme.of(context).colorScheme.surface,
				child: Padding(
					padding: const EdgeInsets.all(14.0),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Icon(Icons.mic, color: PosiaColors.cobrar),
									const SizedBox(width: 8.0),
									const Expanded(
										child: Text(
											'Dicta el producto — nombre, precio, costo…',
											style: TextStyle(fontWeight: FontWeight.w600),
										),
									),
									TextButton(
										onPressed: _finalizarEscuchaVoz,
										child: const Text('Listo'),
									),
								],
							),
							if (_transcripcionVoz.isNotEmpty) ...[
								const SizedBox(height: 8.0),
								Text(
									_transcripcionVoz,
									maxLines: 4,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										color: Colors.grey.shade700,
										fontSize: 13.0,
									),
								),
							],
						],
					),
				),
			),
		);
	}

	Widget _pestanaGeneral(List<Categoria> categorias, AsyncValue<List<Proveedor>> proveedores) {
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				Card(
					color: Colors.blueGrey.shade50,
					child: const ListTile(
						leading: Icon(Icons.mic),
						title: Text('Dictado por voz'),
						subtitle: Text(
							'Toca el micrófono arriba. Ejemplo: '
							'"Jitomate por kilo a 35 pesos categoría verdura stock 10"',
						),
					),
				),
				const SizedBox(height: 12.0),
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
					key: ValueKey('cat-$_categoriaId'),
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
					key: ValueKey('unidad-$_unidad'),
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
						key: ValueKey('prov-$_proveedorId'),
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
					labelText: _vendePorPeso
						? 'Precio del kilo completo (MXN) *'
						: 'Precio menudeo (MXN) *',
					onChanged: (_) => setState(() {}),
				),
				if (_vendePorPeso)
					Padding(
						padding: const EdgeInsets.only(top: 4.0),
						child: Text(
							'Lo que paga el cliente por 1 kg. Abajo puede fijar precios distintos '
							'para medio kilo o un cuarto (suelen salir más caros por kg).',
							style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
						),
					),
				const SizedBox(height: 12.0),
				PanelCalculoUtilidad(
					costoUnitario: costo,
					precioController: _precioController,
					alCambiarPrecio: () => setState(() {}),
				),
				const SizedBox(height: 16.0),
				_buildSeccionEscalas(costo),
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
			escalasMayoreo: _escalasMayoreoActuales(),
			empaquesPendientes: _empaquesPendientes,
			alCambiarEmpaquesPendientes: (lista) =>
				setState(() => _empaquesPendientes = lista),
		);
	}

	List<EscalaMayoreoRef> _escalasMayoreoActuales() {
		if (_vendePorPeso) {
			final precioKilo = parsearPrecioTexto(_precioController.text) ?? 0.0;
			return construirEscalasDesdePreciosCorte(
				precioKilo: precioKilo,
				precioMedio: parsearPrecioTexto(_precioMedioController.text),
				precioCuarto: parsearPrecioTexto(_precioCuartoController.text),
			);
		}
		return _escalas
			.map((e) {
				final cant = parsearPrecioTexto(e.cantidadController.text) ?? 0.0;
				final precioE = parsearPrecioTexto(e.precioController.text) ?? 0.0;
				return (cantidadMinima: cant, precioUnitario: precioE);
			})
			.where((e) => e.cantidadMinima >= 0.0 && e.precioUnitario > 0.0)
			.toList();
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
		if (_vendePorPeso) {
			final precioKilo = parsearPrecioTexto(_precioController.text) ?? 0.0;
			return construirEscalasDesdePreciosCorte(
				precioKilo: precioKilo,
				precioMedio: parsearPrecioTexto(_precioMedioController.text),
				precioCuarto: parsearPrecioTexto(_precioCuartoController.text),
			)
				.map(
					(e) => EscalaMayoreo(
						productoId: productoId,
						cantidadMinima: e.cantidadMinima,
						precioUnitario: e.precioUnitario,
					),
				)
				.toList();
		}
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
			.where((e) => e.cantidadMinima >= 0.0 && e.precioUnitario > 0.0)
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
			PosiaNotificaciones.mostrarSnackBar(context, 
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
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text(errorMenudeo),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		for (final escala in _vendePorPeso ? const <_EscalaEditable>[] : _escalas) {
			if (escala.precioController.text.trim().isEmpty) {
				continue;
			}
			final errorEscala = errorPrecioVentaDesdeTexto(
				escala.precioController.text,
				costoUnitario: costo,
			);
			if (errorEscala != null) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text('Mayoreo: $errorEscala'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
		}
		if (_vendePorPeso) {
			final errorMedio = errorPrecioPresentacionDesdeTexto(
				_precioMedioController.text,
				costoUnitario: costo,
				factorABase: pesoMedioKilo,
				obligatorio: false,
			);
			if (errorMedio != null) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text('Medio kilo: $errorMedio'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
			final errorCuarto = errorPrecioPresentacionDesdeTexto(
				_precioCuartoController.text,
				costoUnitario: costo,
				factorABase: pesoCuartoKilo,
				obligatorio: false,
			);
			if (errorCuarto != null) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text('Cuarto: $errorCuarto'),
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
				final codigo = _codigoController.text.trim();
				if (codigo.isNotEmpty) {
					final existente = await servicio.buscarProductoPorCodigoBarras(codigo);
					if (existente != null && mounted) {
						final editar = await showDialog<bool>(
							context: context,
							builder: (ctx) => AlertDialog(
								title: const Text('Producto ya registrado'),
								content: Text(
									'El codigo de barras "$codigo" ya pertenece a '
									'"${existente.nombre}" '
									'(${formatearMoneda(existente.precioBase)}).\n\n'
									'Para cambiar el precio, edite ese producto. '
									'No cree un producto nuevo con el mismo codigo.',
								),
								actions: [
									TextButton(
										onPressed: () => Navigator.pop(ctx, false),
										child: const Text('Cancelar'),
									),
									FilledButton(
										onPressed: () => Navigator.pop(ctx, true),
										child: const Text('Editar producto'),
									),
								],
							),
						);
						if (!mounted) {
							return;
						}
						if (editar == true) {
							Navigator.pop(context);
							await Navigator.push<bool>(
								context,
								MaterialPageRoute<bool>(
									builder: (_) => PantallaFormularioProducto(
										productoExistente: existente,
									),
								),
							);
							return;
						}
						return;
					}
				}
				final escalasNuevas = _parseEscalas('');
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
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _guardando = false);
			}
		}
	}

	bool get _vozDisponibleEnPlataforma =>
		Platform.isAndroid || Platform.isIOS;

	Future<void> _mostrarAyudaVoz() async {
		await showDialog<void>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Dictar producto por voz'),
				content: const SingleChildScrollView(
					child: Text(
						'Disponible en iPhone y Android.\n\n'
						'1. Toca el micrófono.\n'
						'2. Di el producto en una sola frase.\n'
						'3. Revisa el resumen y confirma.\n'
						'4. Corrige lo necesario y guarda.\n\n'
						'Ejemplos:\n'
						'• Coca Cola precio 25 costo 18 categoría refrescos stock 40\n'
						'• Jitomate por kilo a 35 pesos medio kilo 20 cuarto 12\n'
						'• Arroz código 750123 precio 28.50 mayoreo desde 10 a 25\n'
						'• Leche precio veintiocho proveedor Nestlé mínimo 5\n\n'
						'Puedes dictar nombre, código, categoría, proveedor, '
						'unidad, costo, precio, medio/cuarto kilo, stock, mínimo, '
						'mayoreo y notas. Si una categoría o proveedor no existe, '
						'el resto se aplica y te avisa para elegirlo a mano.',
					),
				),
				actions: [
					FilledButton(
						onPressed: () => Navigator.pop(ctx),
						child: const Text('Entendido'),
					),
				],
			),
		);
	}

	Future<bool> _asegurarPermisosVozAndroid() async {
		var mic = await Permission.microphone.status;
		if (!mic.isGranted) {
			mic = await Permission.microphone.request();
		}
		if (!mic.isGranted) {
			if (!mounted) {
				return false;
			}
			if (mic.isPermanentlyDenied) {
				await _mostrarDialogoIrAjustes(
					'Micrófono bloqueado',
					'Actívalo en Ajustes → Aplicaciones → La Fortuna → Micrófono.',
				);
			} else {
				PosiaNotificaciones.mostrarSnackBar(
					context,
					const SnackBar(
						content: Text('Micrófono requerido'),
						duration: Duration(seconds: 2),
					),
				);
			}
			return false;
		}
		return true;
	}

	Future<void> _mostrarAyudaPermisosVozIos() async {
		await _mostrarDialogoIrAjustes(
			'Micrófono bloqueado',
			'Para dictar productos, La Fortuna necesita acceso al micrófono y al '
			'reconocimiento de voz.\n\n'
			'1. Toca el micrófono otra vez y acepta cuando iOS lo pida.\n'
			'2. Si ya lo rechazaste: Ajustes → La Fortuna → activa Micrófono y '
			'Reconocimiento de voz.',
		);
	}

	Future<void> _mostrarDialogoIrAjustes(String titulo, String mensaje) async {
		await showDialog<void>(
			context: context,
			builder: (dialogContext) => AlertDialog(
				title: Text(titulo),
				content: Text(mensaje),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(dialogContext),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () {
							Navigator.pop(dialogContext);
							openAppSettings();
						},
						child: const Text('Abrir ajustes'),
					),
				],
			),
		);
	}

	Future<void> _alternarEscuchaVoz() async {
		if (_escuchandoVoz) {
			await _finalizarEscuchaVoz();
			return;
		}
		if (!_vozDisponibleEnPlataforma) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(
				context,
				const SnackBar(
					content: Text(
						'El dictado por voz está disponible en iPhone y Android.',
					),
				),
			);
			return;
		}
		if (!Platform.isIOS) {
			final permisosOk = await _asegurarPermisosVozAndroid();
			if (!permisosOk) {
				return;
			}
		}
		if (!_vozInicializada) {
			final ok = await _servicioVoz.inicializar();
			_vozInicializada = ok;
			if (!ok) {
				if (!mounted) {
					return;
				}
				if (Platform.isIOS) {
					await _mostrarAyudaPermisosVozIos();
				} else {
					PosiaNotificaciones.mostrarSnackBar(
						context,
						SnackBar(
							content: Text(
								_servicioVoz.ultimoError ??
									'Voz no disponible en este dispositivo',
							),
						),
					);
				}
				return;
			}
		}
		if (!mounted) {
			return;
		}
		setState(() {
			_escuchandoVoz = true;
			_transcripcionVoz = '';
		});
		await _servicioVoz.escuchar(
			onTranscripcion: (texto, esFinal) {
				if (!mounted) {
					return;
				}
				setState(() => _transcripcionVoz = texto);
				if (esFinal && texto.trim().isNotEmpty) {
					unawaited(_finalizarEscuchaVoz(procesarTexto: texto));
				}
			},
		);
	}

	Future<void> _finalizarEscuchaVoz({String? procesarTexto}) async {
		if (_finalizandoVoz) {
			return;
		}
		_finalizandoVoz = true;
		try {
			final texto = (procesarTexto ?? _transcripcionVoz).trim();
			await _servicioVoz.detener();
			if (!mounted) {
				return;
			}
			setState(() {
				_escuchandoVoz = false;
				_transcripcionVoz = texto;
			});
			if (texto.isNotEmpty) {
				await _aplicarDictadoProducto(texto);
			} else if (mounted) {
				setState(() => _transcripcionVoz = '');
			}
		} finally {
			_finalizandoVoz = false;
		}
	}

	Future<void> _aplicarDictadoProducto(String texto) async {
		final borrador = _interpretadorVoz.interpretar(texto);
		if (!mounted) {
			return;
		}
		if (!borrador.tieneDatos) {
			await showDialog<void>(
				context: context,
				builder: (ctx) => AlertDialog(
					title: const Text('No entendí el dictado'),
					content: const Text(
						'Di algo como:\n\n'
						'• "Coca Cola precio 25 costo 18 categoría refrescos stock 40"\n'
						'• "Jitomate por kilo a 35 pesos medio kilo 20"\n'
						'• "Arroz código 750123 precio 28.50 mayoreo desde 10 a 25"',
					),
					actions: [
						FilledButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text('Entendido'),
						),
					],
				),
			);
			if (mounted) {
				setState(() => _transcripcionVoz = '');
			}
			return;
		}
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('¿Aplicar dictado?'),
				content: SingleChildScrollView(
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								'"$texto"',
								style: TextStyle(
									color: Colors.grey.shade700,
									fontStyle: FontStyle.italic,
								),
							),
							const SizedBox(height: 12.0),
							...borrador.lineasResumen.map(
								(l) => Padding(
									padding: const EdgeInsets.only(bottom: 4.0),
									child: Text('• $l'),
								),
							),
						],
					),
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Aplicar al formulario'),
					),
				],
			),
		);
		if (confirmar != true || !mounted) {
			setState(() => _transcripcionVoz = '');
			return;
		}
		final categorias =
			ref.read(categoriasFormularioAdminProvider).value ?? [];
		final proveedores =
			ref.read(proveedoresFormularioAdminProvider).value ?? [];
		final avisos = <String>[];
		setState(() {
			avisos.addAll(
				_rellenarDesdeBorrador(
					borrador,
					categorias: categorias,
					proveedores: proveedores,
				),
			);
			_irAPestanaSegunBorrador(borrador);
			_transcripcionVoz = '';
		});
		if (!mounted) {
			return;
		}
		final mensaje = avisos.isEmpty
			? 'Dictado aplicado. Revisa los campos y guarda.'
			: 'Dictado aplicado. ${avisos.join(' ')}';
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(
				content: Text(mensaje),
				duration: Duration(seconds: avisos.isEmpty ? 3 : 5),
				backgroundColor: avisos.isEmpty ? null : Colors.orange.shade800,
			),
		);
	}

	void _irAPestanaSegunBorrador(BorradorProductoVoz borrador) {
		final campos = borrador.camposDetectados;
		final soloInventario = campos.every(
			(c) => c == 'stock' || c == 'minimo',
		);
		if (soloInventario && campos.isNotEmpty) {
			_tabs.animateTo(3);
			return;
		}
		final tocaPrecios = campos.any(
			(c) =>
				c == 'precio' ||
				c == 'costo' ||
				c == 'medio' ||
				c == 'cuarto' ||
				c == 'escalas',
		);
		final tocaGeneral = campos.any(
			(c) =>
				c == 'nombre' ||
				c == 'codigo' ||
				c == 'categoria' ||
				c == 'proveedor' ||
				c == 'unidad' ||
				c == 'notas',
		);
		if (tocaPrecios && !tocaGeneral) {
			_tabs.animateTo(1);
		} else {
			_tabs.animateTo(0);
		}
	}

	/// Rellena el formulario. Devuelve avisos (categoria/proveedor no encontrados).
	List<String> _rellenarDesdeBorrador(
		BorradorProductoVoz borrador, {
		required List<Categoria> categorias,
		required List<Proveedor> proveedores,
	}) {
		final avisos = <String>[];
		if (borrador.nombre != null && borrador.nombre!.trim().isNotEmpty) {
			_nombreController.text = borrador.nombre!.trim();
		}
		if (borrador.codigoBarras != null &&
			borrador.codigoBarras!.trim().isNotEmpty) {
			_codigoController.text = borrador.codigoBarras!.trim();
		}
		if (borrador.unidadMedida != null) {
			_unidad = borrador.unidadMedida!;
		}
		if (borrador.precioBase != null) {
			_precioController.text = borrador.precioBase!.toStringAsFixed(2);
		}
		if (borrador.costoUnitario != null) {
			_costoController.text = borrador.costoUnitario!.toStringAsFixed(2);
		}
		if (borrador.stockInicial != null && !_esEdicion) {
			_stockController.text = _formatearCantidadEscala(borrador.stockInicial!);
		}
		if (borrador.stockMinimo != null) {
			_minimoController.text = _formatearCantidadEscala(borrador.stockMinimo!);
		}
		if (borrador.notas != null && borrador.notas!.trim().isNotEmpty) {
			_notasController.text = borrador.notas!.trim();
		}
		if (borrador.precioMedioKilo != null) {
			_precioMedioController.text =
				borrador.precioMedioKilo!.toStringAsFixed(2);
		}
		if (borrador.precioCuartoKilo != null) {
			_precioCuartoController.text =
				borrador.precioCuartoKilo!.toStringAsFixed(2);
		}
		if (borrador.nombreCategoria != null) {
			final id = _resolverIdPorNombre(
				borrador.nombreCategoria!,
				categorias.map((c) => (id: c.id, nombre: c.nombre, activa: c.activa)),
			);
			if (id != null) {
				_categoriaId = id;
			} else {
				avisos.add(
					'No hallé la categoría "${borrador.nombreCategoria}". Elígela manualmente.',
				);
			}
		}
		if (borrador.nombreProveedor != null) {
			final id = _resolverIdPorNombre(
				borrador.nombreProveedor!,
				proveedores.map((p) => (id: p.id, nombre: p.nombre, activa: true)),
			);
			if (id != null) {
				_proveedorId = id;
			} else {
				avisos.add(
					'No hallé el proveedor "${borrador.nombreProveedor}". Elígelo manualmente.',
				);
			}
		}
		if (borrador.escalasMayoreo.isNotEmpty && !_vendePorPeso) {
			for (final e in _escalas) {
				e.dispose();
			}
			_escalas
				..clear()
				..addAll(
					borrador.escalasMayoreo.map(
						(e) => _EscalaEditable(
							cantidadController: TextEditingController(
								text: _formatearCantidadEscala(e.cantidadMinima),
							),
							precioController: TextEditingController(
								text: e.precioUnitario.toStringAsFixed(2),
							),
						),
					),
				);
		}
		return avisos;
	}

	String? _resolverIdPorNombre(
		String hablado,
		Iterable<({String id, String nombre, bool activa})> catalogo,
	) {
		final q = normalizarTextoBusqueda(hablado).trim();
		if (q.isEmpty) {
			return null;
		}
		String? exacto;
		String? parcial;
		var empatesParciales = 0;
		for (final item in catalogo) {
			if (!item.activa) {
				continue;
			}
			final n = normalizarTextoBusqueda(item.nombre).trim();
			if (n == q) {
				exacto = item.id;
				break;
			}
			if (n.contains(q) || q.contains(n)) {
				empatesParciales++;
				parcial ??= item.id;
			}
		}
		if (exacto != null) {
			return exacto;
		}
		// Solo aceptar parcial si no hay ambiguedad.
		if (empatesParciales == 1) {
			return parcial;
		}
		return null;
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
