/// Panel para gestionar presentaciones de empaque de un producto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

/// Borrador de empaque para productos aun no guardados.
class EmpaqueProductoDraft {
	const EmpaqueProductoDraft({
		required this.nombre,
		required this.factorABase,
		this.tipoPresentacionId,
		this.codigoBarras = '',
		this.precio,
	});

	final String nombre;
	final double factorABase;
	final String? tipoPresentacionId;
	final String codigoBarras;
	final double? precio;
}

/// Plantilla rapida de empaque comun.
class PlantillaEmpaque {
	const PlantillaEmpaque({
		required this.etiqueta,
		required this.nombre,
		required this.factor,
		required this.tipoPresentacionId,
		required this.icono,
	});

	final String etiqueta;
	final String nombre;
	final double factor;
	final String tipoPresentacionId;
	final IconData icono;
}

/// Plantillas frecuentes para agregar con un toque.
const plantillasEmpaqueComunes = [
	PlantillaEmpaque(
		etiqueta: 'Caja 12 u.',
		nombre: 'Caja x12',
		factor: 12,
		tipoPresentacionId: 'tp-caja',
		icono: Icons.inventory_2_outlined,
	),
	PlantillaEmpaque(
		etiqueta: 'Caja 20 u.',
		nombre: 'Caja x20',
		factor: 20,
		tipoPresentacionId: 'tp-caja',
		icono: Icons.inventory_2_outlined,
	),
	PlantillaEmpaque(
		etiqueta: 'Caja 24 u.',
		nombre: 'Caja x24',
		factor: 24,
		tipoPresentacionId: 'tp-caja',
		icono: Icons.inventory_2_outlined,
	),
	PlantillaEmpaque(
		etiqueta: 'Bulto 8 kg',
		nombre: 'Bulto 8 kg',
		factor: 8,
		tipoPresentacionId: 'tp-kg',
		icono: Icons.scale_outlined,
	),
	PlantillaEmpaque(
		etiqueta: 'Bulto 25 kg',
		nombre: 'Bulto 25 kg',
		factor: 25,
		tipoPresentacionId: 'tp-kg',
		icono: Icons.scale_outlined,
	),
	PlantillaEmpaque(
		etiqueta: 'Bulto 50 u.',
		nombre: 'Bulto x50',
		factor: 50,
		tipoPresentacionId: 'tp-bulto',
		icono: Icons.all_inbox_outlined,
	),
];

/// Deriva campos legacy del producto a partir de presentaciones activas.
({int? piezasPorCaja, int? unidadesPorBulto}) derivarEmpaqueLegacy({
	required Iterable<PresentacionProducto> presentaciones,
	required List<TipoPresentacion> tipos,
}) {
	int? piezasCaja;
	int? unidadesBulto;
	for (final p in presentaciones) {
		if (p.esPresentacionBase || !p.activo) {
			continue;
		}
		final factor = p.factorABase.round();
		if (factor <= 0) {
			continue;
		}
		final tipo = tipos.where((t) => t.id == p.tipoPresentacionId).firstOrNull;
		if (tipo == null) {
			continue;
		}
		if (tipo.id == 'tp-caja' || tipo.unidad == 'caja') {
			piezasCaja ??= factor;
		} else if (tipo.id == 'tp-bulto') {
			unidadesBulto ??= factor;
		}
	}
	return (piezasPorCaja: piezasCaja, unidadesPorBulto: unidadesBulto);
}

/// Lista, plantillas y formulario de empaques/presentaciones.
class PanelEmpaquesProducto extends ConsumerStatefulWidget {
	const PanelEmpaquesProducto({
		this.productoId,
		required this.costoUnitario,
		required this.precioMenudeo,
		required this.unidadMedida,
		this.escalasMayoreo = const [],
		this.empaquesPendientes = const [],
		this.alCambiarEmpaquesPendientes,
		this.incrustado = false,
		super.key,
	});

