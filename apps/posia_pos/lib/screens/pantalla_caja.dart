/// Pantalla principal de caja con interfaz orientada a iconos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../widgets/selector_cliente_caja.dart';
import '../providers/app_providers.dart';
import '../utils/compartir_ticket_digital_util.dart';
import '../utils/descuento_caja_util.dart';
import '../utils/editar_linea_caja_util.dart';
import '../utils/existencias_caja_util.dart';
import '../utils/imprimir_ticket_digital_util.dart';
import '../utils/ticket_credito_util.dart';
import '../utils/ticket_venta_util.dart';
import '../widgets/dialogo_cobro.dart';

/// Evita abrir varios dialogos de cobro apilados (doble clic / F2 repetido).
bool _cobroCajaEnEjecucion = false;

/// Interfaz de venta con lista de productos, carrito y barra de acciones.
class PantallaCaja extends ConsumerStatefulWidget {
	/// Crea pantalla de caja POSIA.
	const PantallaCaja({super.key});

	@override
	ConsumerState<PantallaCaja> createState() => _PantallaCajaState();
}

class _PantallaCajaState extends ConsumerState<PantallaCaja> {
	StreamSubscription<String>? _suscripcionEscaner;
	BarcodeScanner? _scanner;
	final _busquedaController = TextEditingController();
	late final FocusNode _busquedaFocus;
	String? _ultimoCodigoProcesado;
	DateTime? _ultimoCodigoProcesadoEn;
	Timer? _timerEscaneoBarras;
	DateTime? _ultimoCambioBusquedaEn;
	bool _escaneoRapidoEnCurso = false;

	@override
	void initState() {
		super.initState();
		_busquedaFocus = FocusNode(onKeyEvent: _manejarTeclaEnBusqueda);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_iniciarEscaner();
			_enfocarBusqueda();
		});
	}

	@override
	void dispose() {
		_timerEscaneoBarras?.cancel();
		_suscripcionEscaner?.cancel();
		_scanner?.detener();
		_busquedaController.dispose();
		_busquedaFocus.dispose();
		super.dispose();
	}

	void _enfocarBusqueda() {
		if (!mounted) {
			return;
		}
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted && _busquedaFocus.canRequestFocus) {
				_busquedaFocus.requestFocus();
			}
		});
	}

	Future<void> _iniciarEscaner() async {
		final registry = await ref.read(hardwareRegistryProvider.future);
		final scanner = registry.obtenerScanner();
		_scanner = scanner;
		await scanner.iniciar();
		_suscripcionEscaner = scanner.codigos.listen(_procesarCodigoBarras);
	}

	Future<void> _procesarCodigoBarras(String codigo) async {
		await _intentarAgregarCodigo(codigo);
	}

	void _alCambiarBusqueda(String texto) {
		ref.read(carritoNotifierProvider.notifier).establecerBusqueda(texto);
		_programarProcesamientoEscaneo(texto);
	}

	void _programarProcesamientoEscaneo(String texto) {
		final ahora = DateTime.now();
		if (_ultimoCambioBusquedaEn != null &&
			ahora.difference(_ultimoCambioBusquedaEn!) <
				const Duration(milliseconds: 80)) {
			_escaneoRapidoEnCurso = true;
		}
		_ultimoCambioBusquedaEn = ahora;
		_timerEscaneoBarras?.cancel();

		final normalizado = texto.trim();
		if (normalizado.isEmpty) {
			_escaneoRapidoEnCurso = false;
			return;
		}
		if (!pareceCodigoBarrasEscaneado(normalizado)) {
			return;
		}
		final longitudTipica = normalizado.length >= 8;
		if (!_escaneoRapidoEnCurso && !longitudTipica) {
			return;
		}

		_timerEscaneoBarras = Timer(const Duration(milliseconds: 120), () {
			_escaneoRapidoEnCurso = false;
			if (!mounted) {
				return;
			}
			if (_busquedaController.text.trim() == normalizado) {
				unawaited(_procesarEntradaBusqueda(normalizado));
			}
		});
	}

	Future<void> _procesarEntradaBusqueda(String texto) async {
		final agregado = await _intentarAgregarCodigo(texto);
		if (agregado) {
			return;
		}
		final normalizado = texto.trim();
		if (pareceCodigoBarrasEscaneado(normalizado)) {
			_busquedaController.clear();
			ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
			_enfocarBusqueda();
			return;
		}
		final estado = ref.read(carritoNotifierProvider).value;
		final productos = estado?.productos ?? [];
		if (!mounted) {
			return;
		}
		if (productos.isEmpty) {
			if (texto.trim().isNotEmpty) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text('Sin resultados para "${texto.trim()}"'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
			}
			return;
		}
		final indice = (estado?.indiceBusquedaSeleccionado ?? 0).clamp(0, productos.length - 1);
		final agregadoProducto = await seleccionarProductoEnCaja(
			context,
			ref,
			productos[indice],
		);
		if (agregadoProducto) {
			_busquedaController.clear();
			ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
			_enfocarBusqueda();
		}
	}

	Future<bool> _intentarAgregarCodigo(String codigo) async {
		final normalizado = codigo.trim();
		if (normalizado.isEmpty) {
			return false;
		}
		final ahora = DateTime.now();
		if (_ultimoCodigoProcesado == normalizado &&
			_ultimoCodigoProcesadoEn != null &&
			ahora.difference(_ultimoCodigoProcesadoEn!) < const Duration(milliseconds: 400)) {
			return true;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		final agregado = await servicio.agregarPorCodigoBarras(normalizado);
		if (agregado) {
			_ultimoCodigoProcesado = normalizado;
			_ultimoCodigoProcesadoEn = ahora;
			_busquedaController.clear();
			ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
			await ref.read(carritoNotifierProvider.notifier).recargar();
			_enfocarBusqueda();
			return true;
		}
		if (!mounted) {
			return false;
		}
		if (RegExp(r'^\d{4,}$').hasMatch(normalizado)) {
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text('Código no encontrado: $normalizado'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
		return false;
	}

	KeyEventResult _manejarTeclaEnBusqueda(FocusNode node, KeyEvent event) {
		if (event is! KeyDownEvent) {
			return KeyEventResult.ignored;
		}
		final atajos = ref.read(atajosCajaConfigProvider).value ?? AtajosCajaConfig.predeterminados();
		if (procesarAtajoTecladoEnCaja(
			event: event,
			context: context,
			ref: ref,
			atajos: atajos,
		)) {
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			final texto = _busquedaController.text.trim();
			if (texto.isNotEmpty) {
				_timerEscaneoBarras?.cancel();
				_escaneoRapidoEnCurso = false;
				unawaited(_procesarEntradaBusqueda(texto));
				return KeyEventResult.handled;
			}
		}
		if (_busquedaController.text.trim().isNotEmpty) {
			final productos = ref.read(carritoNotifierProvider).value?.productos ?? [];
			if (productos.isNotEmpty) {
				final notifier = ref.read(carritoNotifierProvider.notifier);
				if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
					notifier.moverSeleccionBusqueda(delta: 1);
					return KeyEventResult.handled;
				}
				if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
					notifier.moverSeleccionBusqueda(delta: -1);
					return KeyEventResult.handled;
				}
			}
		}
		return KeyEventResult.ignored;
	}

	@override
	Widget build(BuildContext context) {
		final estadoCarrito = ref.watch(carritoNotifierProvider);
		final estado = estadoCarrito.value;
		if (estado != null) {
			return _ConstruirLayoutCaja(
				estado: estado,
				busquedaController: _busquedaController,
				busquedaFocus: _busquedaFocus,
				alCambiarBusqueda: _alCambiarBusqueda,
				alEnviarBusqueda: _procesarEntradaBusqueda,
				alEnfocarBusqueda: _enfocarBusqueda,
			);
		}
		return estadoCarrito.when(
			data: (data) => _ConstruirLayoutCaja(
				estado: data,
				busquedaController: _busquedaController,
				busquedaFocus: _busquedaFocus,
				alCambiarBusqueda: _alCambiarBusqueda,
				alEnviarBusqueda: _procesarEntradaBusqueda,
				alEnfocarBusqueda: _enfocarBusqueda,
			),
			loading: () => const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			),
			error: (error, _) => Scaffold(
				body: Center(child: Text(error.toString())),
			),
		);
	}
}

