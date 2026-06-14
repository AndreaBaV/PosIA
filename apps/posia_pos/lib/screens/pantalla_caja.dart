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

import '../providers/app_providers.dart';
import '../widgets/dialogo_cobro.dart';

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

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarEscaner());
	}

	@override
	void dispose() {
		_suscripcionEscaner?.cancel();
		_scanner?.detener();
		super.dispose();
	}

	Future<void> _iniciarEscaner() async {
		final registry = await ref.read(hardwareRegistryProvider.future);
		final scanner = registry.obtenerScanner();
		_scanner = scanner;
		await scanner.iniciar();
		_suscripcionEscaner = scanner.codigos.listen(_procesarCodigoBarras);
	}

	Future<void> _procesarCodigoBarras(String codigo) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final agregado = await servicio.agregarPorCodigoBarras(codigo);
		await ref.read(carritoNotifierProvider.notifier).recargar();
		if (!agregado && mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('Producto no encontrado: $codigo'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final estadoCarrito = ref.watch(carritoNotifierProvider);
		return estadoCarrito.when(
			data: (estado) => _ConstruirLayoutCaja(estado: estado),
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
	const _ConstruirLayoutCaja({required this.estado});

	final EstadoCarrito estado;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return Scaffold(
			body: Column(
				children: [
					PanelTotal(
						nombreTienda: estado.nombreTienda,
						total: estado.total,
					),
					if (!estado.turnoAbierto)
						Container(
							width: double.infinity,
							color: Colors.orange.shade100,
							padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
							child: const Row(
								children: [
									Icon(Icons.warning_amber, color: Colors.orange, size: 20.0),
									SizedBox(width: 8.0),
									Expanded(
										child: Text(
											'Sin turno abierto — Admin > Corte de caja',
											style: TextStyle(fontWeight: FontWeight.w600),
										),
									),
								],
							),
						),
					if (estado.categorias.isNotEmpty)
						BarraCategorias(
							categorias: estado.categorias,
							categoriaSeleccionadaId: estado.categoriaSeleccionadaId,
							alSeleccionar: (id) {
								ref.read(carritoNotifierProvider.notifier).seleccionarCategoria(id);
							},
						),
					if (estado.favoritos.isNotEmpty)
						SizedBox(
							height: 72.0,
							child: ListView.separated(
								scrollDirection: Axis.horizontal,
								padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
								itemCount: estado.favoritos.length,
								separatorBuilder: (_, __) => const SizedBox(width: 8.0),
								itemBuilder: (context, indice) {
									final producto = estado.favoritos[indice];
									return ActionChip(
										avatar: const Icon(Icons.star, size: 18.0, color: Colors.amber),
										label: Text(
											producto.nombre,
											overflow: TextOverflow.ellipsis,
										),
										onPressed: () {
											_manejarSeleccionProducto(context, ref, producto);
										},
									);
								},
							),
						),
					Expanded(
						child: Row(
							children: [
								Expanded(
									flex: 3,
									child: GrillaProductos(
										productos: estado.productos,
										alSeleccionar: (producto) {
											_manejarSeleccionProducto(context, ref, producto);
										},
									),
								),
								Expanded(
									flex: 2,
									child: PanelCarrito(
										lineas: estado.lineas,
										alEliminarLinea: (indice) {
											ref.read(carritoNotifierProvider.notifier).eliminarLinea(indice);
										},
										alTocarLinea: (indice) {
											_mostrarDescuentoLinea(context, ref, indice, estado.lineas[indice]);
										},
									),
								),
							],
						),
					),
					_BarraAccionesCaja(total: estado.total, estado: estado),
				],
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
		if (producto.moduloVertical == ModuloVertical.carniceria) {
			await _agregarProductoCarniceria(context, ref, producto);
			return;
		}
		if (producto.moduloVertical == ModuloVertical.farmacia) {
			await _agregarProductoFarmacia(context, ref, producto);
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
				title: Text('Presentacion: ${producto.nombre}'),
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

	Future<void> _mostrarDescuentoLinea(
		BuildContext context,
		WidgetRef ref,
		int indice,
		LineaCarrito linea,
	) async {
		final ctrl = TextEditingController(
			text: linea.descuentoLinea > 0 ? '${linea.descuentoLinea}' : '',
		);
		final descuento = await showDialog<double>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text('Descuento: ${linea.producto.nombre}'),
				content: TextField(
					controller: ctrl,
					keyboardType: const TextInputType.numberWithOptions(decimal: true),
					decoration: const InputDecoration(
						labelText: 'Descuento (\$)',
						border: OutlineInputBorder(),
					),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0.0),
						child: const Text('Aplicar'),
					),
				],
			),
		);
		ctrl.dispose();
		if (descuento == null) {
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		servicio.aplicarDescuentoLinea(indice, descuento);
		await ref.read(carritoNotifierProvider.notifier).recargar();
	}
}

/// Barra inferior fija con acciones iconograficas de caja.
class _BarraAccionesCaja extends ConsumerWidget {
	const _BarraAccionesCaja({required this.total, required this.estado});

	final double total;
	final EstadoCarrito estado;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final puedeCobrar = total > 0.0;
		return Container(
			padding: const EdgeInsets.all(8.0),
			color: PosiaColors.tarjeta,
			child: Row(
				children: [
					BotonAccionCaja(
						icono: Icons.qr_code_scanner,
						etiqueta: 'Escanear',
						colorFondo: Colors.blueGrey,
						alPresionar: () => _escanearManual(context, ref),
					),
					BotonAccionCaja(
						icono: Icons.badge,
						etiqueta: estado.nombreVendedor ?? 'Vendedor',
						colorFondo: Colors.deepPurple,
						alPresionar: () => _mostrarSelectorVendedor(context, ref),
					),
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
						icono: Icons.payments,
						etiqueta: 'COBRAR',
						colorFondo: PosiaColors.cobrar,
						habilitado: puedeCobrar,
						alPresionar: () => _ejecutarCobro(context, ref),
					),
				],
			),
		);
	}

	/// Abre dialogo para ingresar codigo de barras manualmente.
	Future<void> _escanearManual(BuildContext context, WidgetRef ref) async {
		final controller = TextEditingController();
		final codigo = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Codigo de barras'),
				content: TextField(
					controller: controller,
					autofocus: true,
					keyboardType: TextInputType.number,
					decoration: const InputDecoration(
						labelText: 'Escanear o escribir codigo',
						border: OutlineInputBorder(),
					),
					onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, controller.text.trim()),
						child: const Text('Agregar'),
					),
				],
			),
		);
		controller.dispose();
		if (codigo == null || codigo.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		final agregado = await servicio.agregarPorCodigoBarras(codigo);
		await ref.read(carritoNotifierProvider.notifier).recargar();
		if (!context.mounted) {
			return;
		}
		if (!agregado) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('Producto no encontrado: $codigo'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}

	/// Pide confirmacion antes de vaciar el carrito.
	Future<void> _confirmarVaciarCarrito(BuildContext context, WidgetRef ref) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Vaciar carrito'),
				content: const Text('Se eliminaran todas las lineas del carrito.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Si, vaciar'),
					),
				],
			),
		);
		if (confirmar == true) {
			await ref.read(carritoNotifierProvider.notifier).vaciarCarrito();
		}
	}

	/// Muestra dialogo de seleccion de vendedor activo.
	Future<void> _mostrarSelectorVendedor(BuildContext context, WidgetRef ref) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final vendedores = await servicio.listarVendedores();
		if (!context.mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (dialogContext) {
				return AlertDialog(
					title: const Text('Seleccionar vendedor'),
					content: SizedBox(
						width: 320.0,
						child: ListView(
							shrinkWrap: true,
							children: vendedores
								.map(
									(vendedor) => ListTile(
										leading: const Icon(Icons.badge),
										title: Text(vendedor.nombre),
										subtitle: Text('Codigo ${vendedor.codigo}'),
										onTap: () async {
											await servicio.seleccionarVendedor(vendedor);
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
				);
			},
		);
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
										await ref.read(carritoNotifierProvider.notifier).recargar();
									},
								),
								...clientes.map(
									(cliente) => ListTile(
										leading: const Icon(Icons.person),
										title: Text(cliente.nombre),
										onTap: () async {
											await servicio.seleccionarCliente(cliente);
											if (dialogContext.mounted) {
												Navigator.of(dialogContext).pop();
											}
											await ref.read(carritoNotifierProvider.notifier).recargar();
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

	/// Ejecuta cobro con dialogo multipago y muestra confirmacion visual.
	Future<void> _ejecutarCobro(BuildContext context, WidgetRef ref) async {
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
			creditoDisponible: cliente?.creditoHabilitado ?? false,
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
		final tienda = await contenedor.servicioAdmin.obtenerTiendaActiva();
		final textoTicket = generarTextoTicket(
			venta: venta,
			nombreTienda: tienda?.nombre ?? 'Tienda',
			montoRecibido: request.montoRecibido,
		);
		final hardware = await ref.read(hardwareRegistryProvider.future);
		await hardware.obtenerImpresora().imprimirTicket(textoTicket);
		if (!context.mounted) {
			return;
		}
		await showDialog<void>(
			context: context,
			builder: (dialogContext) {
				return AlertDialog(
					icon: const Icon(Icons.check_circle, color: PosiaColors.cobrar, size: 64.0),
					title: const Text('Venta completada'),
					content: Text(
						formatearMoneda(venta.total),
						style: Theme.of(context).textTheme.headlineLarge,
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
}
