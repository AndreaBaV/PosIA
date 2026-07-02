/// Gestion de pedidos: recibir, asignar a empleados y consultar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../utils/documento_ticket_util.dart';
import '../widgets/acciones_documento_ticket.dart';

class PantallaPedidosAdmin extends ConsumerStatefulWidget {
	const PantallaPedidosAdmin({super.key});

	@override
	ConsumerState<PantallaPedidosAdmin> createState() => _PantallaPedidosAdminState();
}

class _PantallaPedidosAdminState extends ConsumerState<PantallaPedidosAdmin>
	with SingleTickerProviderStateMixin {
	late final TabController _tabs;
	final _notasController = TextEditingController();
	final _busquedaProductoController = TextEditingController();
	final _nombreEntregaController = TextEditingController();
	final _telefonoEntregaController = TextEditingController();
	final _direccionEntregaController = TextEditingController();
	final _cantidadControllers = <String, TextEditingController>{};
	final _seleccionados = <String>{};
	String? _clienteId;
	MetodoPago _metodoPago = MetodoPago.efectivo;
	String _filtroProducto = '';

	@override
	void initState() {
		super.initState();
		_tabs = TabController(length: 3, vsync: this);
	}

	@override
	void dispose() {
		_tabs.dispose();
		_notasController.dispose();
		_busquedaProductoController.dispose();
		_nombreEntregaController.dispose();
		_telefonoEntregaController.dispose();
		_direccionEntregaController.dispose();
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

	@override
	Widget build(BuildContext context) {
		final operador = ref.watch(sesionUsuarioProvider);
		final recibidosAsync = ref.watch(_pedidosRecibidosProvider);
		final todosAsync = ref.watch(_pedidosTodosProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Pedidos'),
				bottom: TabBar(
					controller: _tabs,
					tabs: [
						Tab(
							text: 'Recibidos',
							icon: recibidosAsync.maybeWhen(
								data: (lista) => lista.isNotEmpty
									? Badge(
										label: Text('${lista.length}'),
										child: const Icon(Icons.inbox),
									)
									: const Icon(Icons.inbox),
								orElse: () => const Icon(Icons.inbox),
							),
						),
						const Tab(text: 'Todos', icon: Icon(Icons.list_alt)),
						const Tab(text: 'Nuevo', icon: Icon(Icons.add_box)),
					],
				),
			),
			body: TabBarView(
				controller: _tabs,
				children: [
					_buildListaPedidos(
						recibidosAsync,
						soloAsignacion: true,
						operador: operador,
					),
					_buildListaPedidos(todosAsync, operador: operador),
					_buildNuevoPedido(operador),
				],
			),
		);
	}

	Widget _buildListaPedidos(
		AsyncValue<List<Pedido>> pedidosAsync, {
		required Usuario? operador,
		bool soloAsignacion = false,
	}) {
		return pedidosAsync.when(
			data: (pedidos) {
				if (pedidos.isEmpty) {
					return Center(
						child: Text(
							soloAsignacion
								? 'No hay pedidos pendientes de asignar'
								: 'Sin pedidos registrados',
						),
					);
				}
				return ListView.builder(
					padding: const EdgeInsets.all(12.0),
					itemCount: pedidos.length,
					itemBuilder: (context, indice) {
						final pedido = pedidos[indice];
						return _TarjetaPedidoAdmin(
							pedido: pedido,
							alAsignar: pedido.pendienteAsignacion
								? () => _asignarPedido(pedido, operador)
								: null,
							alCancelar: pedido.estado != EstadoPedido.entregado &&
								pedido.estado != EstadoPedido.cancelado
								? () => _cancelarPedido(pedido, operador)
								: null,
							alVerDetalle: () => _mostrarDetalle(pedido),
						);
					},
				);
			},
			loading: () => const Center(child: CircularProgressIndicator()),
			error: (e, _) => Center(child: Text('$e')),
		);
	}

	Widget _buildNuevoPedido(Usuario? operador) {
		final datosAsync = ref.watch(_pedidosDatosProvider);
		return datosAsync.when(
			data: (datos) {
				final productos = datos.productos.where((p) {
					if (_filtroProducto.isEmpty) {
						return true;
					}
					final q = _filtroProducto.toLowerCase();
					return p.nombre.toLowerCase().contains(q) ||
						p.codigoBarras.toLowerCase().contains(q);
				}).toList();
				return Column(
					children: [
						Expanded(
							child: ListView(
								padding: const EdgeInsets.all(12.0),
								children: [
									DropdownButtonFormField<String?>(
										initialValue: _clienteId,
										isExpanded: true,
										decoration: const InputDecoration(
											labelText: 'Cliente (opcional)',
											border: OutlineInputBorder(),
										),
										items: [
											const DropdownMenuItem<String?>(
												value: null,
												child: Text('Sin cliente registrado'),
											),
											...datos.clientes.map(
												(c) => DropdownMenuItem<String?>(
													value: c.id,
													child: Text(c.nombre),
												),
											),
										],
										onChanged: (v) {
											setState(() {
												_clienteId = v;
												if (v != null) {
													final cliente = datos.clientes
														.firstWhere((c) => c.id == v);
													_nombreEntregaController.text = cliente.nombre;
													_telefonoEntregaController.text = cliente.telefono;
													_direccionEntregaController.text = cliente.direccion;
												}
											});
										},
									),
									const SizedBox(height: 8.0),
									TextField(
										controller: _nombreEntregaController,
										decoration: const InputDecoration(
											labelText: 'Entregar a *',
											border: OutlineInputBorder(),
										),
									),
									const SizedBox(height: 8.0),
									TextField(
										controller: _telefonoEntregaController,
										keyboardType: TextInputType.phone,
										decoration: const InputDecoration(
											labelText: 'Teléfono *',
											border: OutlineInputBorder(),
										),
									),
									const SizedBox(height: 8.0),
									TextField(
										controller: _direccionEntregaController,
										maxLines: 2,
										decoration: const InputDecoration(
											labelText: 'Dirección de entrega *',
											border: OutlineInputBorder(),
										),
									),
									const SizedBox(height: 8.0),
									const Text(
										'Forma de pago',
										style: TextStyle(fontWeight: FontWeight.w600),
									),
									const SizedBox(height: 8.0),
									Wrap(
										spacing: 8.0,
										runSpacing: 8.0,
										children: [
											_metodoChip(MetodoPago.efectivo, 'Efectivo'),
											_metodoChip(MetodoPago.tarjeta, 'Tarjeta'),
											_metodoChip(MetodoPago.transferencia, 'Transferencia'),
											_metodoChip(MetodoPago.credito, 'Crédito'),
										],
									),
									const SizedBox(height: 12.0),
									CampoBusqueda(
										controlador: _busquedaProductoController,
										sugerencia: 'Buscar producto...',
										alCambiar: (v) => setState(() => _filtroProducto = v.trim()),
									),
									const SizedBox(height: 8.0),
									...productos.map((producto) {
										final seleccionado = _seleccionados.contains(producto.id);
										return Card(
											child: CheckboxListTile(
												value: seleccionado,
												onChanged: (v) => setState(() {
													if (v == true) {
														_seleccionados.add(producto.id);
													} else {
														_seleccionados.remove(producto.id);
													}
												}),
												title: Text(producto.nombre),
												subtitle: Text(
													'${formatearMoneda(producto.precioBase)} · '
													'${producto.codigoBarras}',
												),
												secondary: seleccionado
													? SizedBox(
														width: 72.0,
														child: TextField(
															controller: _controllerCantidad(producto.id),
															keyboardType: TextInputType.number,
															decoration: const InputDecoration(
																labelText: 'Cant.',
																isDense: true,
															),
														),
													)
													: null,
											),
										);
									}),
									const SizedBox(height: 8.0),
									TextField(
										controller: _notasController,
										maxLines: 2,
										decoration: const InputDecoration(
											labelText: 'Notas del pedido',
											border: OutlineInputBorder(),
										),
									),
								],
							),
						),
						SafeArea(
							child: Padding(
								padding: const EdgeInsets.all(12.0),
								child: FilledButton.icon(
									onPressed: _seleccionados.isEmpty
										? null
										: () => _registrarPedido(datos, operador),
									icon: const Icon(Icons.save),
									label: Text(
										'Registrar pedido (${_seleccionados.length} prod.)',
									),
								),
							),
						),
					],
				);
			},
			loading: () => const Center(child: CircularProgressIndicator()),
			error: (e, _) => Center(child: Text('$e')),
		);
	}

	Widget _metodoChip(MetodoPago metodo, String etiqueta) {
		return FilterChip(
			selected: _metodoPago == metodo,
			label: Text(etiqueta),
			onSelected: (_) => setState(() => _metodoPago = metodo),
		);
	}

	List<LineaPedidoSolicitud> _construirLineas(List<Producto> productos) {
		return _seleccionados.map((productoId) {
			final producto = productos.firstWhere((p) => p.id == productoId);
			final cantidad = double.tryParse(
				_controllerCantidad(productoId).text.replaceAll(',', '.'),
			) ?? 1.0;
			return LineaPedidoSolicitud(
				productoId: productoId,
				cantidad: cantidad,
				precioUnitario: producto.precioBase,
			);
		}).toList();
	}

	Future<void> _registrarPedido(_DatosPedidos datos, Usuario? operador) async {
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.registrarPedido(
				lineas: _construirLineas(datos.productos),
				nombreEntrega: _nombreEntregaController.text,
				telefonoEntrega: _telefonoEntregaController.text,
				direccionEntrega: _direccionEntregaController.text,
				metodoPago: _metodoPago,
				clienteId: _clienteId,
				notas: _notasController.text.trim(),
				tiendaId: datos.tiendaId,
				operador: operador,
			);
			ref.invalidate(_pedidosRecibidosProvider);
			ref.invalidate(_pedidosTodosProvider);
			setState(() {
				_seleccionados.clear();
				_clienteId = null;
				_metodoPago = MetodoPago.efectivo;
				_nombreEntregaController.clear();
				_telefonoEntregaController.clear();
				_direccionEntregaController.clear();
				_notasController.clear();
			});
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Pedido registrado')),
			);
			_tabs.animateTo(0);
		} catch (error) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _asignarPedido(Pedido pedido, Usuario? operador) async {
		final empleados = await ref.refresh(empleadosAsignacionProvider.future);
		if (!mounted) {
			return;
		}
		if (empleados.isEmpty) {
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(
					content: Text('No hay empleados disponibles para asignar'),
					backgroundColor: PosiaColors.cancelar,
				),
			);
			return;
		}
		final empleadoId = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Asignar pedido'),
				content: SizedBox(
					width: 360.0,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text('Entregar a: ${pedido.nombreEntrega}'),
							Text(
								formatearMoneda(pedido.total),
								style: const TextStyle(fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 12.0),
							const Text('Seleccione empleado:'),
							const SizedBox(height: 8.0),
							...empleados.map(
								(e) => ListTile(
									leading: const Icon(Icons.badge),
									title: Text(e.nombre),
									subtitle: Text(e.codigo),
									onTap: () => Navigator.pop(ctx, e.id),
								),
							),
						],
					),
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx),
						child: const Text('Cancelar'),
					),
				],
			),
		);
		if (empleadoId == null) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.asignarPedido(
				pedidoId: pedido.id,
				empleadoUsuarioId: empleadoId,
				operador: operador,
			);
			ref.invalidate(_pedidosRecibidosProvider);
			ref.invalidate(_pedidosTodosProvider);
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Pedido asignado')),
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

	Future<void> _cancelarPedido(Pedido pedido, Usuario? operador) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Cancelar pedido'),
				content: Text(
					'Cancelar pedido para ${pedido.nombreEntrega}?',
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Si')),
				],
			),
		);
		if (confirmar != true) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.cancelarPedido(pedidoId: pedido.id, operador: operador);
			ref.invalidate(_pedidosRecibidosProvider);
			ref.invalidate(_pedidosTodosProvider);
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Pedido cancelado')),
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

	void _mostrarDetalle(Pedido pedido) {
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.6,
				maxChildSize: 0.92,
				builder: (context, scrollController) => Padding(
					padding: const EdgeInsets.all(20.0),
					child: ListView(
						controller: scrollController,
						children: [
							Text(
								'Pedido ${pedido.id.substring(0, 8).toUpperCase()}',
								style: Theme.of(context).textTheme.titleLarge,
							),
							Text(etiquetaEstadoPedido(pedido.estado)),
							if (pedido.asignadoAUsuarioNombre != null)
								Text('Asignado a: ${pedido.asignadoAUsuarioNombre}'),
							const Divider(height: 24.0),
							_ListaDato('Entregar a', pedido.nombreEntrega),
							_ListaDato('Teléfono', pedido.telefonoEntrega),
							_ListaDato('Dirección', pedido.direccionEntrega),
							_ListaDato('Pago', etiquetaMetodoPago(pedido.metodoPago)),
							if (pedido.esCredito)
								_ListaDato(
									'Crédito',
									'${pedido.creditoDias ?? '?'} días'
									'${pedido.creditoVenceEn != null ? ' · vence ${formatearFechaCredito(pedido.creditoVenceEn!.toLocal())}' : ''}',
								),
							_ListaDato('Total', formatearMoneda(pedido.total)),
							if (pedido.notas.isNotEmpty)
								_ListaDato('Notas', pedido.notas),
							const SizedBox(height: 12.0),
							const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold)),
							...pedido.lineas.map(
								(l) => ListTile(
									dense: true,
									contentPadding: EdgeInsets.zero,
									title: Text(l.nombreProducto),
									subtitle: Text(
										'${l.cantidad} x ${formatearMoneda(l.precioUnitario)}',
									),
									trailing: Text(formatearMoneda(l.subtotal)),
								),
							),
							const SizedBox(height: 12.0),
							AccionesDocumentoTicket(
								onWhatsApp: () async {
									final servicio = await ref.read(servicioAdminProvider.future);
									final texto = await construirTextoPedido(
										pedido: pedido,
										servicio: servicio,
									);
									await compartirDocumentoWhatsApp(
										context,
										texto: texto,
										telefono: pedido.telefonoEntrega,
									);
								},
								onCerrar: () => Navigator.pop(ctx),
							),
						],
					),
				),
			),
		);
	}
}

