/// Historial de ventas con filtros, detalle enriquecido y eliminacion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/ticket_credito_util.dart';
import '../utils/ticket_venta_util.dart';

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
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final ventasAsync = ref.watch(_historialProvider(_diasAtras));
		return Scaffold(
			appBar: AppBar(title: const Text('Historial de ventas')),
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
						sugerencia: 'Buscar por monto o producto...',
						alCambiar: (v) => setState(() => _filtro = v.trim().toLowerCase()),
					),
					Expanded(
						child: ventasAsync.when(
							data: (ventas) {
								final filtradas = ventas.where((v) {
									if (_filtro.isEmpty) {
										return true;
									}
									if (formatearMoneda(v.total).toLowerCase().contains(_filtro)) {
										return true;
									}
									for (final linea in v.lineas) {
										if (linea.nombreProducto.toLowerCase().contains(_filtro)) {
											return true;
										}
									}
									return false;
								}).toList();
								if (filtradas.isEmpty) {
									return const Center(child: Text('Sin ventas en el período'));
								}
								return ListView.builder(
									itemCount: filtradas.length,
									itemBuilder: (context, i) {
										final venta = filtradas[i];
										return Card(
											margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
											child: ListTile(
												leading: Icon(
													venta.estado == EstadoVenta.completada
														? Icons.receipt_long
														: Icons.cancel,
													color: venta.estado == EstadoVenta.completada
														? PosiaColors.cobrar
														: PosiaColors.cancelar,
												),
												title: Text(
													formatearMoneda(venta.total),
													style: const TextStyle(fontWeight: FontWeight.bold),
												),
												subtitle: Text(
													'${venta.lineas.length} productos · '
													'${etiquetaMetodoPago(venta.metodoPago)}'
													'${venta.metodoPago == MetodoPago.credito && !venta.creditoLiquidado ? ' · Pendiente' : ''}'
													' · ${venta.creadaEn.toLocal().toString().substring(0, 16)}',
												),
												trailing: venta.puedeAnularse()
													? IconButton(
														icon: const Icon(Icons.undo, color: PosiaColors.cancelar),
														tooltip: 'Anular',
														onPressed: () => _anular(venta.id),
													)
													: null,
												onTap: () => _mostrarDetalle(context, venta),
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
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(ok ? 'Venta anulada' : 'No se pudo anular'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(_historialProvider(_diasAtras));
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
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(ok ? 'Venta eliminada' : 'No se pudo eliminar'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(_historialProvider(_diasAtras));
	}

	void _mostrarDetalle(BuildContext context, Venta venta) {
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

	Future<void> _reimprimirTicket(Venta venta) async {
		final servicio = await ref.read(servicioAdminProvider.future);
		final config = await ref.read(configDispositivoProvider.future);
		try {
			final hardware = await ref.read(hardwareRegistryProvider.future);
			final impresora = hardware.obtenerImpresora();
			if (venta.metodoPago == MetodoPago.credito && !venta.creditoLiquidado) {
				final pagares = await construirTextosPagareCredito(
					venta: venta,
					servicioAdmin: servicio,
				);
				for (final pagare in pagares) {
					await impresora.imprimirTicket(pagare);
				}
			} else if (venta.metodoPago == MetodoPago.credito && venta.creditoLiquidado) {
				final texto = await construirTextoLiquidacionCredito(
					venta: venta,
					servicioAdmin: servicio,
				);
				await impresora.imprimirTicket(texto);
			} else {
				final texto = await construirTextoTicketVenta(
					venta: venta,
					servicioAdmin: servicio,
					config: config,
				);
				await impresora.imprimirTicket(texto);
			}
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Ticket enviado a impresora')),
			);
		} catch (_) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
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
			final texto = await construirTextoLiquidacionCredito(
				venta: actualizada,
				servicioAdmin: servicio,
			);
			final hardware = await ref.read(hardwareRegistryProvider.future);
			await hardware.obtenerImpresora().imprimirTicket(texto);
			ref.invalidate(_historialProvider(_diasAtras));
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Crédito liquidado')),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		}
	}

	Future<void> _devolverParcial(BuildContext context, Venta venta) async {
		final messenger = ScaffoldMessenger.of(context);
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
		messenger.showSnackBar(
			SnackBar(
				content: Text(ok ? 'Devolución registrada' : 'No se pudo devolver'),
				backgroundColor: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
			),
		);
		ref.invalidate(_historialProvider(_diasAtras));
	}
}

final _historialProvider = FutureProvider.family<List<Venta>, int>((ref, dias) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final hasta = DateTime.now().toUtc();
	final desde = hasta.subtract(Duration(days: dias));
	return servicio.listarHistorialVentas(
		FiltroVentas(tiendaId: servicio.tiendaActivaId, desde: desde, hasta: hasta),
	);
});
