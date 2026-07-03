/// Historial de ventas con filtros, detalle enriquecido y eliminacion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../models/item_historial.dart';
import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/compartir_ticket_digital_util.dart';
import '../utils/documento_ticket_util.dart';
import '../utils/imprimir_ticket_digital_util.dart';
import '../utils/ticket_credito_util.dart';
import '../utils/ticket_venta_util.dart';
import '../widgets/acciones_documento_ticket.dart';

/// Color distintivo para pedidos entregados en historial.
const _colorPedidoHistorial = Color(0xFF1565C0);

class PantallaHistorialVentas extends ConsumerStatefulWidget {
	const PantallaHistorialVentas({super.key});

	@override
	ConsumerState<PantallaHistorialVentas> createState() =>
		_PantallaHistorialVentasState();
}

class _PantallaHistorialVentasState extends ConsumerState<PantallaHistorialVentas> {
	int _diasAtras = 7;
	final _busquedaController = TextEditingController();
	String _filtro = '';

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted) {
				ref.invalidate(historialOperacionesProvider(_diasAtras));
			}
		});
	}

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final historialAsync = ref.watch(historialOperacionesProvider(_diasAtras));
		return Scaffold(
			appBar: AppBar(title: const Text('Historial')),
			body: Column(
				children: [
					Padding(
						padding: const EdgeInsets.all(12.0),
						child: SegmentedButton<int>(
							segments: const [
								ButtonSegment(value: 1, label: Text('Hoy')),
								ButtonSegment(value: 7, label: Text('7 días')),
								ButtonSegment(value: 30, label: Text('30 días')),
							],
							selected: {_diasAtras},
							onSelectionChanged: (s) => setState(() => _diasAtras = s.first),
						),
					),
					CampoBusqueda(
						controlador: _busquedaController,
						sugerencia: 'Buscar por monto, producto o cliente...',
						alCambiar: (v) => setState(() => _filtro = v.trim().toLowerCase()),
					),
					Expanded(
						child: historialAsync.when(
							data: (items) {
								final filtradas = items.where(_coincideFiltro).toList();
								if (filtradas.isEmpty) {
									return const Center(
										child: Text('Sin ventas ni pedidos en el período'),
									);
								}
								return ListView.builder(
									itemCount: filtradas.length,
									itemBuilder: (context, i) {
										final item = filtradas[i];
										return Card(
											margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
											child: ListTile(
												leading: Icon(
													_iconoItemHistorial(item),
													color: _colorItemHistorial(item),
												),
												title: Text(
													formatearMoneda(item.total),
													style: const TextStyle(fontWeight: FontWeight.bold),
												),
												subtitle: Text(_subtituloItemHistorial(item)),
												trailing: item.tipo == TipoRegistroHistorial.venta &&
													item.venta!.puedeAnularse()
													? IconButton(
														icon: const Icon(Icons.undo, color: PosiaColors.cancelar),
														tooltip: 'Anular',
														onPressed: () => _anular(item.venta!.id),
													)
													: null,
												onTap: () => _abrirDetalle(context, item),
											),
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
		);
	}

	bool _coincideFiltro(ItemHistorial item) {
		if (_filtro.isEmpty) {
			return true;
		}
		if (formatearMoneda(item.total).toLowerCase().contains(_filtro)) {
			return true;
		}
		return switch (item.tipo) {
			TipoRegistroHistorial.venta => _coincideFiltroVenta(item.venta!),
			TipoRegistroHistorial.pedidoEntregado => _coincideFiltroPedido(item.pedido!),
		};
	}

	bool _coincideFiltroVenta(Venta venta) {
		for (final linea in venta.lineas) {
			if (linea.nombreProducto.toLowerCase().contains(_filtro)) {
				return true;
			}
		}
		return false;
	}

	bool _coincideFiltroPedido(Pedido pedido) {
		if (pedido.nombreEntrega.toLowerCase().contains(_filtro)) {
			return true;
		}
		if (pedido.telefonoEntrega.contains(_filtro)) {
			return true;
		}
		for (final linea in pedido.lineas) {
			if (linea.nombreProducto.toLowerCase().contains(_filtro)) {
				return true;
			}
		}
		return false;
	}

	IconData _iconoItemHistorial(ItemHistorial item) {
		return switch (item.tipo) {
			TipoRegistroHistorial.venta =>
				item.venta!.estado == EstadoVenta.completada
					? Icons.receipt_long
					: Icons.cancel,
			TipoRegistroHistorial.pedidoEntregado => Icons.local_shipping_outlined,
		};
	}

	Color _colorItemHistorial(ItemHistorial item) {
		return switch (item.tipo) {
			TipoRegistroHistorial.venta =>
				item.venta!.estado == EstadoVenta.completada
					? PosiaColors.cobrar
					: PosiaColors.cancelar,
			TipoRegistroHistorial.pedidoEntregado => _colorPedidoHistorial,
		};
	}

	String _subtituloItemHistorial(ItemHistorial item) {
		final fecha = item.fecha.toLocal().toString().substring(0, 16);
		return switch (item.tipo) {
			TipoRegistroHistorial.venta => () {
				final venta = item.venta!;
				return 'Venta · ${venta.lineas.length} productos · '
					'${etiquetaMetodoPago(venta.metodoPago)}'
					'${venta.metodoPago == MetodoPago.credito && !venta.creditoLiquidado ? ' · Pendiente' : ''}'
					' · $fecha';
			}(),
			TipoRegistroHistorial.pedidoEntregado => () {
				final pedido = item.pedido!;
				return 'Pedido entregado · ${pedido.lineas.length} productos · '
					'${pedido.nombreEntrega} · $fecha';
			}(),
		};
	}

	void _abrirDetalle(BuildContext context, ItemHistorial item) {
		switch (item.tipo) {
			case TipoRegistroHistorial.venta:
				_mostrarDetalleVenta(context, item.venta!);
			case TipoRegistroHistorial.pedidoEntregado:
				_mostrarDetallePedido(context, item.pedido!);
		}
	}

	void _mostrarDetallePedido(BuildContext context, Pedido pedido) {
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.65,
				maxChildSize: 0.9,
				builder: (context, scrollController) => Padding(
					padding: const EdgeInsets.all(20.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									const Icon(
										Icons.local_shipping_outlined,
										color: _colorPedidoHistorial,
										size: 32.0,
									),
									const SizedBox(width: 12.0),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													formatearMoneda(pedido.total),
													style: Theme.of(context).textTheme.headlineSmall?.copyWith(
														fontWeight: FontWeight.bold,
													),
												),
												Text(
													'Pedido ${pedido.id.substring(0, 8).toUpperCase()}',
												),
											],
										),
									),
								],
							),
							const SizedBox(height: 16.0),
							_wrapInfo('Estado', etiquetaEstadoPedido(pedido.estado)),
							_wrapInfo('Entregar a', pedido.nombreEntrega),
							_wrapInfo('Teléfono', pedido.telefonoEntrega),
							_wrapInfo('Dirección', pedido.direccionEntrega),
							_wrapInfo('Método de pago', etiquetaMetodoPago(pedido.metodoPago)),
							if (pedido.asignadoAUsuarioNombre != null)
								_wrapInfo('Entregó', pedido.asignadoAUsuarioNombre!),
							_wrapInfo('Fecha', pedido.creadoEn.toLocal().toString().substring(0, 19)),
							if (pedido.notas.isNotEmpty) _wrapInfo('Notas', pedido.notas),
							const Divider(height: 24.0),
							Text('Productos', style: Theme.of(context).textTheme.titleMedium),
							const SizedBox(height: 8.0),
							Expanded(
								child: ListView(
									controller: scrollController,
									children: pedido.lineas.map((linea) {
										return ListTile(
											contentPadding: EdgeInsets.zero,
											title: Text(linea.nombreProducto),
											subtitle: Text(
												'${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}',
											),
											trailing: Text(
												formatearMoneda(linea.subtotal),
												style: const TextStyle(fontWeight: FontWeight.w600),
											),
										);
									}).toList(),
								),
							),
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

	Future<void> _anular(String ventaId) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Anular venta'),
				content: const Text('Se revertirá el stock. Esta acción no se puede deshacer.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Anular'),
					),
				],
			),
		);
		if (confirmar != true) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final ok = await servicio.anularVenta(ventaId);
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(
				content: Text(ok ? 'Venta anulada' : 'No se pudo anular'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(historialOperacionesProvider(_diasAtras));
	}

	Future<void> _eliminar(Venta venta) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar venta'),
				content: const Text(
					'Se eliminará permanentemente del historial. '
					'Si estaba completada, el stock será restaurado.',
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cancelar),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (confirmar != true) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final ok = await servicio.eliminarVenta(venta.id);
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(
				content: Text(ok ? 'Venta eliminada' : 'No se pudo eliminar'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(historialOperacionesProvider(_diasAtras));
	}

	void _mostrarDetalleVenta(BuildContext context, Venta venta) {
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.6,
				maxChildSize: 0.9,
				builder: (context, scrollController) => Padding(
					padding: const EdgeInsets.all(20.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									Icon(
										Icons.receipt_long,
										color: venta.estado == EstadoVenta.completada
											? PosiaColors.cobrar
											: PosiaColors.cancelar,
										size: 32.0,
									),
									const SizedBox(width: 12.0),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													formatearMoneda(venta.total),
													style: Theme.of(context).textTheme.headlineSmall?.copyWith(
														fontWeight: FontWeight.bold,
													),
												),
												Text('Ticket ${venta.id.substring(0, 8).toUpperCase()}'),
											],
										),
									),
								],
							),
							const SizedBox(height: 16.0),
							_wrapInfo('Estado', etiquetaEstadoVenta(venta.estado)),
							_wrapInfo('Método de pago', etiquetaMetodoPago(venta.metodoPago)),
							if (venta.metodoPago == MetodoPago.credito &&
								venta.creditoDias != null)
								_wrapInfo('Plazo de crédito', '${venta.creditoDias} días'),
							if (venta.creditoVenceEn != null)
								_wrapInfo(
									'Pagar a más tardar',
									formatearFechaCredito(venta.creditoVenceEn!.toLocal()),
								),
							if (venta.metodoPago == MetodoPago.credito)
								_wrapInfo(
									'Estado crédito',
									venta.creditoLiquidado
										? 'Liquidado${venta.creditoLiquidadoEn != null ? ' · ${formatearFechaCredito(venta.creditoLiquidadoEn!.toLocal())}' : ''}'
										: 'Pendiente de pago',
								),
							_wrapInfo('Fecha', venta.creadaEn.toLocal().toString().substring(0, 19)),
							if (venta.vendedorId != null)
								_wrapInfo('Vendedor', venta.vendedorId!),
							const Divider(height: 24.0),
							Text('Productos', style: Theme.of(context).textTheme.titleMedium),
							const SizedBox(height: 8.0),
							Expanded(
								child: ListView(
									controller: scrollController,
									children: venta.lineas.map((linea) {
										final subtotal = linea.cantidad * linea.precioUnitario;
										return ListTile(
											contentPadding: EdgeInsets.zero,
											title: Text(linea.nombreProducto),
											subtitle: Text(
												'${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}',
											),
											trailing: Text(
												formatearMoneda(subtotal),
												style: const TextStyle(fontWeight: FontWeight.w600),
											),
										);
									}).toList(),
								),
							),
							Row(
								children: [
									if (venta.estado == EstadoVenta.completada)
										TextButton.icon(
											onPressed: () {
												Navigator.pop(ctx);
												_reimprimirTicket(venta);
											},
											icon: const Icon(Icons.print),
											label: Text(
												venta.metodoPago == MetodoPago.credito && !venta.creditoLiquidado
													? 'Reimprimir pagarés'
													: 'Reimprimir',
											),
										),
										TextButton.icon(
											onPressed: () {
												Navigator.pop(ctx);
												_compartirWhatsApp(venta);
											},
											icon: const Icon(Icons.chat),
											label: const Text('WhatsApp'),
										),
									if (venta.metodoPago == MetodoPago.credito &&
										!venta.creditoLiquidado &&
										venta.estado == EstadoVenta.completada)
										TextButton.icon(
											onPressed: () {
												Navigator.pop(ctx);
												_liquidarCredito(venta);
											},
											icon: const Icon(Icons.paid),
											label: const Text('Liquidar'),
										),
									if (venta.puedeDevolverseParcial())
										TextButton(
											onPressed: () {
												Navigator.pop(ctx);
												_devolverParcial(context, venta);
											},
											child: const Text('Devolver'),
										),
									const Spacer(),
									TextButton(
										style: TextButton.styleFrom(foregroundColor: PosiaColors.cancelar),
										onPressed: () {
											Navigator.pop(ctx);
											_eliminar(venta);
										},
										child: const Text('Eliminar'),
									),
									FilledButton(
										onPressed: () => Navigator.pop(ctx),
										child: const Text('Cerrar'),
									),
								],
							),
						],
					),
				),
			),
		);
	}

	Widget _wrapInfo(String etiqueta, String valor) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 4.0),
			child: Row(
				children: [
					SizedBox(
						width: 120.0,
						child: Text(etiqueta, style: const TextStyle(color: Colors.grey)),
					),
					Expanded(child: Text(valor)),
				],
			),
		);
	}

	Future<void> _compartirWhatsApp(Venta venta) async {
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
			String? telefono;
			if (venta.clienteId != null) {
				final cliente = await servicio.obtenerCliente(venta.clienteId!);
				telefono = cliente?.telefono;
			}
			if (!mounted) {
				return;
			}
			await compartirTicketDigitalWhatsApp(
				context,
				contenido: digital,
				telefono: telefono,
			);
		} catch (_) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('No se pudo compartir el ticket')),
			);
		}
	}

	Future<void> _reimprimirTicket(Venta venta) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final config = await ref.read(configDispositivoProvider.future);
		try {
			final hardware = await ref.read(hardwareRegistryProvider.future);
			final impresora = hardware.obtenerImpresora();
			if (venta.metodoPago == MetodoPago.credito && !venta.creditoLiquidado) {
				final pagares = await obtenerTicketsDigitalesPagareCredito(
					venta: venta,
					servicioAdmin: servicio,
				);
				await imprimirTicketsDigitales(
					impresora: impresora,
					contenidos: pagares,
				);
			} else if (venta.metodoPago == MetodoPago.credito && venta.creditoLiquidado) {
				final digital = await obtenerTicketDigitalLiquidacionCredito(
					venta: venta,
					servicioAdmin: servicio,
				);
				await imprimirTicketDigital(
					impresora: impresora,
					contenido: digital,
				);
			} else {
				final digital = await obtenerTicketDigitalVenta(
					venta: venta,
					servicioAdmin: servicio,
					config: config,
				);
				await imprimirTicketDigital(
					impresora: impresora,
					contenido: digital,
				);
			}
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Ticket enviado a impresora')),
			);
		} catch (_) {
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('No se pudo imprimir el ticket')),
			);
		}
	}

	Future<void> _liquidarCredito(Venta venta) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Liquidar crédito'),
				content: Text(
					'Confirmar pago de ${formatearMoneda(venta.total)} en una sola exhibición.',
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Liquidar'),
					),
				],
			),
		);
		if (confirmar != true || !mounted) {
			return;
		}
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			final actualizada = await servicio.liquidarCreditoVenta(venta.id);
			final digital = await obtenerTicketDigitalLiquidacionCredito(
				venta: actualizada,
				servicioAdmin: servicio,
			);
			final hardware = await ref.read(hardwareRegistryProvider.future);
			await imprimirTicketDigital(
				impresora: hardware.obtenerImpresora(),
				contenido: digital,
			);
			ref.invalidate(historialOperacionesProvider(_diasAtras));
			if (!mounted) {
				return;
			}
			PosiaNotificaciones.mostrarSnackBar(context, 
				const SnackBar(content: Text('Crédito liquidado')),
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

	Future<void> _devolverParcial(BuildContext context, Venta venta) async {
		final cantidades = <String, double>{};
		for (final linea in venta.lineas) {
			if (!context.mounted) {
				return;
			}
			final controller = TextEditingController(text: '0');
			final devolver = await showDialog<double>(
				context: context,
				builder: (ctx) => AlertDialog(
					title: Text('Devolver: ${linea.nombreProducto}'),
					content: TextField(
						controller: controller,
						keyboardType: TextInputType.number,
						decoration: InputDecoration(
							labelText: 'Cantidad (máx. ${linea.cantidad})',
						),
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Omitir')),
						FilledButton(
							onPressed: () =>
								Navigator.pop(ctx, double.tryParse(controller.text) ?? 0.0),
							child: const Text('Siguiente'),
						),
					],
				),
			);
			controller.dispose();
			if (devolver != null && devolver > 0.0) {
				cantidades[linea.productoId] = devolver;
			}
		}
		if (cantidades.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		final ok = await servicio.devolverLineasVenta(venta.id, cantidades);
		if (!context.mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(context, 
			SnackBar(
				content: Text(ok ? 'Devolución registrada' : 'No se pudo devolver'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(historialOperacionesProvider(_diasAtras));
	}
}