class _TarjetaPedidoAdmin extends StatelessWidget {
	const _TarjetaPedidoAdmin({
		required this.pedido,
		this.alAsignar,
		this.alCancelar,
		required this.alVerDetalle,
	});

	final Pedido pedido;
	final VoidCallback? alAsignar;
	final VoidCallback? alCancelar;
	final VoidCallback alVerDetalle;

	@override
	Widget build(BuildContext context) {
		return Card(
			margin: const EdgeInsets.only(bottom: 8.0),
			child: InkWell(
				onTap: alVerDetalle,
				borderRadius: BorderRadius.circular(12.0),
				child: Padding(
					padding: const EdgeInsets.all(12.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											pedido.nombreEntrega,
											style: const TextStyle(
												fontWeight: FontWeight.bold,
												fontSize: 16.0,
											),
										),
									),
									if (pedido.esCredito)
										Container(
											padding: const EdgeInsets.symmetric(
												horizontal: 8.0,
												vertical: 2.0,
											),
											decoration: BoxDecoration(
												color: Colors.amber.shade100,
												borderRadius: BorderRadius.circular(8.0),
											),
											child: const Text(
												'CREDITO',
												style: TextStyle(
													fontSize: 11.0,
													fontWeight: FontWeight.bold,
												),
											),
										),
								],
							),
							const SizedBox(height: 4.0),
							Text(pedido.direccionEntrega, style: const TextStyle(color: Colors.grey)),
							Text('Tel: ${pedido.telefonoEntrega}'),
							const SizedBox(height: 6.0),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: [
									Text(
										formatearMoneda(pedido.total),
										style: const TextStyle(fontWeight: FontWeight.w600),
									),
									Text(etiquetaEstadoPedido(pedido.estado)),
								],
							),
							if (pedido.asignadoAUsuarioNombre != null)
								Text('Empleado: ${pedido.asignadoAUsuarioNombre}'),
							if (alAsignar != null || alCancelar != null) ...[
								const SizedBox(height: 8.0),
								Row(
									children: [
										if (alAsignar != null)
											Expanded(
												child: FilledButton.icon(
													onPressed: alAsignar,
													icon: const Icon(Icons.person_add),
													label: const Text('Asignar'),
												),
											),
										if (alAsignar != null && alCancelar != null)
											const SizedBox(width: 8.0),
										if (alCancelar != null)
											IconButton(
												onPressed: alCancelar,
												icon: const Icon(Icons.cancel, color: PosiaColors.cancelar),
												tooltip: 'Cancelar',
											),
									],
								),
							],
						],
					),
				),
			),
		);
	}
}