/// Layout interno de caja con paneles y acciones.
class _ConstruirLayoutCaja extends ConsumerWidget {
	const _ConstruirLayoutCaja({
		required this.estado,
		required this.busquedaController,
		required this.busquedaFocus,
		required this.alCambiarBusqueda,
		required this.alEnviarBusqueda,
		required this.alEnfocarBusqueda,
	});

	final EstadoCarrito estado;
	final TextEditingController busquedaController;
	final FocusNode busquedaFocus;
	final ValueChanged<String> alCambiarBusqueda;
	final ValueChanged<String> alEnviarBusqueda;
	final VoidCallback alEnfocarBusqueda;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final teclaConfig = ref.watch(atajosCajaConfigProvider).value ?? AtajosCajaConfig.predeterminados();
		final etiquetaCobrar = etiquetaAtajoConfigurado(teclaConfig.atajo(atajoAccionCobrar));
		return Scaffold(
			backgroundColor: PosiaColors.fondo,
			body: Column(
				children: [
					PanelTotal(
						nombreTienda: estado.nombreTienda,
						total: estado.total,
						nombreVendedor: estado.nombreVendedor,
						turnoAbierto: estado.turnoAbierto,
					),
					if (!estado.turnoAbierto)
						Material(
							color: Colors.orange.shade50,
							child: Container(
								width: double.infinity,
								padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
								child: Row(
									children: [
										Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20.0),
										const SizedBox(width: 8.0),
										Expanded(
											child: Text(
												'Sin turno abierto — Admin › Corte de caja',
												style: TextStyle(
													fontWeight: FontWeight.w600,
													color: Colors.orange.shade900,
												),
											),
										),
									],
								),
							),
						),
					if (estado.categorias.isNotEmpty)
						DecoratedBox(
							decoration: BoxDecoration(
								color: PosiaColors.tarjeta,
								boxShadow: [
									BoxShadow(
										color: Colors.black.withValues(alpha: 0.04),
										blurRadius: 6.0,
										offset: const Offset(0.0, 2.0),
									),
								],
							),
							child: BarraCategorias(
								categorias: estado.categorias,
								categoriaSeleccionadaId: estado.categoriaSeleccionadaId,
								alSeleccionar: (id) {
									ref.read(carritoNotifierProvider.notifier).seleccionarCategoria(id);
								},
							),
						),
					CampoBusquedaCaja(
						controlador: busquedaController,
						focusNode: busquedaFocus,
						alCambiar: alCambiarBusqueda,
						alEnviar: alEnviarBusqueda,
					),
					if (estado.favoritos.isNotEmpty)
						Container(
							height: 56.0,
							margin: const EdgeInsets.only(top: 4.0),
							child: ListView.separated(
								scrollDirection: Axis.horizontal,
								padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
								itemCount: estado.favoritos.length,
								separatorBuilder: (_, _) => const SizedBox(width: 8.0),
								itemBuilder: (context, indice) {
									final producto = estado.favoritos[indice];
									return ActionChip(
										avatar: Icon(Icons.star_rounded, size: 18.0, color: Colors.amber.shade700),
										label: Text(
											producto.nombre,
											overflow: TextOverflow.ellipsis,
										),
										backgroundColor: Colors.amber.shade50,
										side: BorderSide(color: Colors.amber.shade200),
										onPressed: () async {
											final agregado = await seleccionarProductoEnCaja(
												context,
												ref,
												producto,
											);
											if (agregado) {
												alEnfocarBusqueda();
											}
										},
									);
								},
							),
						),
					Expanded(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
							child: Row(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									Expanded(
										flex: 3,
										child: Card(
											margin: EdgeInsets.zero,
											clipBehavior: Clip.antiAlias,
											child: ListaProductosCaja(
												categoriaId: estado.categoriaSeleccionadaId,
												productos: estado.productos,
												stockLocalPorProducto: estado.stockLocalPorProducto,
												indiceSeleccionado: busquedaController.text.trim().isNotEmpty
													? estado.indiceBusquedaSeleccionado
													: null,
												mensajeVacio: busquedaController.text.trim().isNotEmpty
													? 'Sin coincidencias para "${busquedaController.text.trim()}"'
													: 'Sin productos en esta categoría',
												alVerExistencias: (producto) =>
													mostrarExistenciasProductoEnCaja(context, ref, producto),
												alPresionarLargo: (producto) =>
													intentarSeleccionarEmpaqueEnCaja(
														context,
														ref,
														producto,
													),
												alSeleccionar: (producto) async {
													final agregado = await seleccionarProductoEnCaja(
														context,
														ref,
														producto,
													);
													if (agregado) {
														alEnfocarBusqueda();
													}
												},
											),
										),
									),
									const SizedBox(width: 8.0),
									Expanded(
										flex: 2,
										child: Card(
											margin: EdgeInsets.zero,
											clipBehavior: Clip.antiAlias,
											child: PanelCarrito(
												lineas: estado.lineas,
												total: estado.total,
												descuentoTicket: estado.descuentoTicket,
												alEliminarLinea: (indice) {
													ref.read(carritoNotifierProvider.notifier).eliminarLinea(indice);
												},
												alDobleClicLinea: (indice) => mostrarEditarLineaCaja(
													context,
													ref,
													indice,
												),
											),
										),
									),
								],
							),
						),
					),
					_BarraAccionesCaja(
						total: estado.total,
						estado: estado,
						etiquetaTeclaCobrar: etiquetaCobrar,
					),
				],
			),
		);
	}
}

