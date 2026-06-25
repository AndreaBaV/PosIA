/// Registro de venta a credito desde administracion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/ticket_credito_util.dart';
import '../widgets/dialogo_completar_datos_credito.dart';

class PantallaRegistrarCredito extends ConsumerStatefulWidget {
	const PantallaRegistrarCredito({this.clienteInicial, super.key});

	final Cliente? clienteInicial;

	@override
	ConsumerState<PantallaRegistrarCredito> createState() =>
		_PantallaRegistrarCreditoState();
}

class _PantallaRegistrarCreditoState extends ConsumerState<PantallaRegistrarCredito> {
	final _busquedaController = TextEditingController();
	final _diasCreditoController = TextEditingController();
	final _cantidadControllers = <String, TextEditingController>{};
	final _seleccionados = <String>{};
	String? _clienteId;
	String _filtroProducto = '';
	var _aceptaPlazo = false;
	var _guardando = false;

	@override
	void initState() {
		super.initState();
		_clienteId = widget.clienteInicial?.id;
		_diasCreditoController.text = (widget.clienteInicial?.diasCredito ??
				DIAS_CREDITO_PREDETERMINADO)
			.toString();
	}

	@override
	void dispose() {
		_busquedaController.dispose();
		_diasCreditoController.dispose();
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
		final productos = ref.read(_productosCreditoProvider).asData?.value ?? [];
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
		final clientesAsync = ref.watch(_clientesCreditoProvider);
		final productosAsync = ref.watch(_productosCreditoProvider);
		Cliente? clienteSeleccionado = widget.clienteInicial;
		if (clientesAsync.hasValue && _clienteId != null) {
			for (final c in clientesAsync.requireValue) {
				if (c.id == _clienteId) {
					clienteSeleccionado = c;
					break;
				}
			}
		}
		final clientePendiente = clienteSeleccionado;

		return Scaffold(
			appBar: AppBar(title: const Text('Nuevo crédito')),
			body: ListView(
				padding: const EdgeInsets.all(16.0),
				children: [
					Text(
						'Fiado al cliente',
						style: Theme.of(context).textTheme.titleMedium,
					),
					const SizedBox(height: 4.0),
					const Text(
						'Seleccione cliente y productos. También puede fiar desde Caja '
						'con método de pago "Crédito".',
						style: TextStyle(color: Colors.grey, fontSize: 13.0),
					),
					const SizedBox(height: 12.0),
					clientesAsync.when(
						data: (clientes) => DropdownButtonFormField<String?>(
							initialValue: _clienteId,
							decoration: const InputDecoration(
								labelText: 'Cliente *',
								border: OutlineInputBorder(),
							),
							items: [
								const DropdownMenuItem<String?>(
									value: null,
									child: Text('Seleccione cliente...'),
								),
								...clientes.map(
									(c) => DropdownMenuItem<String?>(
										value: c.id,
										child: Text(
											clientePuedeRecibirCredito(c)
												? c.nombre
												: '${c.nombre} (sin crédito listo)',
										),
									),
								),
							],
							onChanged: (id) {
								setState(() {
									_clienteId = id;
									if (id != null) {
										for (final c in clientes) {
											if (c.id == id) {
												_diasCreditoController.text = c.diasCredito.toString();
												break;
											}
										}
									}
								});
							},
						),
						loading: () => const LinearProgressIndicator(),
						error: (e, _) => Text('$e'),
					),
					if (clientePendiente != null &&
						!clientePuedeRecibirCredito(clientePendiente)) ...[
						const SizedBox(height: 8.0),
						OutlinedButton.icon(
							onPressed: () => _habilitarCreditoCliente(clientePendiente),
							icon: const Icon(Icons.edit),
							label: const Text('Completar datos y habilitar crédito'),
						),
					],
					const SizedBox(height: 16.0),
					TextField(
						controller: _diasCreditoController,
						keyboardType: TextInputType.number,
						decoration: const InputDecoration(
							labelText: 'Días para pagar',
							border: OutlineInputBorder(),
							suffixText: 'días',
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
					const SizedBox(height: 8.0),
					CheckboxListTile(
						contentPadding: EdgeInsets.zero,
						title: const Text('El cliente acepta pagar en el plazo indicado'),
						value: _aceptaPlazo,
						onChanged: (v) => setState(() => _aceptaPlazo = v ?? false),
					),
					const SizedBox(height: 8.0),
					FilledButton.icon(
						onPressed: _guardando ? null : _registrar,
						icon: _guardando
							? const SizedBox(
								width: 18.0,
								height: 18.0,
								child: CircularProgressIndicator(strokeWidth: 2.0),
							)
							: const Icon(Icons.handshake),
						label: const Text('Registrar crédito'),
					),
				],
			),
		);
	}

	Future<void> _habilitarCreditoCliente(Cliente cliente) async {
		final actualizado = await mostrarDialogoCompletarDatosCredito(
			context: context,
			cliente: cliente,
		);
		if (actualizado == null || !mounted) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarCliente(actualizado);
		ref.invalidate(_clientesCreditoProvider);
		setState(() {
			_clienteId = actualizado.id;
			_diasCreditoController.text = actualizado.diasCredito.toString();
		});
	}

	Future<void> _registrar() async {
		if (_clienteId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Seleccione un cliente'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		if (_seleccionados.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Seleccione al menos un producto'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		if (!_aceptaPlazo) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Confirme que el cliente acepta el plazo de pago'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		final dias = int.tryParse(_diasCreditoController.text.trim()) ??
			DIAS_CREDITO_PREDETERMINADO;
		if (dias <= 0) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Indique días de crédito válidos'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}

		final productos = await ref.read(_productosCreditoProvider.future);
		final lineas = <LineaPedidoSolicitud>[];
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
				LineaPedidoSolicitud(
					productoId: producto.id,
					cantidad: cantidad,
					precioUnitario: producto.precioBase,
				),
			);
		}

		setState(() => _guardando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final operador = ref.read(sesionUsuarioProvider);
			final venta = await servicio.registrarVentaCredito(
				clienteId: _clienteId!,
				lineas: lineas,
				diasCredito: dias,
				operador: operador,
			);
			final hardware = await ref.read(hardwareRegistryProvider.future);
			final pagares = await construirTextosPagareCredito(
				venta: venta,
				servicioAdmin: servicio,
			);
			for (final pagare in pagares) {
				await hardware.obtenerImpresora().imprimirTicket(pagare);
			}
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						'Crédito registrado: ${formatearMoneda(venta.total)}',
					),
					backgroundColor: PosiaColors.cobrar,
				),
			);
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

final _clientesCreditoProvider = FutureProvider<List<Cliente>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarClientes();
});

final _productosCreditoProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProductosCatalogo();
});
