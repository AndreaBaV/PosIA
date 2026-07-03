/// Ficha detallada de cliente con historial de ventas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../utils/compartir_ticket_digital_util.dart';
import '../utils/ticket_credito_util.dart';
import '../utils/ticket_venta_util.dart';
import 'pantalla_registrar_credito.dart';

class PantallaFichaCliente extends ConsumerStatefulWidget {
	const PantallaFichaCliente({required this.cliente, super.key});

	final Cliente cliente;

	@override
	ConsumerState<PantallaFichaCliente> createState() => _PantallaFichaClienteState();
}

class _PantallaFichaClienteState extends ConsumerState<PantallaFichaCliente>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	late final TextEditingController _nombreController;
	late final TextEditingController _telefonoController;
	late final TextEditingController _emailController;
	late final TextEditingController _rfcController;
	late final TextEditingController _direccionController;
	late final TextEditingController _notasController;
	late final TextEditingController _diasCreditoController;
	late bool _credito;
	String? _listaPreciosId;

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 2, vsync: this);
		final c = widget.cliente;
		_nombreController = TextEditingController(text: c.nombre);
		_telefonoController = TextEditingController(text: c.telefono);
		_emailController = TextEditingController(text: c.email);
		_rfcController = TextEditingController(text: c.rfc);
		_direccionController = TextEditingController(text: c.direccion);
		_notasController = TextEditingController(text: c.notas);
		_diasCreditoController = TextEditingController(text: c.diasCredito.toString());
		_credito = c.creditoHabilitado;
		_listaPreciosId = c.listaPreciosId;
	}

	@override
	void dispose() {
		_tabs.dispose();
		_nombreController.dispose();
		_telefonoController.dispose();
		_emailController.dispose();
		_rfcController.dispose();
		_direccionController.dispose();
		_notasController.dispose();
		_diasCreditoController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final ventasAsync = ref.watch(_ventasClienteProvider(widget.cliente.id));
		final resumenAsync = ref.watch(_resumenClienteProvider(widget.cliente.id));
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.cliente.nombre),
				bottom: TabBar(
					controller: _tabs,
					tabs: const [
						Tab(text: 'Datos'),
						Tab(text: 'Ventas'),
					],
				),
				actions: [
					IconButton(
						icon: const Icon(Icons.delete_outline),
						color: PosiaColors.cancelar,
						tooltip: 'Eliminar cliente',
						onPressed: _confirmarEliminar,
					),
					IconButton(icon: const Icon(Icons.save), onPressed: _guardar),
				],
			),
			body: TabBarView(
				controller: _tabs,
				children: [
					ListView(
						padding: const EdgeInsets.all(16.0),
						children: [
							TextField(
								controller: _nombreController,
								decoration: const InputDecoration(
									labelText: 'Nombre',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _telefonoController,
								keyboardType: TextInputType.phone,
								decoration: const InputDecoration(
									labelText: 'Teléfono * (requerido para crédito)',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _emailController,
								decoration: const InputDecoration(
									labelText: 'Email',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _rfcController,
								decoration: const InputDecoration(
									labelText: 'RFC',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _direccionController,
								maxLines: 2,
								decoration: const InputDecoration(
									labelText: 'Dirección * (requerida para crédito)',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _diasCreditoController,
								keyboardType: TextInputType.number,
								decoration: const InputDecoration(
									labelText: 'Días de crédito predeterminados',
									border: OutlineInputBorder(),
									suffixText: 'días',
									helperText: 'Plazo al fiar en caja',
								),
							),
							const SizedBox(height: 8.0),
							Consumer(
								builder: (context, ref, _) {
									final listasAsync = ref.watch(listasPreciosAdminProvider);
									return listasAsync.when(
										data: (listas) {
											final idsValidos = listas.map((l) => l.id).toSet();
											final listaAsignada = _listaPreciosId != null &&
												idsValidos.contains(_listaPreciosId)
												? _listaPreciosId
												: null;
											final listaHuerfana = _listaPreciosId != null &&
												!idsValidos.contains(_listaPreciosId);
											return Column(
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													if (listaHuerfana)
														Padding(
															padding: const EdgeInsets.only(bottom: 8.0),
															child: Text(
																'La lista asignada ya no existe. '
																'Al guardar se usará precio genérico.',
																style: TextStyle(
																	color: Colors.orange.shade800,
																	fontSize: 13.0,
																),
															),
														),
													DropdownButtonFormField<String?>(
														initialValue: listaAsignada,
														decoration: const InputDecoration(
															labelText: 'Lista de precios',
															border: OutlineInputBorder(),
														),
														items: [
															const DropdownMenuItem<String?>(
																value: null,
																child: Text('Precio genérico (público)'),
															),
															...listas.map(
																(l) => DropdownMenuItem<String?>(
																	value: l.id,
																	child: Text(l.nombre),
																),
															),
														],
														onChanged: (v) => setState(() => _listaPreciosId = v),
													),
												],
											);
										},
										loading: () => const LinearProgressIndicator(),
										error: (e, _) => Text('$e'),
									);
								},
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: _notasController,
								maxLines: 3,
								decoration: const InputDecoration(
									labelText: 'Notas',
									border: OutlineInputBorder(),
								),
							),
							SwitchListTile(
								title: const Text('Crédito habilitado'),
								subtitle: const Text(
									'Requiere teléfono y dirección completos',
								),
								value: _credito,
								onChanged: (v) => setState(() => _credito = v),
							),
							if (clientePuedeRecibirCredito(widget.cliente.copiarCon(
								creditoHabilitado: _credito,
								telefono: _telefonoController.text,
								direccion: _direccionController.text,
							)))
								Padding(
									padding: const EdgeInsets.only(top: 8.0),
									child: OutlinedButton.icon(
										onPressed: _abrirRegistrarCredito,
										icon: const Icon(Icons.handshake),
										label: const Text('Registrar nuevo crédito'),
									),
								),
						],
					),
					Column(
						children: [
							resumenAsync.when(
								data: (r) => Card(
									margin: const EdgeInsets.all(12.0),
									child: Padding(
										padding: const EdgeInsets.all(16.0),
										child: Row(
											mainAxisAlignment: MainAxisAlignment.spaceAround,
											children: [
												_ColumnStat(
													'Ventas',
													'${r.cantidadVentas}',
												),
												_ColumnStat(
													'Total',
													formatearMoneda(r.totalComprado),
												),
											],
										),
									),
								),
								loading: () => const LinearProgressIndicator(),
								error: (e, _) => Text('$e'),
							),
							Expanded(
								child: ventasAsync.when(
									data: (ventas) {
										if (ventas.isEmpty) {
											return const Center(child: Text('Sin ventas'));
										}
										return ListView.builder(
											itemCount: ventas.length,
											itemBuilder: (_, i) {
												final v = ventas[i];
												return ListTile(
													leading: const Icon(Icons.receipt),
													title: Text(formatearMoneda(v.total)),
													subtitle: Text(
														'${v.estado.name} · '
														'${v.creadaEn.toLocal().toString().substring(0, 16)}',
													),
													trailing: IconButton(
														icon: const Icon(Icons.chat),
														tooltip: 'WhatsApp',
														onPressed: () => _compartirVentaWhatsApp(v),
													),
													onTap: () => _compartirVentaWhatsApp(v),
												);
											},
										);
									},
									loading: () => const Center(child: CircularProgressIndicator()),
									error: (e, _) => Center(child: Text('$e')),
								),
							),
						],
					),
				],
			),
		);
	}

	Future<void> _compartirVentaWhatsApp(Venta venta) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final config = await ref.read(configDispositivoProvider.future);
		try {
			final TicketDigitalContenido digital;
			if (venta.metodoPago == MetodoPago.credito && !venta.creditoLiquidado) {
				digital = await obtenerTicketDigitalPagareCliente(
					venta: venta,
					servicioAdmin: servicio,
				);
			} else {
				digital = await obtenerTicketDigitalVenta(
					venta: venta,
					servicioAdmin: servicio,
					config: config,
				);
			}
			if (!mounted) {
				return;
			}
			await compartirTicketDigitalWhatsApp(
				context,
				contenido: digital,
				telefono: _telefonoController.text.trim().isNotEmpty
					? _telefonoController.text.trim()
					: widget.cliente.telefono,
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _guardar() async {
		final diasCredito = int.tryParse(_diasCreditoController.text.trim()) ??
			DIAS_CREDITO_PREDETERMINADO;
		final listas = await ref.read(listasPreciosAdminProvider.future);
		final idsListasValidas = listas.map((l) => l.id).toSet();
		final listaPreciosId = _listaPreciosId != null &&
				idsListasValidas.contains(_listaPreciosId)
			? _listaPreciosId
			: null;
		final actualizado = widget.cliente.copiarCon(
			nombre: _nombreController.text.trim(),
			telefono: _telefonoController.text.trim(),
			email: _emailController.text.trim(),
			rfc: _rfcController.text.trim(),
			direccion: _direccionController.text.trim(),
			notas: _notasController.text.trim(),
			creditoHabilitado: _credito,
			activo: true,
			listaPreciosId: listaPreciosId,
			diasCredito: diasCredito,
		);
		if (_credito) {
			final error = validarClienteParaCredito(actualizado, diasCredito: diasCredito);
			if (error != null) {
				if (!mounted) {
					return;
				}
				PosiaNotificaciones.mostrarSnackBar(context, 
					SnackBar(content: Text(error)),
				);
				return;
			}
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.actualizarCliente(actualizado);
		invalidarListasPrecios(ref);
		ref.invalidate(clientesAdminProvider);
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			const SnackBar(content: Text('Cliente actualizado')),
		);
	}

	Future<void> _abrirRegistrarCredito() async {
		await Navigator.of(context).push<void>(
			MaterialPageRoute<void>(
				builder: (_) => PantallaRegistrarCredito(clienteInicial: widget.cliente),
			),
		);
	}

	Future<void> _confirmarEliminar() async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar cliente'),
				content: Text(
					'¿Eliminar permanentemente a "${widget.cliente.nombre}"?\n\n'
					'No es posible si tiene ventas, pedidos o cotizaciones registradas.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (confirmar != true || !mounted) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.eliminarCliente(widget.cliente.id);
			if (!mounted) {
				return;
			}
			Navigator.of(context).pop();
		} on StateError catch (e) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(
					content: Text(e.message),
					backgroundColor: PosiaColors.cancelar,
				),
			);
		}
	}
}

class _ColumnStat extends StatelessWidget {
	const _ColumnStat(this.etiqueta, this.valor);

	final String etiqueta;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				Text(etiqueta, style: const TextStyle(color: Colors.grey)),
				Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0)),
			],
		);
	}
}

final _ventasClienteProvider = FutureProvider.family<List<Venta>, String>((ref, id) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarVentasCliente(id);
});

final _resumenClienteProvider = FutureProvider.family<ResumenCliente, String>((ref, id) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerResumenCliente(id);
});
