/// Pedidos asignados al empleado en sesion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../utils/documento_ticket_util.dart';
import '../widgets/acciones_documento_ticket.dart';

class PantallaMisPedidos extends ConsumerWidget {
	const PantallaMisPedidos({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final usuario = ref.watch(sesionUsuarioProvider);
		if (usuario == null) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}
		final pedidosAsync = ref.watch(_misPedidosProvider(usuario.id));
		return Scaffold(
			appBar: AppBar(
				title: const Text('Mis pedidos'),
			),
			body: pedidosAsync.when(
				data: (pedidos) {
					final activos = pedidos
						.where((p) => p.estado != EstadoPedido.entregado)
						.toList();
					if (activos.isEmpty) {
						return const Center(
							child: Text('No tiene pedidos asignados'),
						);
					}
					return ListView.builder(
						padding: const EdgeInsets.all(12.0),
						itemCount: activos.length,
						itemBuilder: (context, indice) {
							final pedido = activos[indice];
							return _TarjetaPedidoEmpleado(
								pedido: pedido,
								alEntregar: () async {
									try {
										final servicio = await ref.read(servicioAdminProvider.future);
										await servicio.marcarPedidoEntregado(
											pedidoId: pedido.id,
											operador: usuario,
										);
										ref.invalidate(_misPedidosProvider(usuario.id));
										ref.invalidate(historialOperacionesProvider);
										if (context.mounted) {
											PosiaNotificaciones.mostrarSnackBar(context, 
												const SnackBar(content: Text('Pedido marcado como entregado')),
											);
										}
									} catch (error) {
										if (context.mounted) {
											PosiaNotificaciones.mostrarSnackBar(context, 
												SnackBar(
													content: Text('$error'),
													backgroundColor: PosiaColors.cancelar,
												),
											);
										}
									}
								},
								alVerDetalle: () => _mostrarDetalle(context, ref, pedido),
							);
						},
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	void _mostrarDetalle(BuildContext context, WidgetRef ref, Pedido pedido) {
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			builder: (ctx) => DraggableScrollableSheet(
				expand: false,
				initialChildSize: 0.65,
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
							const Divider(height: 24.0),
							_DatoDetalle('Entregar a', pedido.nombreEntrega),
							_DatoDetalle('Teléfono', pedido.telefonoEntrega),
							_DatoDetalle('Dirección', pedido.direccionEntrega),
							_DatoDetalle('Pago', etiquetaMetodoPago(pedido.metodoPago)),
							if (pedido.esCredito) ...[
								_DatoDetalle(
									'Crédito',
									'${pedido.creditoDias ?? '?'} días'
									'${pedido.creditoVenceEn != null ? ' · vence ${formatearFechaCredito(pedido.creditoVenceEn!.toLocal())}' : ''}',
								),
							],
							_DatoDetalle('Total', formatearMoneda(pedido.total)),
							if (pedido.notas.isNotEmpty)
								_DatoDetalle('Notas', pedido.notas),
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
									if (!context.mounted) {
										return;
									}
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

class _TarjetaPedidoEmpleado extends StatelessWidget {
	const _TarjetaPedidoEmpleado({
		required this.pedido,
		required this.alEntregar,
		required this.alVerDetalle,
	});

	final Pedido pedido;
	final VoidCallback alEntregar;
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
							Text(
								pedido.direccionEntrega,
								style: const TextStyle(color: Colors.grey),
							),
							Text('Tel: ${pedido.telefonoEntrega}'),
							const SizedBox(height: 8.0),
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
							if (pedido.puedeMarcarseEntregado) ...[
								const SizedBox(height: 8.0),
								FilledButton.icon(
									onPressed: alEntregar,
									icon: const Icon(Icons.check_circle),
									label: const Text('Marcar entregado'),
								),
							],
						],
					),
				),
			),
		);
	}
}

class _DatoDetalle extends StatelessWidget {
	const _DatoDetalle(this.etiqueta, this.valor);

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

final _misPedidosProvider = FutureProvider.family<List<Pedido>, String>(
	(ref, usuarioId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final usuario = ref.watch(sesionUsuarioProvider);
		if (usuario == null || usuario.id != usuarioId) {
			return [];
		}
		return servicio.listarPedidosAsignadosA(usuario);
	},
);