class _ListaDato extends StatelessWidget {
	const _ListaDato(this.etiqueta, this.valor);

	final String etiqueta;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 6.0),
			child: RichText(
				text: TextSpan(
					style: DefaultTextStyle.of(context).style,
					children: [
						TextSpan(
							text: '$etiqueta: ',
							style: const TextStyle(fontWeight: FontWeight.w600),
						),
						TextSpan(text: valor),
					],
				),
			),
		);
	}
}

class _DatosPedidos {
	const _DatosPedidos({
		required this.tiendaId,
		required this.productos,
		required this.clientes,
	});

	final String tiendaId;
	final List<Producto> productos;
	final List<Cliente> clientes;
}

final _pedidosDatosProvider = FutureProvider<_DatosPedidos>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final productos = await servicio.listarProductosCatalogo();
	final clientes = await servicio.listarClientes();
	return _DatosPedidos(
		tiendaId: servicio.tiendaActivaId,
		productos: productos.where((p) => p.activo).toList(),
		clientes: clientes.where((c) => c.activo).toList(),
	);
});

final _pedidosRecibidosProvider = FutureProvider<List<Pedido>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	return servicio.listarPedidosRecibidos(operador: operador);
});

final _pedidosTodosProvider = FutureProvider<List<Pedido>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	return servicio.listarPedidosTienda(operador: operador);
});