/// Enruta seleccion de producto segun modulo vertical activo.
///
/// Retorna true si el producto quedo agregado al carrito.
Future<bool> seleccionarProductoEnCaja(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	FocusManager.instance.primaryFocus?.unfocus();
	if (producto.moduloVertical == ModuloVertical.farmacia) {
		return _agregarProductoFarmacia(context, ref, producto);
	}
	if (producto.moduloVertical == ModuloVertical.carniceria || producto.requierePeso()) {
		return _agregarProductoCarniceria(context, ref, producto);
	}
	final servicio = await ref.read(servicioCajaProvider.future);
	if (!context.mounted) {
		return false;
	}
	if (await servicio.productoTieneVariantes(producto.id)) {
		if (!context.mounted) {
			return false;
		}
		return _seleccionarVariante(context, ref, producto);
	}
	if (!context.mounted) {
		return false;
	}
	final resultado = await DialogoCantidadProducto.mostrar(context, producto);
	if (!resultado.confirmado) {
		return false;
	}
	try {
		await ref.read(carritoNotifierProvider.notifier).agregarProducto(
			producto,
			cantidad: resultado.cantidad,
		);
	} catch (error) {
		if (context.mounted) {
			await _mostrarErrorCaja(context, '$error');
		}
		return false;
	}
	return true;
}