	final String? productoId;
	final double costoUnitario;
	final double precioMenudeo;
	final UnidadMedida unidadMedida;
	final List<EscalaMayoreoRef> escalasMayoreo;
	final List<EmpaqueProductoDraft> empaquesPendientes;
	final ValueChanged<List<EmpaqueProductoDraft>>? alCambiarEmpaquesPendientes;
	final bool incrustado;

	@override
	ConsumerState<PanelEmpaquesProducto> createState() =>
		_PanelEmpaquesProductoState();
}

class _PanelEmpaquesProductoState extends ConsumerState<PanelEmpaquesProducto> {
	List<PresentacionProducto> _presentaciones = [];
	List<TipoPresentacion> _tipos = [];
	bool _cargando = true;
	bool _procesando = false;

	/// Ultimo fallo al persistir un empaque, mostrado fijo en el panel.
	///
	/// Los SnackBar de esta pantalla se perdian: los del diálogo quedaban detrás
	/// de la barrera modal y los del panel se descartaban si el widget ya no
	/// estaba montado. El resultado era un guardado que no ocurría y no decía
	/// nada. Este banner permanece hasta que el usuario lo cierra.
	String? _errorPersistente;

	bool get _esProductoNuevo => widget.productoId == null;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatos());
	}

	@override
	void didUpdateWidget(covariant PanelEmpaquesProducto oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.productoId != widget.productoId) {
			_cargarDatos();
		}
	}

	Future<void> _cargarDatos() async {
		setState(() => _cargando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final tipos = await servicio.listarTiposPresentacion();
			List<PresentacionProducto> presentaciones = [];
			if (!_esProductoNuevo) {
				presentaciones = await servicio.listarPresentacionesProducto(
					widget.productoId!,
				);
			}
			if (!mounted) {
				return;
			}
			setState(() {
				_tipos = tipos.where((t) => t.activo).toList();
				_presentaciones = presentaciones;
				_cargando = false;
			});
		} catch (error) {
			if (!mounted) {
				return;
			}
			setState(() => _cargando = false);
			_mostrarError('$error');
		}
	}

	void _mostrarError(String mensaje) {
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(content: Text(mensaje), backgroundColor: PosiaColors.cancelar),
		);
	}

	void _mostrarExito(String mensaje) {
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(content: Text(mensaje)),
		);
	}

	List<PresentacionProducto> get _presentacionesActivas =>
		_presentaciones.where((p) => p.activo).toList();

	bool _factorYaExiste(
		double factor, {
		String? excluirPresentacionId,
		int? excluirIndicePendiente,
	}) {
		if (_esProductoNuevo) {
			return widget.empaquesPendientes.asMap().entries.any(
				(e) =>
					e.key != excluirIndicePendiente &&
					(e.value.factorABase - factor).abs() < 0.001,
			);
		}
		return _presentacionesActivas.any(
			(p) =>
				!p.esPresentacionBase &&
				p.id != excluirPresentacionId &&
				(p.factorABase - factor).abs() < 0.001,
		);
	}

	double? _precioSugerido(double factor) {
		return calcularPrecioSugeridoPresentacion(
			factorABase: factor,
			precioMenudeo: widget.precioMenudeo,
			escalasMayoreo: widget.escalasMayoreo,
		);
	}

	String _etiquetaUnidadBase() {
		return switch (widget.unidadMedida) {
			UnidadMedida.kilogramo => 'Kilogramo (unidad base)',
			UnidadMedida.litro => 'Litro (unidad base)',
			_ => 'Pieza (unidad base)',
		};
	}

	String _etiquetaUnidadBaseCorta() {
		return switch (widget.unidadMedida) {
			UnidadMedida.kilogramo => 'kg',
			UnidadMedida.litro => 'L',
			_ => 'piezas',
		};
	}

	String _descripcionFactor(PresentacionProducto p) {
		final factor = _formatearFactor(p.factorABase);
		final unidadBase = _etiquetaUnidadBaseCorta();
		if (p.esPresentacionBase || p.factorABase == 1.0) {
			return '1 $unidadBase = 1 unidad base';
		}
		final empaque = p.nombre.isNotEmpty
			? p.nombre
			: (_tipos.where((t) => t.id == p.tipoPresentacionId).firstOrNull?.nombre ??
				'empaque');
		return '1 $empaque = $factor $unidadBase';
	}

	String _descripcionFactorDraft(EmpaqueProductoDraft e) {
		final tipo = _tipos.where((t) => t.id == e.tipoPresentacionId).firstOrNull;
		final unidad = tipo?.unidad ?? widget.unidadMedida.name;
		final factor = _formatearFactor(e.factorABase);
		if (unidad == 'kilogramo') {
			return '$factor kg por empaque';
		}
		return 'Factor $factor · ${tipo?.nombre ?? 'Empaque'}';
	}

	String _formatearFactor(double factor) {
		if (factor == factor.roundToDouble()) {
			return factor.toStringAsFixed(0);
		}
		return factor.toStringAsFixed(2);
	}

	Future<void> _aplicarPlantilla(PlantillaEmpaque plantilla) async {
		if (_factorYaExiste(plantilla.factor)) {
			_mostrarError('Ya existe un empaque con factor ${plantilla.factor}');
			return;
		}
		await _abrirFormularioEmpaque(
			nombreInicial: plantilla.nombre,
			factorInicial: plantilla.factor,
			tipoInicial: plantilla.tipoPresentacionId,
			precioInicial: _precioSugerido(plantilla.factor),
		);
	}

	Future<void> _abrirFormularioEmpaque({
		PresentacionProducto? existente,
		String? nombreInicial,
		double? factorInicial,
		String? tipoInicial,
		double? precioInicial,
		int? indicePendiente,
	}) async {
		final draft = indicePendiente != null &&
				indicePendiente < widget.empaquesPendientes.length
			? widget.empaquesPendientes[indicePendiente]
			: null;
		final nombreController = TextEditingController(
			text: existente?.nombre ?? draft?.nombre ?? nombreInicial ?? '',
		);
		final factorController = TextEditingController(
			text: existente != null
				? _formatearFactor(existente.factorABase)
				: draft != null
					? _formatearFactor(draft.factorABase)
					: factorInicial != null
						? _formatearFactor(factorInicial)
						: '',
		);
		final codigoController = TextEditingController(
			text: existente?.codigoBarras ?? draft?.codigoBarras ?? '',
		);
		final precioController = TextEditingController(
			text: existente?.precio?.toStringAsFixed(2) ??
				draft?.precio?.toStringAsFixed(2) ??
				(precioInicial?.toStringAsFixed(2) ?? ''),
		);
		var tipoId = existente?.tipoPresentacionId ??
			draft?.tipoPresentacionId ??
			tipoInicial ??
			_tipos.firstOrNull?.id;

		// Solo auto-actualizar precio mientras coincida con el sugerido anterior;
		// si el usuario lo edita a mano, ya no se sobrescribe.
		String? ultimoPrecioSugerido;
		final factorInicialParseado =
			parsearPrecioTexto(factorController.text) ?? 0.0;
		if (factorInicialParseado > 0) {
			final sugeridoInicial = _precioSugerido(factorInicialParseado);
			if (sugeridoInicial != null &&
				precioController.text.trim() == sugeridoInicial.toStringAsFixed(2)) {
				ultimoPrecioSugerido = sugeridoInicial.toStringAsFixed(2);
			}
		}

		void sincronizarPrecioSugerido() {
			final f = parsearPrecioTexto(factorController.text) ?? 0.0;
			if (f <= 0) {
				return;
			}
			final sugerido = _precioSugerido(f);
			if (sugerido == null) {
				return;
			}
			final textoSugerido = sugerido.toStringAsFixed(2);
			final precioActual = precioController.text.trim();
			final esSugeridoPrevio = ultimoPrecioSugerido != null &&
				precioActual == ultimoPrecioSugerido;
			if (precioActual.isEmpty || esSugeridoPrevio) {
				precioController.text = textoSugerido;
				ultimoPrecioSugerido = textoSugerido;
			}
		}

		// Los errores de validación se muestran DENTRO del diálogo. Con
		// ScaffoldMessenger el SnackBar queda detrás de la barrera modal: el
		// usuario pulsa Guardar, la validación falla y no aparece nada.
		String? errorDialogo;

		final guardado = await showDialog<bool>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setLocal) {
					final factor = parsearPrecioTexto(factorController.text) ?? 0.0;
					return AlertDialog(
						title: Text(
							existente != null || indicePendiente != null
								? 'Editar empaque'
								: 'Nuevo empaque',
						),
						content: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									TextField(
										controller: nombreController,
										decoration: const InputDecoration(
											labelText: 'Nombre *',
											border: OutlineInputBorder(),
											hintText: 'Ej. Caja 12, Bulto 25 kg',
										),
									),
									const SizedBox(height: 12.0),
									TextField(
										controller: factorController,
										keyboardType: const TextInputType.numberWithOptions(
											decimal: true,
										),
										decoration: InputDecoration(
											labelText: 'Cantidad por empaque *',
											border: const OutlineInputBorder(),
											helperText: widget.unidadMedida == UnidadMedida.kilogramo
												? 'Ej. 25 = bulto de 25 kg'
												: 'Ej. 12 = caja de 12 piezas',
										),
										onChanged: (_) {
											sincronizarPrecioSugerido();
											setLocal(() => errorDialogo = null);
										},
									),
									const SizedBox(height: 12.0),
									if (_tipos.isNotEmpty)
										DropdownButtonFormField<String>(
											initialValue: _tipos.any((t) => t.id == tipoId)
												? tipoId
												: _tipos.first.id,
											items: _tipos
												.map(
													(t) => DropdownMenuItem(
														value: t.id,
														child: Text(t.nombre),
													),
												)
												.toList(),
											onChanged: (v) => setLocal(() => tipoId = v),
											decoration: const InputDecoration(
												labelText: 'Tipo de empaque',
												border: OutlineInputBorder(),
											),
										),
									const SizedBox(height: 12.0),
									TextField(
										controller: codigoController,
										decoration: const InputDecoration(
											labelText: 'Código de barras (opcional)',
											border: OutlineInputBorder(),
										),
									),
									const SizedBox(height: 12.0),
									CampoPrecioVenta(
										controller: precioController,
										costoUnitario: widget.costoUnitario,
										factorABase: factor > 0 ? factor : 1,
										labelText: 'Precio de venta (opcional)',
										obligatorio: false,
									),
									if (errorDialogo != null) ...[
										const SizedBox(height: 12.0),
										Container(
											width: double.infinity,
											padding: const EdgeInsets.all(12.0),
											decoration: BoxDecoration(
												color: PosiaColors.cancelar.withValues(alpha: 0.10),
												borderRadius: BorderRadius.circular(8.0),
											),
											child: Row(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													const Icon(
														Icons.error_outline,
														color: PosiaColors.cancelar,
														size: 20.0,
													),
													const SizedBox(width: 8.0),
													Expanded(
														child: Text(
															errorDialogo!,
															style: const TextStyle(
																color: PosiaColors.cancelar,
															),
														),
													),
												],
											),
										),
									],
								],
							),
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(ctx, false),
								child: const Text('Cancelar'),
							),
							FilledButton(
								onPressed: () {
									final nombre = nombreController.text.trim();
									final factor =
										parsearPrecioTexto(factorController.text) ?? 0.0;
									if (nombre.isEmpty || factor <= 0) {
										setLocal(
											() => errorDialogo = nombre.isEmpty
												? 'Escriba un nombre para el empaque'
												: 'La cantidad por empaque debe ser mayor a 0',
										);
										return;
									}
									final textoPrecio = precioController.text.trim();
									final errorPrecio = CampoPrecioVenta.validarController(
										precioController,
										costoUnitario: widget.costoUnitario,
										factorABase: factor > 0 ? factor : 1,
										obligatorio: false,
									);
									if (errorPrecio != null && textoPrecio.isNotEmpty) {
										setLocal(() => errorDialogo = errorPrecio);
										return;
									}
									if (_factorYaExiste(
										factor,
										excluirPresentacionId: existente?.id,
										excluirIndicePendiente: indicePendiente,
									)) {
										setLocal(
											() => errorDialogo = existente != null ||
													indicePendiente != null
												? 'Ya existe otro empaque con esa cantidad '
													'(${_formatearFactor(factor)})'
												: 'Ya existe un empaque con esa cantidad '
													'(${_formatearFactor(factor)})',
										);
										return;
									}
									Navigator.pop(ctx, true);
								},
								child: const Text('Guardar'),
							),
						],
					);
				},
			),
		);

		if (guardado != true) {
			nombreController.dispose();
			factorController.dispose();
			codigoController.dispose();
			precioController.dispose();
			return;
		}

		final nombre = nombreController.text.trim();
		final factor = parsearPrecioTexto(factorController.text) ?? 0.0;
		final precio = parsearPrecioTexto(precioController.text);
		final codigo = codigoController.text.trim();

		nombreController.dispose();
		factorController.dispose();
		codigoController.dispose();
		precioController.dispose();

		if (_esProductoNuevo) {
			final lista = List<EmpaqueProductoDraft>.from(widget.empaquesPendientes);
			final draft = EmpaqueProductoDraft(
				nombre: nombre,
				factorABase: factor,
				tipoPresentacionId: tipoId,
				codigoBarras: codigo,
				precio: precio,
			);
			if (indicePendiente != null) {
				lista[indicePendiente] = draft;
			} else {
				lista.add(draft);
			}
			widget.alCambiarEmpaquesPendientes?.call(lista);
			setState(() {});
			_mostrarExito(
				indicePendiente != null ? 'Empaque actualizado' : 'Empaque agregado',
			);
			return;
		}

		setState(() => _procesando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.guardarPresentacionProducto(
				id: existente?.id,
				productoId: widget.productoId!,
				nombre: nombre,
				factorABase: factor,
				tipoPresentacionId: tipoId,
				codigoBarras: codigo,
				precio: precio,
			);
			await _cargarDatos();
			if (!mounted) {
				return;
			}
			setState(() => _errorPersistente = null);
			_mostrarExito('Empaque guardado');
		} catch (error, rastro) {
			// Nunca tragar el fallo: si el widget se desmontó no hay setState
			// posible, pero al menos queda en el log de la plataforma.
			debugPrint('POSIA: fallo al guardar empaque: $error\n$rastro');
			if (mounted) {
				setState(() => _errorPersistente = '$error');
				_mostrarError('$error');
			}
		} finally {
			if (mounted) {
				setState(() => _procesando = false);
			}
		}
	}

	Future<void> _confirmarEliminar(PresentacionProducto presentacion) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar empaque'),
				content: Text(
					'¿Quitar "${presentacion.nombre}" de las presentaciones de venta?',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						style: FilledButton.styleFrom(
							backgroundColor: PosiaColors.cancelar,
						),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (ok != true) {
			return;
		}
		setState(() => _procesando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.eliminarPresentacionProducto(presentacion.id);
			await _cargarDatos();
			if (mounted) {
				_mostrarExito('Empaque eliminado');
			}
		} catch (error) {
			if (mounted) {
				_mostrarError('$error');
			}
		} finally {
			if (mounted) {
				setState(() => _procesando = false);
			}
		}
	}

	void _eliminarPendiente(int indice) {
		final lista = List<EmpaqueProductoDraft>.from(widget.empaquesPendientes);
		lista.removeAt(indice);
		widget.alCambiarEmpaquesPendientes?.call(lista);
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		if (_cargando) {
			return const Center(child: CircularProgressIndicator());
		}

		final baseExistente = _presentacionesActivas
			.where((p) => p.esPresentacionBase)
			.firstOrNull;

		return Stack(
			children: [
				ListView(
					padding: widget.incrustado
						? EdgeInsets.zero
						: const EdgeInsets.all(16.0),
					shrinkWrap: widget.incrustado,
					physics: widget.incrustado
						? const NeverScrollableScrollPhysics()
						: null,
					children: [
						Text(
							widget.incrustado
								? 'Empaques (caja, bulto…)'
								: 'Presentaciones de empaque',
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
								fontWeight: FontWeight.bold,
							),
						),
						const SizedBox(height: 4.0),
						Text(
							widget.incrustado
								? 'Opcional. Precio fijo al vender en caja, bulto u otro empaque. '
									'En caja se cobra al elegir el empaque o escanear su código.'
								: 'Configure cómo llega y se vende el producto: cajas, bultos, kg, etc.',
							style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0),
						),
						if (_esProductoNuevo) ...[
							const SizedBox(height: 8.0),
							Row(
								children: [
									Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
									const SizedBox(width: 8.0),
									Expanded(
										child: Text(
											widget.incrustado
												? 'Los empaques se guardan al pulsar Guardar producto.'
												: 'Los empaques se guardarán al crear el producto.',
											style: TextStyle(
												color: Colors.grey.shade600,
												fontSize: 12.0,
											),
										),
									),
								],
							),
						],
						if (_errorPersistente != null) ...[
							const SizedBox(height: 12.0),
							Container(
								padding: const EdgeInsets.all(12.0),
								decoration: BoxDecoration(
									color: PosiaColors.cancelar.withValues(alpha: 0.10),
									border: Border.all(
										color: PosiaColors.cancelar.withValues(alpha: 0.40),
									),
									borderRadius: BorderRadius.circular(8.0),
								),
								child: Row(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Icon(
											Icons.error_outline,
											color: PosiaColors.cancelar,
											size: 20.0,
										),
										const SizedBox(width: 8.0),
										Expanded(
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													const Text(
														'No se pudo guardar el empaque',
														style: TextStyle(
															fontWeight: FontWeight.bold,
															color: PosiaColors.cancelar,
														),
													),
													const SizedBox(height: 4.0),
													Text(
														_errorPersistente!,
														style: const TextStyle(fontSize: 12.0),
													),
												],
											),
										),
										IconButton(
											icon: const Icon(Icons.close, size: 18.0),
											tooltip: 'Cerrar',
											onPressed: () =>
												setState(() => _errorPersistente = null),
										),
									],
								),
							),
						],
						const SizedBox(height: 16.0),
						_buildTarjetaBase(baseExistente),
						const SizedBox(height: 16.0),
						if (_esProductoNuevo)
							..._buildListaPendientes()
						else
							..._buildListaPersistidas(),
						const SizedBox(height: 20.0),
						Text(
							'Agregar empaque rápido',
							style: Theme.of(context).textTheme.titleSmall?.copyWith(
								fontWeight: FontWeight.w600,
							),
						),
						const SizedBox(height: 8.0),
						Wrap(
							spacing: 8.0,
							runSpacing: 8.0,
							children: [
								...plantillasEmpaqueComunes.map(
									(p) => ActionChip(
										avatar: Icon(p.icono, size: 18.0),
										label: Text(p.etiqueta),
										onPressed: _procesando
											? null
											: () => _aplicarPlantilla(p),
									),
								),
								ActionChip(
									avatar: const Icon(Icons.add, size: 18.0),
									label: const Text('Personalizado'),
									onPressed: _procesando ? null : _abrirFormularioEmpaque,
								),
							],
						),
					],
				),
				if (_procesando)
					const Positioned(
						left: 0,
						right: 0,
						top: 0,
						child: LinearProgressIndicator(minHeight: 2.0),
					),
			],
		);
	}

	Widget _buildTarjetaBase(PresentacionProducto? baseExistente) {
		return Card(
			color: PosiaColors.cobrar.withValues(alpha: 0.06),
			child: ListTile(
				leading: CircleAvatar(
					backgroundColor: PosiaColors.cobrar.withValues(alpha: 0.15),
					child: const Icon(Icons.looks_one, color: PosiaColors.cobrar),
				),
				title: Text(baseExistente?.nombre ?? _etiquetaUnidadBase()),
				subtitle: Text(
					baseExistente != null
						? _descripcionFactor(baseExistente)
						: 'Factor 1 · Venta unitaria',
				),
				trailing: baseExistente?.precio != null
					? Text(formatearMoneda(baseExistente!.precio!))
					: widget.precioMenudeo > 0
						? Text(formatearMoneda(widget.precioMenudeo))
						: null,
			),
		);
	}

	List<Widget> _buildListaPersistidas() {
		final extras = _presentacionesActivas
			.where((p) => !p.esPresentacionBase)
			.toList();
		if (extras.isEmpty) {
			return [
				Card(
					child: Padding(
						padding: const EdgeInsets.all(20.0),
						child: Text(
							'Sin empaques adicionales. Use las plantillas de arriba '
							'o cree uno personalizado.',
							textAlign: TextAlign.center,
							style: TextStyle(color: Colors.grey.shade600),
						),
					),
				),
			];
		}
		return extras.map(_buildTarjetaPersistida).toList();
	}

	List<Widget> _buildListaPendientes() {
		if (widget.empaquesPendientes.isEmpty) {
			return [
				Card(
					child: Padding(
						padding: const EdgeInsets.all(20.0),
						child: Text(
							'Sin empaques adicionales. Elija una plantilla o cree uno personalizado.',
							textAlign: TextAlign.center,
							style: TextStyle(color: Colors.grey.shade600),
						),
					),
				),
			];
		}
		return widget.empaquesPendientes.asMap().entries.map((entry) {
			final i = entry.key;
			final e = entry.value;
			return Card(
				margin: const EdgeInsets.only(bottom: 8.0),
				child: ListTile(
					leading: const Icon(Icons.inventory_2_outlined),
					title: Text(e.nombre),
					subtitle: Text(_descripcionFactorDraft(e)),
					trailing: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (e.precio != null)
								Padding(
									padding: const EdgeInsets.only(right: 4.0),
									child: Text(formatearMoneda(e.precio!)),
								),
							IconButton(
								icon: const Icon(Icons.edit_outlined),
								tooltip: 'Editar',
								onPressed: () => _abrirFormularioEmpaque(
									nombreInicial: e.nombre,
									factorInicial: e.factorABase,
									tipoInicial: e.tipoPresentacionId,
									precioInicial: e.precio,
									indicePendiente: i,
								),
							),
							IconButton(
								icon: const Icon(Icons.delete_outline, color: PosiaColors.cancelar),
								tooltip: 'Eliminar',
								onPressed: () => _eliminarPendiente(i),
							),
						],
					),
				),
			);
		}).toList();
	}

	Widget _buildTarjetaPersistida(PresentacionProducto p) {
		return Card(
			margin: const EdgeInsets.only(bottom: 8.0),
			child: ListTile(
				leading: const Icon(Icons.inventory_2_outlined),
				title: Text(p.nombre),
				subtitle: Text(
					'${_descripcionFactor(p)}'
					'${p.codigoBarras.isNotEmpty ? ' · ${p.codigoBarras}' : ''}',
				),
				trailing: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						if (p.precio != null)
							Padding(
								padding: const EdgeInsets.only(right: 4.0),
								child: Text(formatearMoneda(p.precio!)),
							),
						IconButton(
							icon: const Icon(Icons.edit_outlined),
							tooltip: 'Editar',
							onPressed: () => _abrirFormularioEmpaque(existente: p),
						),
						IconButton(
							icon: const Icon(Icons.delete_outline, color: PosiaColors.cancelar),
							tooltip: 'Eliminar',
							onPressed: () => _confirmarEliminar(p),
						),
					],
				),
			),
		);
	}
}

/// Persiste empaques pendientes tras crear un producto nuevo.
Future<void> guardarEmpaquesPendientes({
	required ServicioAdmin servicio,
	required String productoId,
	required List<EmpaqueProductoDraft> empaques,
}) async {
	for (final e in empaques) {
		await servicio.guardarPresentacionProducto(
			productoId: productoId,
			nombre: e.nombre,
			factorABase: e.factorABase,
			tipoPresentacionId: e.tipoPresentacionId,
			codigoBarras: e.codigoBarras,
			precio: e.precio,
			sincronizar: false,
		);
	}
	if (empaques.isNotEmpty) {
		await servicio.sincronizarPresentacionesProducto(productoId);
	}
}
