/// Registro de cotización desde administración.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/compartir_ticket_digital_util.dart';
import '../utils/ticket_venta_util.dart';

class PantallaRegistrarCotizacion extends ConsumerStatefulWidget {
	const PantallaRegistrarCotizacion({this.clienteInicial, super.key});

	final Cliente? clienteInicial;

	@override
	ConsumerState<PantallaRegistrarCotizacion> createState() =>
		_PantallaRegistrarCotizacionState();
}

class _PantallaRegistrarCotizacionState extends ConsumerState<PantallaRegistrarCotizacion> {
	final _busquedaController = TextEditingController();
	final _notasController = TextEditingController();
	final _vigenciaController = TextEditingController();
	final _cantidadControllers = <String, TextEditingController>{};
	final _seleccionados = <String>{};
	String? _clienteId;
	String _filtroProducto = '';
	var _guardando = false;

	@override
	void initState() {
		super.initState();
		_clienteId = widget.clienteInicial?.id;
		_vigenciaController.text = VIGENCIA_COTIZACION_DIAS.toString();
	}

	@override
	void dispose() {
		_busquedaController.dispose();
		_notasController.dispose();
		_vigenciaController.dispose();
		for (final ctrl in _cantidadControllers.values) {
			ctrl.dispose();
		}
		super.dispose();
	}

	TextEditingController _controllerCantidad(String productoId) {
		return _cantidadControllers.putIfAbsent(
			productoId,
			() => TextEditingController(text: '1'),
		);
	}

	double get _totalEstimado {
		final productos = ref.read(_productosCotizacionProvider).asData?.value ?? [];
		var total = 0.0;
		for (final producto in productos) {
			if (!_seleccionados.contains(producto.id)) {
				continue;
			}
			final cantidad = double.tryParse(_controllerCantidad(producto.id).text) ?? 0.0;
			total += cantidad * producto.precioBase;
		}
		return redondearMonto(total);
	}