/// Muestra dialogo para vender por empaque (caja, bulto, etc.).
///
/// Uso secundario: mantener pulsado un producto en la lista o favoritos.
Future<bool> seleccionarEmpaqueEnCaja(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	final presentaciones = await servicio.listarPresentacionesActivas(producto.id);
	if (!context.mounted || presentaciones.isEmpty) {
		return false;
	}
	var agregado = false;
	await showDialog<void>(
		context: context,
		builder: (dialogContext) => AlertDialog(
			title: Text('Vender por empaque: ${producto.nombre}'),
			content: SizedBox(
				width: 340.0,
				child: ListView(
					shrinkWrap: true,
					children: presentaciones
						.map(
							(p) => ListTile(
								title: Text(p.nombre),
								subtitle: Text(
									p.codigoBarras.isNotEmpty
										? '${p.codigoBarras} · ${_etiquetaContenidoEmpaque(p, producto)}'
										: _etiquetaContenidoEmpaque(p, producto),
								),
								trailing: Text(
									formatearMoneda(
										p.precio ??
											redondearMonto(producto.precioBase * p.factorABase),
									),
								),
								onTap: () async {
									Navigator.of(dialogContext).pop();
									if (!context.mounted) {
										return;
									}
									final precioEmpaque = p.precio ??
										redondearMonto(producto.precioBase * p.factorABase);
									final resultado = await DialogoCantidadProducto.mostrar(
										context,
										producto.copiarCon(
											nombre: '${producto.nombre} - ${p.nombre}',
											precioBase: precioEmpaque,
										),
										etiquetaUnidad: p.nombre,
									);
									if (!resultado.confirmado) {
										return;
									}
									try {
										await servicio.agregarPresentacion(
											p,
											cantidad: resultado.cantidad,
										);
										agregado = true;
										await ref
											.read(carritoNotifierProvider.notifier)
											.recargar();
									} catch (error) {
										if (context.mounted) {
											await _mostrarErrorCaja(context, '$error');
										}
									}
								},
							),
						)
						.toList(),
				),
			),
		),
	);
	return agregado;
}

String _etiquetaContenidoEmpaque(PresentacionProducto presentacion, Producto producto) {
	final factor = presentacion.factorABase == presentacion.factorABase.roundToDouble()
		? presentacion.factorABase.toStringAsFixed(0)
		: presentacion.factorABase.toStringAsFixed(2);
	final unidadBase = switch (producto.unidadMedida) {
		UnidadMedida.kilogramo => 'kg',
		UnidadMedida.litro => 'L',
		_ => 'piezas',
	};
	return '1 ${presentacion.nombre} = $factor $unidadBase';
}

Future<void> intentarSeleccionarEmpaqueEnCaja(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	if (!await servicio.productoTienePresentaciones(producto.id)) {
		return;
	}
	if (!context.mounted) {
		return;
	}
	await seleccionarEmpaqueEnCaja(context, ref, producto);
}

/// Muestra dialogo de presentaciones activas del producto.
Future<bool> _seleccionarVariante(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	final variantes = await servicio.listarVariantesActivas(producto.id);
	if (!context.mounted || variantes.isEmpty) {
		return false;
	}
	var agregado = false;
	await showDialog<void>(
		context: context,
		builder: (dialogContext) => AlertDialog(
			title: Text('Presentación: ${producto.nombre}'),
			content: SizedBox(
				width: 320.0,
				child: ListView(
					shrinkWrap: true,
					children: variantes
						.map(
							(v) => ListTile(
								title: Text(v.nombre),
								subtitle: Text(v.codigoBarras),
								trailing: Text(formatearMoneda(v.precioBase)),
								onTap: () async {
									await servicio.agregarVariante(v);
									agregado = true;
									if (dialogContext.mounted) {
										Navigator.of(dialogContext).pop();
									}
									await ref.read(carritoNotifierProvider.notifier).recargar();
								},
							),
						)
						.toList(),
				),
			),
		),
	);
	return agregado;
}

/// Muestra dialogo de peso y agrega corte al carrito.
Future<bool> _agregarProductoCarniceria(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	if (!context.mounted) {
		return false;
	}
	final resultado = await DialogoPesoCarniceria.mostrar(
		context,
		producto,
		resolverPrecio: (pesoKg) => servicio.resolverPrecioVenta(producto, pesoKg),
	);
	if (!resultado.confirmado) {
		return false;
	}
	final error = await servicio.agregarProductoConPeso(producto, resultado.pesoKg);
	if (!context.mounted) {
		return false;
	}
	if (error.isNotEmpty) {
		await _mostrarErrorCaja(context, error);
		return false;
	}
	await ref.read(carritoNotifierProvider.notifier).recargar();
	return true;
}

/// Muestra dialogo de lote FEFO y agrega medicamento al carrito.
Future<bool> _agregarProductoFarmacia(
	BuildContext context,
	WidgetRef ref,
	Producto producto,
) async {
	final contenedor = await ref.read(contenedorServiciosProvider.future);
	final servicioFarmacia = contenedor.servicioFarmacia;
	final servicioCaja = contenedor.servicioCaja;
	final tiendaId = contenedor.servicioAdmin.tiendaActivaId;
	final lotes = await servicioFarmacia.listarLotesParaVenta(
		producto.id,
		tiendaId,
	);
	if (!context.mounted) {
		return false;
	}
	final resultado = await DialogoLoteFarmacia.mostrar(
		context: context,
		producto: producto,
		lotes: lotes,
		servicioFarmacia: servicioFarmacia,
	);
	if (!resultado.confirmado || resultado.lote == null) {
		return false;
	}
	final error = await servicioCaja.agregarProductoConLote(
		producto,
		resultado.lote!,
		resultado.cantidad,
	);
	if (error.isNotEmpty && context.mounted) {
		await _mostrarErrorCaja(context, error);
		return false;
	}
	await ref.read(carritoNotifierProvider.notifier).recargar();
	return true;
}

