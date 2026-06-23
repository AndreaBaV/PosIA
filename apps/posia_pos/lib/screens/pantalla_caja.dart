/// Pantalla principal de caja con interfaz orientada a iconos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_hardware/posia_hardware.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../widgets/dialogo_completar_datos_credito.dart';
import '../providers/app_providers.dart';
import '../utils/ticket_credito_util.dart';
import '../utils/ticket_venta_util.dart';
import '../widgets/dialogo_cobro.dart';

/// Atajo de teclado para cobrar venta.
class CobrarIntent extends Intent {
	const CobrarIntent();
}

/// Interfaz de venta con grilla de productos, carrito y barra de acciones.
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
	final _busquedaFocus = FocusNode();
	String? _ultimoCodigoProcesado;
	DateTime? _ultimoCodigoProcesadoEn;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_iniciarEscaner();
			_enfocarBusqueda();
		});
	}

	@override
	void dispose() {
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

	Future<void> _procesarEntradaBusqueda(String texto) async {
		final agregado = await _intentarAgregarCodigo(texto);
		if (agregado) {
			return;
		}
		final productos = ref.read(carritoNotifierProvider).value?.productos ?? [];
		if (productos.length == 1) {
			await ref.read(carritoNotifierProvider.notifier).agregarProducto(productos.first);
			_busquedaController.clear();
			ref.read(carritoNotifierProvider.notifier).limpiarBusqueda();
			_enfocarBusqueda();
			return;
		}
		if (!mounted) {
			return;
		}
		if (texto.trim().isNotEmpty && productos.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('Sin resultados para "${texto.trim()}"'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
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
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('Código no encontrado: $normalizado'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
		return false;
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
				alCambiarBusqueda: (texto) =>
					ref.read(carritoNotifierProvider.notifier).establecerBusqueda(texto),
				alEnviarBusqueda: _procesarEntradaBusqueda,
				alEnfocarBusqueda: _enfocarBusqueda,
			);
		}
		return estadoCarrito.when(
			data: (data) => _ConstruirLayoutCaja(
				estado: data,
				busquedaController: _busquedaController,
				busquedaFocus: _busquedaFocus,
				alCambiarBusqueda: (texto) =>
					ref.read(carritoNotifierProvider.notifier).establecerBusqueda(texto),
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
		final teclaConfig = ref.watch(teclaCobrarConfigProvider).value ?? teclaCobrarPredeterminada;
		return Shortcuts(
			shortcuts: {
				SingleActivator(parsearTeclaConfigurada(teclaConfig)): const CobrarIntent(),
			},
			child: Actions(
				actions: {
					CobrarIntent: CallbackAction<CobrarIntent>(
						onInvoke: (_) {
							if (estado.total > 0.0) {
								ejecutarCobroCaja(context, ref);
							}
							return null;
						},
					),
				},
				child: Focus(
					autofocus: true,
					child: Scaffold(
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
								separatorBuilder: (_, __) => const SizedBox(width: 8.0),
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
										onPressed: () {
											_manejarSeleccionProducto(context, ref, producto);
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
											child: GrillaProductos(
												categoriaId: estado.categoriaSeleccionadaId,
												productos: estado.productos,
												mensajeVacio: busquedaController.text.trim().isNotEmpty
													? 'Sin coincidencias para "${busquedaController.text.trim()}"'
													: 'Sin productos en esta categoría',
												alSeleccionar: (producto) async {
													await _manejarSeleccionProducto(context, ref, producto);
													alEnfocarBusqueda();
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
												alEliminarLinea: (indice) {
													ref.read(carritoNotifierProvider.notifier).eliminarLinea(indice);
												},
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
						etiquetaTeclaCobrar: etiquetaTeclaConfigurada(teclaConfig),
					),
				],
			),
					),
				),
			),
		);
	}

	/// Enruta seleccion de producto segun modulo vertical activo.
	///
	/// [context] Contexto para dialogos modales.
	/// [ref] Referencia Riverpod.
	/// [producto] Producto seleccionado en grilla.
	Future<void> _manejarSeleccionProducto(
		BuildContext context,
		WidgetRef ref,
		Producto producto,
	) async {
		if (producto.moduloVertical == ModuloVertical.farmacia) {
			await _agregarProductoFarmacia(context, ref, producto);
			return;
		}
		if (producto.moduloVertical == ModuloVertical.carniceria || producto.requierePeso()) {
			await _agregarProductoCarniceria(context, ref, producto);
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		if (!context.mounted) {
			return;
		}
		if (await servicio.productoTieneVariantes(producto.id)) {
			if (!context.mounted) {
				return;
			}
			await _seleccionarVariante(context, ref, producto);
			return;
		}
		await ref.read(carritoNotifierProvider.notifier).agregarProducto(producto);
	}

	/// Muestra dialogo de presentaciones activas del producto.
	Future<void> _seleccionarVariante(
		BuildContext context,
		WidgetRef ref,
		Producto producto,
	) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final variantes = await servicio.listarVariantesActivas(producto.id);
		if (!context.mounted || variantes.isEmpty) {
			return;
		}
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
	}

	/// Muestra dialogo de peso y agrega corte al carrito.
	///
	/// [context] Contexto de navegacion.
	/// [ref] Referencia Riverpod.
	/// [producto] Producto vendido por kilogramo.
	Future<void> _agregarProductoCarniceria(
		BuildContext context,
		WidgetRef ref,
		Producto producto,
	) async {
		final resultado = await DialogoPesoCarniceria.mostrar(context, producto);
		if (!resultado.confirmado) {
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = await servicio.agregarProductoConPeso(producto, resultado.pesoKg);
		if (error.isNotEmpty && context.mounted) {
			await _mostrarError(context, error);
			return;
		}
		await ref.read(carritoNotifierProvider.notifier).recargar();
	}

	/// Muestra dialogo de lote FEFO y agrega medicamento al carrito.
	///
	/// [context] Contexto de navegacion.
	/// [ref] Referencia Riverpod.
	/// [producto] Producto farmaceutico.
	Future<void> _agregarProductoFarmacia(
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
			return;
		}
		final resultado = await DialogoLoteFarmacia.mostrar(
			context: context,
			producto: producto,
			lotes: lotes,
			servicioFarmacia: servicioFarmacia,
		);
		if (!resultado.confirmado || resultado.lote == null) {
			return;
		}
		final error = await servicioCaja.agregarProductoConLote(
			producto,
			resultado.lote!,
			resultado.cantidad,
		);
		if (error.isNotEmpty && context.mounted) {
			await _mostrarError(context, error);
			return;
		}
		await ref.read(carritoNotifierProvider.notifier).recargar();
	}

	/// Muestra alerta visual de error en operacion de caja.
	///
	/// [context] Contexto de navegacion.
	/// [mensaje] Texto de error para el cajero.
	Future<void> _mostrarError(BuildContext context, String mensaje) async {
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
}

/// Ejecuta cobro con dialogo multipago e impresion.
Future<void> ejecutarCobroCaja(BuildContext context, WidgetRef ref) async {
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
	final cliente = servicio.obtenerClienteActivo();
	final request = await mostrarDialogoCobro(
		context: context,
		subtotal: servicio.calcularTotalCarrito(),
		cliente: cliente,
	);
	if (request == null || !context.mounted) {
		return;
	}
	final errorCobro = await servicio.validarCobroRequest(request);
	if (errorCobro != null && context.mounted) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text(errorCobro), backgroundColor: PosiaColors.cancelar),
		);
		return;
	}
	final venta = await servicio.cobrar(request);
	await ref.read(carritoNotifierProvider.notifier).recargar();
	if (!context.mounted || venta == null) {
		return;
	}
	final contenedor = await ref.read(contenedorServiciosProvider.future);
	final config = await ref.read(configDispositivoProvider.future);
	final hardware = await ref.read(hardwareRegistryProvider.future);
	final impresora = hardware.obtenerImpresora();
	if (venta.metodoPago == MetodoPago.credito) {
		final pagares = await construirTextosPagareCredito(
			venta: venta,
			servicioAdmin: contenedor.servicioAdmin,
		);
		for (final pagare in pagares) {
			await impresora.imprimirTicket(pagare);
		}
	} else {
		final textoTicket = await construirTextoTicketVenta(
			venta: venta,
			servicioAdmin: contenedor.servicioAdmin,
			config: config,
			montoRecibido: request.montoRecibido,
		);
		await impresora.imprimirTicket(textoTicket);
	}
	if (!context.mounted) {
		return;
	}
	final esCredito = venta.metodoPago == MetodoPago.credito;
	await showDialog<void>(
		context: context,
		builder: (dialogContext) {
			return AlertDialog(
				icon: const Icon(Icons.check_circle, color: PosiaColors.cobrar, size: 64.0),
				title: Text(esCredito ? 'Credito registrado' : 'Venta completada'),
				content: Text(
					esCredito
						? 'Se imprimieron 2 pagares.\n${formatearMoneda(venta.total)}'
						: formatearMoneda(venta.total),
					style: Theme.of(context).textTheme.headlineSmall,
					textAlign: TextAlign.center,
				),
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

/// Genera e imprime cotizacion desde el carrito actual.
Future<void> ejecutarCotizacionCaja(BuildContext context, WidgetRef ref) async {
	final servicio = await ref.read(servicioCajaProvider.future);
	if (servicio.obtenerCarrito().isEmpty) {
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
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
		await hardware.obtenerImpresora().imprimirTicket(resultado.texto);
		if (!context.mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (dialogContext) => AlertDialog(
				icon: const Icon(Icons.request_quote, color: PosiaColors.neutro, size: 56.0),
				title: const Text('Cotizacion guardada'),
				content: Text(
					'Folio ${resultado.cotizacion.id.substring(0, 8).toUpperCase()}\n'
					'${formatearMoneda(resultado.cotizacion.total)}',
					style: Theme.of(context).textTheme.headlineSmall,
					textAlign: TextAlign.center,
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(dialogContext).pop(),
						child: const Text('OK'),
					),
				],
			),
		);
	} catch (error) {
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
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
		return Container(
			padding: const EdgeInsets.all(8.0),
			color: PosiaColors.tarjeta,
			child: Row(
				children: [
					BotonAccionCaja(
						icono: Icons.person,
						etiqueta: 'Cliente',
						colorFondo: PosiaColors.neutro,
						alPresionar: () => _mostrarSelectorCliente(context, ref),
					),
					BotonAccionCaja(
						icono: Icons.clear,
						etiqueta: 'Cancelar',
						colorFondo: PosiaColors.cancelar,
						alPresionar: () => _confirmarVaciarCarrito(context, ref),
					),
					BotonAccionCaja(
						icono: Icons.request_quote,
						etiqueta: 'Cotizar',
						colorFondo: PosiaColors.neutro,
						habilitado: puedeCobrar,
						alPresionar: () => ejecutarCotizacionCaja(context, ref),
					),
					BotonAccionCaja(
						icono: Icons.payments,
						etiqueta: 'COBRAR ($etiquetaTeclaCobrar)',
						colorFondo: PosiaColors.cobrar,
						habilitado: puedeCobrar,
						alPresionar: () => ejecutarCobroCaja(context, ref),
					),
				],
			),
		);
	}

	/// Pide confirmacion antes de vaciar el carrito.
	Future<void> _confirmarVaciarCarrito(BuildContext context, WidgetRef ref) async {
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

	/// Muestra dialogo simplificado de seleccion de cliente.
	///
	/// [context] Contexto de navegacion.
	/// [ref] Referencia Riverpod.
	Future<void> _mostrarSelectorCliente(BuildContext context, WidgetRef ref) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final clientes = await servicio.listarClientes();
		if (!context.mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (dialogContext) {
				return AlertDialog(
					title: const Text('Seleccionar cliente'),
					content: SizedBox(
						width: 320.0,
						child: ListView(
							shrinkWrap: true,
							children: [
								ListTile(
									leading: const Icon(Icons.storefront),
									title: const Text('Mostrador'),
									onTap: () async {
										await servicio.seleccionarCliente(null);
										if (dialogContext.mounted) {
											Navigator.of(dialogContext).pop();
										}
										await ref.read(carritoNotifierProvider.notifier).recargar(
											invalidarCatalogo: true,
										);
									},
								),
								...clientes.map(
									(cliente) => ListTile(
										leading: Icon(
											Icons.person,
											color: clientePuedeRecibirCredito(cliente)
												? PosiaColors.cobrar
												: null,
										),
										title: Text(cliente.nombre),
										subtitle: cliente.creditoHabilitado
											? Text(
												clientePuedeRecibirCredito(cliente)
													? 'Credito · ${cliente.diasCredito} dias'
													: 'Credito: faltan datos',
												style: TextStyle(
													fontSize: 12.0,
													color: clientePuedeRecibirCredito(cliente)
														? Colors.grey
														: PosiaColors.cancelar,
												),
											)
											: null,
										onTap: () async {
											var seleccion = cliente;
											if (cliente.creditoHabilitado &&
												!clienteTieneDatosCredito(cliente)) {
												if (!dialogContext.mounted) {
													return;
												}
												final actualizado = await mostrarDialogoCompletarDatosCredito(
													context: dialogContext,
													cliente: cliente,
												);
												if (actualizado == null) {
													return;
												}
												final contenedor =
													await ref.read(contenedorServiciosProvider.future);
												await contenedor.servicioAdmin.actualizarCliente(
													actualizado,
												);
												seleccion = actualizado;
											}
											await servicio.seleccionarCliente(seleccion);
											if (dialogContext.mounted) {
												Navigator.of(dialogContext).pop();
											}
											await ref.read(carritoNotifierProvider.notifier).recargar(
												invalidarCatalogo: true,
											);
										},
									),
								),
							],
						),
					),
				);
			},
		);
	}
}