	@override
	Widget build(BuildContext context) {
		final clientesAsync = ref.watch(_clientesCotizacionProvider);
		final productosAsync = ref.watch(_productosCotizacionProvider);

		return Scaffold(
			appBar: AppBar(title: const Text('Nueva cotización')),
			body: ListView(
				padding: const EdgeInsets.all(16.0),
				children: [
					Text(
						'Cotización al cliente',
						style: Theme.of(context).textTheme.titleMedium,
					),
					const SizedBox(height: 4.0),
					const Text(
						'Seleccione productos y opcionalmente un cliente. '
						'También puede cotizar desde Caja con el botón "Cotizar".',
						style: TextStyle(color: Colors.grey, fontSize: 13.0),
					),
					const SizedBox(height: 12.0),
					clientesAsync.when(
						data: (clientes) => DropdownButtonFormField<String?>(
							key: ValueKey('cliente_$_clienteId'),
							initialValue: _clienteId,
							decoration: const InputDecoration(
								labelText: 'Cliente (opcional)',
								border: OutlineInputBorder(),
							),
							items: [
								const DropdownMenuItem<String?>(
									value: null,
									child: Text('Mostrador / sin cliente'),
								),
								...clientes.map(
									(c) => DropdownMenuItem<String?>(
										value: c.id,
										child: Text(c.nombre),
									),
								),
							],
							onChanged: (id) => setState(() => _clienteId = id),
						),
						loading: () => const LinearProgressIndicator(),
						error: (e, _) => Text('$e'),
					),
					const SizedBox(height: 16.0),
					TextField(
						controller: _vigenciaController,
						keyboardType: TextInputType.number,
						decoration: const InputDecoration(
							labelText: 'Vigencia',
							border: OutlineInputBorder(),
							suffixText: 'días',
						),
					),
					const SizedBox(height: 12.0),
					TextField(
						controller: _notasController,
						maxLines: 2,
						decoration: const InputDecoration(
							labelText: 'Notas (opcional)',
							border: OutlineInputBorder(),
						),
					),
					const SizedBox(height: 16.0),
					Text(
						'Productos',
						style: Theme.of(context).textTheme.titleMedium,
					),
					const SizedBox(height: 8.0),
					TextField(
						controller: _busquedaController,
						decoration: const InputDecoration(
							labelText: 'Buscar producto',
							border: OutlineInputBorder(),
							prefixIcon: Icon(Icons.search),
						),
						onChanged: (v) => setState(() => _filtroProducto = v.trim().toLowerCase()),
					),
					const SizedBox(height: 8.0),
					productosAsync.when(
						data: (productos) {
							final filtrados = productos.where((p) {
								if (_filtroProducto.isEmpty) {
									return true;
								}
								return p.nombre.toLowerCase().contains(_filtroProducto) ||
									p.codigoBarras.contains(_filtroProducto);
							}).toList();
							if (filtrados.isEmpty) {
								return const Text('Sin productos en catálogo');
							}
							return Column(
								children: filtrados.take(40).map((producto) {
									final seleccionado = _seleccionados.contains(producto.id);
									return Card(
										child: Padding(
											padding: const EdgeInsets.symmetric(
												horizontal: 8.0,
												vertical: 4.0,
											),
											child: Row(
												children: [
													Checkbox(
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
													),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(producto.nombre),
																Text(
																	formatearMoneda(producto.precioBase),
																	style: const TextStyle(
																		fontSize: 12.0,
																		color: Colors.grey,
																	),
																),
															],
														),
													),
													if (seleccionado)
														SizedBox(
															width: 72.0,
															child: TextField(
																controller: _controllerCantidad(producto.id),
																keyboardType: const TextInputType.numberWithOptions(
																	decimal: true,
																),
																decoration: const InputDecoration(
																	labelText: 'Cant.',
																	isDense: true,
																),
																onChanged: (_) => setState(() {}),
															),
														),
												],
											),
										),
									);
								}).toList(),
							);
						},
						loading: () => const Center(child: CircularProgressIndicator()),
						error: (e, _) => Text('$e'),
					),
					const SizedBox(height: 12.0),
					Text(
						'Total: ${formatearMoneda(_totalEstimado)}',
						style: Theme.of(context).textTheme.titleLarge?.copyWith(
							fontWeight: FontWeight.bold,
							color: PosiaColors.cobrar,
						),
						textAlign: TextAlign.center,
					),
					const SizedBox(height: 12.0),
					FilledButton.icon(
						onPressed: _guardando ? null : _registrar,
						icon: _guardando
							? const SizedBox(
								width: 18.0,
								height: 18.0,
								child: CircularProgressIndicator(strokeWidth: 2.0),
							)
							: const Icon(Icons.request_quote),
						label: Text(_guardando ? 'Guardando…' : 'Guardar cotización'),
					),
				],
			),
		);
	}

	Future<void> _registrar() async {
		if (_seleccionados.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Seleccione al menos un producto'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		final vigencia = int.tryParse(_vigenciaController.text.trim()) ??
			VIGENCIA_COTIZACION_DIAS;
		if (vigencia <= 0) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Indique días de vigencia válidos'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}

		final productos = await ref.read(_productosCotizacionProvider.future);
		final lineas = <LineaCotizacion>[];
		for (final producto in productos) {
			if (!_seleccionados.contains(producto.id)) {
				continue;
			}
			final cantidad = double.tryParse(_controllerCantidad(producto.id).text) ?? 0.0;
			if (cantidad <= 0) {
				if (!mounted) {
					return;
				}
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Cantidad inválida para ${producto.nombre}'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
			lineas.add(
				LineaCotizacion(
					productoId: producto.id,
					nombreProducto: producto.nombre,
					cantidad: cantidad,
					precioUnitario: producto.precioBase,
				),
			);
		}

		setState(() => _guardando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final cotizacion = await servicio.registrarCotizacion(
				lineas: lineas,
				clienteId: _clienteId,
				notas: _notasController.text,
				vigenciaDias: vigencia,
			);
			final tienda = await servicio.obtenerTiendaActiva();
			final nombreTienda = tienda?.nombre ?? 'Tienda';
			final digital = construirTicketDigitalDesdeCotizacion(
				cotizacion: cotizacion,
				nombreTienda: nombreTienda,
				direccionTienda: tienda?.direccion,
			);
			final texto = construirTextoCotizacionGuardada(
				cotizacion: cotizacion,
				nombreTienda: nombreTienda,
				direccionTienda: tienda?.direccion,
			);
			final hardware = await ref.read(hardwareRegistryProvider.future);
			await hardware.obtenerImpresora().imprimirTicket(texto);

			String? telefonoCliente;
			if (_clienteId != null) {
				final cliente = await servicio.obtenerCliente(_clienteId!);
				telefonoCliente = cliente?.telefono;
			}

			if (!mounted) {
				return;
			}
			await showDialog<void>(
				context: context,
				builder: (dialogContext) => AlertDialog(
					icon: const Icon(Icons.request_quote, color: PosiaColors.neutro, size: 56.0),
					title: const Text('Cotización guardada'),
					content: Text(
						'Folio ${cotizacion.id.substring(0, 8).toUpperCase()}\n'
						'${formatearMoneda(cotizacion.total)}',
						style: Theme.of(context).textTheme.headlineSmall,
						textAlign: TextAlign.center,
					),
					actions: [
						TextButton.icon(
							onPressed: () async {
								await compartirTicketDigitalWhatsApp(
									context,
									contenido: digital,
									telefono: telefonoCliente,
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
			if (!mounted) {
				return;
			}
			Navigator.of(context).pop(true);
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(e.message),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		} finally {
			if (mounted) {
				setState(() => _guardando = false);
			}
		}
	}
}

final _clientesCotizacionProvider = FutureProvider<List<Cliente>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarClientes();
});

final _productosCotizacionProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductosCatalogo();
});