/// Muestra alerta visual de error en operacion de caja.
Future<void> _mostrarErrorCaja(BuildContext context, String mensaje) async {
	await showDialog<void>(
		context: context,
		builder: (dialogContext) {
			return AlertDialog(
				icon: const Icon(Icons.error_outline, color: PosiaColors.cancelar, size: 48.0),
				content: Text(mensaje, textAlign: TextAlign.center),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(dialogContext).pop(),
						child: const Text('OK'),
					),
				],
			);
		},
	);
}

/// Aparta el carrito actual para atender otro cliente.
Future<void> ejecutarPonerEnEspera(BuildContext context, WidgetRef ref) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	if (!servicio.carritoTieneLineas()) {
		if (context.mounted) {
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('El carrito está vacío')),
			);
		}
		return;
	}
	final notasController = TextEditingController();
	final cliente = servicio.obtenerClienteActivo();
	if (cliente != null) {
		notasController.text = cliente.nombre;
	}
	if (!context.mounted) {
		notasController.dispose();
		return;
	}
	final confirmar = await showDialog<bool>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text('Poner ticket en espera'),
			content: SizedBox(
				width: 360.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							'Total: ${formatearMoneda(servicio.calcularTotalCarrito())}',
							style: const TextStyle(fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: notasController,
							decoration: const InputDecoration(
								labelText: 'Referencia (opcional)',
								hintText: 'Ej. Mesa 3, Juan, pedido teléfono',
								border: OutlineInputBorder(),
							),
						),
					],
				),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
				FilledButton(
					onPressed: () => Navigator.pop(ctx, true),
					child: const Text('Guardar en espera'),
				),
			],
		),
	);
	if (confirmar != true || !context.mounted) {
		notasController.dispose();
		return;
	}
	final notas = notasController.text;
	notasController.dispose();
	try {
		await ref.read(carritoNotifierProvider.notifier).ponerCarritoEnEspera(
			notas: notas,
		);
		if (!context.mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('Ticket guardado en espera')),
		);
	} on StateError catch (e) {
		if (!context.mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(content: Text(e.message), backgroundColor: PosiaColors.cancelar),
		);
	}
}

/// Muestra tickets apartados para recuperar o eliminar.
Future<void> mostrarTicketsEnEspera(BuildContext context, WidgetRef ref) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	final tickets = await servicio.listarTicketsEnEspera();
	if (!context.mounted) {
		return;
	}
	if (tickets.isEmpty) {
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('No hay tickets en espera')),
		);
		await ref.read(carritoNotifierProvider.notifier).recargar();
		return;
	}
	await showDialog<void>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text('Tickets en espera'),
			content: SizedBox(
				width: 420.0,
				height: 360.0,
				child: ListView.separated(
					itemCount: tickets.length,
					separatorBuilder: (_, _) => const Divider(height: 1.0),
					itemBuilder: (context, indice) {
						final ticket = tickets[indice];
						final hora = ticket.creadoEn.toLocal();
						final horaTexto =
							'${hora.hour.toString().padLeft(2, '0')}:'
							'${hora.minute.toString().padLeft(2, '0')}';
						return ListTile(
							title: Text(ticket.etiquetaLista),
							subtitle: Text(
								'${ticket.cantidadLineas} productos · $horaTexto',
							),
							trailing: Text(
								formatearMoneda(ticket.total),
								style: const TextStyle(fontWeight: FontWeight.w600),
							),
							onTap: () async {
								final carritoConLineas = servicio.carritoTieneLineas();
								if (carritoConLineas) {
									final reemplazar = await showDialog<bool>(
										context: ctx,
										builder: (d) => AlertDialog(
											title: const Text('Reemplazar carrito actual'),
											content: const Text(
												'El carrito actual tiene productos. '
												'¿Descartarlos y recuperar este ticket?',
											),
											actions: [
												TextButton(
													onPressed: () => Navigator.pop(d, false),
													child: const Text('Cancelar'),
												),
												FilledButton(
													onPressed: () => Navigator.pop(d, true),
													child: const Text('Recuperar'),
												),
											],
										),
									);
									if (reemplazar != true) {
										return;
									}
									await ref.read(carritoNotifierProvider.notifier).vaciarCarrito();
								}
								await ref
									.read(carritoNotifierProvider.notifier)
									.recuperarTicketEnEspera(ticket.id);
								if (ctx.mounted) {
									Navigator.pop(ctx);
								}
								if (context.mounted) {
									PosiaNotificaciones.mostrarSnackBar(context, 
										SnackBar(
											content: Text('Ticket recuperado: ${ticket.etiquetaLista}'),
										),
									);
								}
							},
							onLongPress: () async {
								final eliminar = await showDialog<bool>(
									context: ctx,
									builder: (d) => AlertDialog(
										title: const Text('Eliminar ticket en espera'),
										content: Text(
											'¿Eliminar "${ticket.etiquetaLista}" '
											'(${formatearMoneda(ticket.total)})?',
										),
										actions: [
											TextButton(
												onPressed: () => Navigator.pop(d, false),
												child: const Text('Cancelar'),
											),
											FilledButton(
												style: FilledButton.styleFrom(
													backgroundColor: PosiaColors.cancelar,
												),
												onPressed: () => Navigator.pop(d, true),
												child: const Text('Eliminar'),
											),
										],
									),
								);
								if (eliminar != true) {
									return;
								}
								await ref
									.read(carritoNotifierProvider.notifier)
									.eliminarTicketEnEspera(ticket.id);
								if (ctx.mounted) {
									Navigator.pop(ctx);
								}
								if (context.mounted) {
									await mostrarTicketsEnEspera(context, ref);
								}
							},
						);
					},
				),
			),
			actions: [
				TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
			],
		),
	);
}

/// Pide confirmacion antes de vaciar el carrito.
Future<void> confirmarVaciarCarritoCaja(BuildContext context, WidgetRef ref) async {
	final confirmar = await showDialog<bool>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text('Vaciar carrito'),
			content: const Text('Se eliminarán todas las líneas del carrito.'),
			actions: [
				TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
				FilledButton(
					onPressed: () => Navigator.pop(ctx, true),
					child: const Text('Sí, vaciar'),
				),
			],
		),
	);
	if (confirmar == true) {
		await ref.read(carritoNotifierProvider.notifier).vaciarCarrito();
	}
}

/// Procesa atajos de caja (cobrar, espera, cotizar, etc.).
///
/// Retorna true si el evento fue consumido.
bool procesarAtajoTecladoEnCaja({
	required KeyEvent event,
	required BuildContext context,
	required WidgetRef ref,
	required AtajosCajaConfig atajos,
	void Function(String claveAdmin)? alAbrirSeccionAdmin,
	void Function()? alIrAdmin,
}) {
	if (event is! KeyDownEvent || hayDialogoModalConFoco()) {
		return false;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionCobrar))) {
		final estado = ref.read(carritoNotifierProvider).value;
		if (estado != null && estado.total > 0.0) {
			ejecutarCobroCaja(context, ref);
			return true;
		}
		return false;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionPonerEspera))) {
		ejecutarPonerEnEspera(context, ref);
		return true;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionRecuperarEspera))) {
		mostrarTicketsEnEspera(context, ref);
		return true;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionCotizar))) {
		ejecutarCotizacionCaja(context, ref);
		return true;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionVaciarCarrito))) {
		confirmarVaciarCarritoCaja(context, ref);
		return true;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionCreditos))) {
		if (alAbrirSeccionAdmin != null) {
			alAbrirSeccionAdmin('creditos');
			return true;
		}
		ref.read(solicitudNavegacionDesdeCajaProvider.notifier).solicitar(
			const SolicitudNavegacionDesdeCaja.seccion('creditos'),
		);
		return true;
	}
	if (coincideAtajoConfigurado(event, atajos.atajo(atajoAccionAdmin))) {
		if (alIrAdmin != null) {
			alIrAdmin();
			return true;
		}
		ref.read(solicitudNavegacionDesdeCajaProvider.notifier).solicitar(
			const SolicitudNavegacionDesdeCaja.admin(),
		);
		return true;
	}
	return false;
}

bool _cobroIncluyeEfectivo(MetodoPago metodo, CobroRequest request) {
	if (metodo == MetodoPago.efectivo) {
		return true;
	}
	if (metodo == MetodoPago.mixto && (request.montoEfectivo ?? 0) > 0) {
		return true;
	}
	return false;
}

Future<void> _mostrarOpcionesPostVenta(
	BuildContext context, {
	required TicketDigitalContenido ticketDigital,
	String? telefonoCliente,
}) async {
	await showDialog<void>(
		context: context,
		builder: (dialogContext) => CallbackShortcuts(
			bindings: {
				const SingleActivator(LogicalKeyboardKey.enter): () {
					Navigator.of(dialogContext).pop();
				},
				const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
					Navigator.of(dialogContext).pop();
				},
			},
			child: AlertDialog(
				title: const Text('Venta completada'),
				content: const Text(
					'¿Desea enviar el ticket digital por WhatsApp?\n'
					'Se adjuntará una imagen con el logo de la tienda.',
				),
				actions: [
					TextButton.icon(
						onPressed: () async {
							await compartirTicketDigitalWhatsApp(
								context,
								contenido: ticketDigital,
								telefono: telefonoCliente,
							);
							if (dialogContext.mounted) {
								Navigator.of(dialogContext).pop();
							}
						},
						icon: const Icon(Icons.chat),
						label: const Text('WhatsApp'),
					),
					FilledButton(
						autofocus: true,
						onPressed: () => Navigator.of(dialogContext).pop(),
						child: const Text('Cerrar'),
					),
				],
			),
		),
	);
}

Future<void> _mostrarOpcionesPostCredito(
	BuildContext context, {
	required TicketDigitalContenido pagareDigital,
	String? telefonoCliente,
}) async {
	await showDialog<void>(
		context: context,
		builder: (dialogContext) => CallbackShortcuts(
			bindings: {
				const SingleActivator(LogicalKeyboardKey.enter): () {
					Navigator.of(dialogContext).pop();
				},
				const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
					Navigator.of(dialogContext).pop();
				},
			},
			child: AlertDialog(
				title: const Text('Crédito registrado'),
				content: const Text(
					'¿Desea enviar el pagaré digital por WhatsApp al cliente?',
				),
				actions: [
					TextButton.icon(
						onPressed: () async {
							await compartirTicketDigitalWhatsApp(
								context,
								contenido: pagareDigital,
								telefono: telefonoCliente,
							);
							if (dialogContext.mounted) {
								Navigator.of(dialogContext).pop();
							}
						},
						icon: const Icon(Icons.chat),
						label: const Text('WhatsApp'),
					),
					FilledButton(
						autofocus: true,
						onPressed: () => Navigator.of(dialogContext).pop(),
						child: const Text('Cerrar'),
					),
				],
			),
		),
	);
}

/// Ejecuta cobro con dialogo multipago e impresion.
Future<void> ejecutarCobroCaja(BuildContext context, WidgetRef ref) async {
	if (_cobroCajaEnEjecucion) {
		return;
	}
	_cobroCajaEnEjecucion = true;
	try {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = await servicio.validarCobro();
		if (error != null && context.mounted) {
			await showDialog<void>(
				context: context,
				builder: (ctx) => AlertDialog(
					icon: const Icon(Icons.warning_amber, color: Colors.orange),
					content: Text(error, textAlign: TextAlign.center),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
					],
				),
			);
			return;
		}
		CobroRequest? request;
		while (context.mounted) {
			final cliente = servicio.obtenerClienteActivo();
			if (!context.mounted) {
				return;
			}
			request = await mostrarDialogoCobro(
				context: context,
				subtotal: servicio.calcularTotalCarrito(),
				cliente: cliente,
			);
			if (request == null) {
				return;
			}
			final errorCobro = await servicio.validarCobroRequest(request);
			if (errorCobro == null) {
				break;
			}
			if (context.mounted) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(content: Text(errorCobro), backgroundColor: PosiaColors.cancelar),
				);
			}
		}
		if (!context.mounted || request == null) {
			return;
		}
		Venta? venta;
		try {
			venta = await servicio.cobrar(request);
		} on Object catch (error) {
			if (context.mounted) {
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(
						content: Text('No se pudo completar la venta: $error'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
			}
			return;
		}
		await ref.read(carritoNotifierProvider.notifier).recargar();
		if (!context.mounted || venta == null) {
			return;
		}
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final config = await ref.read(configDispositivoProvider.future);
		final hardware = await ref.read(hardwareRegistryProvider.future);
		final impresora = hardware.obtenerImpresora();
		if (venta.metodoPago == MetodoPago.credito) {
			final pagares = await obtenerTicketsDigitalesPagareCredito(
				venta: venta,
				servicioAdmin: contenedor.servicioAdmin,
			);
			await imprimirTicketsDigitales(
				impresora: impresora,
				contenidos: pagares,
			);
			if (!context.mounted) {
				return;
			}
			final cliente = venta.clienteId != null
				? await contenedor.servicioAdmin.obtenerCliente(venta.clienteId!)
				: null;
			if (!context.mounted) {
				return;
			}
			final pagareDigital = await obtenerTicketDigitalPagareCliente(
				venta: venta,
				servicioAdmin: contenedor.servicioAdmin,
			);
			if (!context.mounted) {
				return;
			}
			await _mostrarOpcionesPostCredito(
				context,
				pagareDigital: pagareDigital,
				telefonoCliente: cliente?.telefono,
			);
		} else {
			final ticketDigital = await obtenerTicketDigitalVenta(
				venta: venta,
				servicioAdmin: contenedor.servicioAdmin,
				config: config,
				montoRecibido: request.montoRecibido,
			);
			await imprimirTicketDigital(
				impresora: impresora,
				contenido: ticketDigital,
			);
			if (_cobroIncluyeEfectivo(venta.metodoPago, request)) {
				try {
					await hardware.obtenerCajon()?.abrir();
				} catch (_) {}
			}
			if (!context.mounted) {
				return;
			}
			final cliente = venta.clienteId != null
				? await contenedor.servicioAdmin.obtenerCliente(venta.clienteId!)
				: null;
			if (!context.mounted) {
				return;
			}
			await _mostrarOpcionesPostVenta(
				context,
				ticketDigital: ticketDigital,
				telefonoCliente: cliente?.telefono,
			);
		}
		if (!context.mounted) {
			return;
		}
		final esCredito = venta.metodoPago == MetodoPago.credito;
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(
				content: Text(
					esCredito
						? 'Crédito registrado · ${formatearMoneda(venta.total)}'
						: 'Venta completada · ${formatearMoneda(venta.total)}',
				),
				backgroundColor: PosiaColors.cobrar,
				duration: const Duration(seconds: 2),
			),
		);
	} finally {
		_cobroCajaEnEjecucion = false;
	}
}

/// Genera e imprime cotizacion desde el carrito actual.
Future<void> ejecutarCotizacionCaja(BuildContext context, WidgetRef ref) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	if (servicio.obtenerCarrito().isEmpty) {
		if (context.mounted) {
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Agregue productos al carrito')),
			);
		}
		return;
	}
	try {
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final resultado = await registrarCotizacionDesdeCarrito(
			servicioCaja: servicio,
			servicioAdmin: contenedor.servicioAdmin,
		);
		final hardware = await ref.read(hardwareRegistryProvider.future);
		await imprimirTicketDigital(
			impresora: hardware.obtenerImpresora(),
			contenido: resultado.digital,
		);
		ref.invalidate(cotizacionesAdminProvider);
		if (!context.mounted) {
			return;
		}
		final clienteActivo = servicio.obtenerClienteActivo();
		await showDialog<void>(
			context: context,
			builder: (dialogContext) => AlertDialog(
				icon: const Icon(Icons.request_quote, color: PosiaColors.neutro, size: 56.0),
				title: const Text('Cotización guardada'),
				content: Text(
					'Folio ${resultado.cotizacion.id.substring(0, 8).toUpperCase()}\n'
					'${formatearMoneda(resultado.cotizacion.total)}',
					style: Theme.of(context).textTheme.headlineSmall,
					textAlign: TextAlign.center,
				),
				actions: [
					TextButton.icon(
						onPressed: () async {
							await compartirTicketDigitalWhatsApp(
								context,
								contenido: resultado.digital,
								telefono: clienteActivo?.telefono,
							);
						},
						icon: const Icon(Icons.chat),
						label: const Text('WhatsApp'),
					),
					TextButton(
						onPressed: () => Navigator.of(dialogContext).pop(),
						child: const Text('OK'),
					),
				],
			),
		);
	} catch (error) {
		if (context.mounted) {
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}
}

/// Barra inferior fija con acciones iconograficas de caja.
class _BarraAccionesCaja extends ConsumerWidget {
	const _BarraAccionesCaja({
		required this.total,
		required this.estado,
		required this.etiquetaTeclaCobrar,
	});

	final double total;
	final EstadoCarrito estado;
	final String etiquetaTeclaCobrar;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final puedeCobrar = total > 0.0;
		final adminDescuento = puedeDescuentoEnCaja(ref);
		return SafeArea(
			top: false,
			child: DecoratedBox(
				decoration: BoxDecoration(
					color: PosiaColors.tarjeta,
					boxShadow: [
						BoxShadow(
							color: Colors.black.withValues(alpha: 0.08),
							blurRadius: 8.0,
							offset: const Offset(0.0, -2.0),
						),
					],
				),
				child: Padding(
					padding: const EdgeInsets.fromLTRB(8.0, 10.0, 8.0, 10.0),
					child: Row(
						children: [
							Expanded(
								child: BotonAccionCaja(
									icono: Icons.person,
									etiqueta: 'Cliente',
									colorFondo: PosiaColors.neutro,
									alPresionar: () => mostrarSelectorClienteCaja(context, ref),
								),
							),
							Expanded(
								child: BotonAccionCaja(
									icono: Icons.pause_circle_outline,
									etiqueta: 'En espera',
									colorFondo: PosiaColors.neutro,
									habilitado: puedeCobrar,
									alPresionar: () => ejecutarPonerEnEspera(context, ref),
								),
							),
							if (estado.ticketsEnEspera > 0)
								Expanded(
									child: BotonAccionCaja(
										icono: Icons.playlist_play,
										etiqueta: 'Recuperar (${estado.ticketsEnEspera})',
										colorFondo: Colors.orange.shade800,
										alPresionar: () => mostrarTicketsEnEspera(context, ref),
									),
								),
							Expanded(
								child: BotonAccionCaja(
									icono: Icons.clear,
									etiqueta: 'Cancelar',
									colorFondo: PosiaColors.cancelar,
									alPresionar: () => confirmarVaciarCarritoCaja(context, ref),
								),
							),
							Expanded(
								child: BotonAccionCaja(
									icono: Icons.request_quote,
									etiqueta: 'Cotizar',
									colorFondo: PosiaColors.neutro,
									habilitado: puedeCobrar,
									alPresionar: () => ejecutarCotizacionCaja(context, ref),
								),
							),
							if (adminDescuento)
								Expanded(
									child: BotonAccionCaja(
										icono: Icons.discount_outlined,
										etiqueta: estado.descuentoTicket > 0.0
											? 'Nota ${formatearMoneda(estado.descuentoTicket)}'
											: 'Desc. nota',
										colorFondo: PosiaColors.neutro,
										habilitado: puedeCobrar,
										alPresionar: () =>
											mostrarDescuentoTicketCaja(context, ref),
									),
								),
							Expanded(
								flex: 2,
								child: BotonAccionCaja(
									icono: Icons.payments,
									etiqueta: 'COBRAR ($etiquetaTeclaCobrar)',
									colorFondo: PosiaColors.cobrar,
									habilitado: puedeCobrar,
									alPresionar: () => ejecutarCobroCaja(context, ref),
								),
							),
						],
					),
				),
			),
		);
	}
}
