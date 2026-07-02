/// Pantalla de creditos pendientes de liquidar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/compartir_ticket_digital_util.dart';
import '../utils/ticket_credito_util.dart';
import 'pantalla_registrar_credito.dart';

class PantallaCreditosPendientes extends ConsumerStatefulWidget {
  const PantallaCreditosPendientes({super.key});

  @override
  ConsumerState<PantallaCreditosPendientes> createState() =>
      _PantallaCreditosPendientesState();
}

class _PantallaCreditosPendientesState extends ConsumerState<PantallaCreditosPendientes> {
  Map<String, String> _nombresCliente = {};
  Map<String, String> _telefonosCliente = {};
  Object? _clientesCargadosPara;

  Future<void> _cargarClientes(List<Venta> ventas) async {
    if (identical(_clientesCargadosPara, ventas)) {
      return;
    }
    _clientesCargadosPara = ventas;
    final servicio = await ref.read(servicioAdminProvider.future);
    final nombres = <String, String>{};
    final telefonos = <String, String>{};
    for (final venta in ventas) {
      final clienteId = venta.clienteId;
      if (clienteId == null || nombres.containsKey(clienteId)) {
        continue;
      }
      final cliente = await servicio.obtenerCliente(clienteId);
      nombres[clienteId] = cliente?.nombre ?? 'Cliente';
      telefonos[clienteId] = cliente?.telefono ?? '';
    }
    if (mounted) {
      setState(() {
        _nombresCliente = nombres;
        _telefonosCliente = telefonos;
      });
    }
  }

  void _recargar() {
    _clientesCargadosPara = null;
    ref.invalidate(creditosPendientesAdminProvider);
  }

  Future<void> _abrirNuevoCredito() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PantallaRegistrarCredito(),
      ),
    );
    if (ok == true) {
      _recargar();
    }
  }

  Future<void> _mostrarDetalle(Venta venta) async {
    final nombreCliente = venta.clienteId == null
        ? 'Sin cliente'
        : (_nombresCliente[venta.clienteId!] ?? 'Cliente');
    final telefono = venta.clienteId == null
        ? ''
        : (_telefonosCliente[venta.clienteId!] ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombreCliente,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Folio ${venta.id.substring(0, 8).toUpperCase()}'),
              Text('Total: ${formatearMoneda(venta.total)}'),
              if (venta.creditoVenceEn != null)
                Text(
                  'Vence: ${formatearFechaCredito(venta.creditoVenceEn!.toLocal())}',
                ),
              const SizedBox(height: 12.0),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: venta.lineas.map((linea) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(linea.nombreProducto),
                      subtitle: Text(
                        '${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}',
                      ),
                      trailing: Text(formatearMoneda(linea.calcularSubtotal())),
                    );
                  }).toList(),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final servicio = await ref.read(servicioAdminProvider.future);
                      final digital = await obtenerTicketDigitalPagareCliente(
                        venta: venta,
                        servicioAdmin: servicio,
                      );
                      await compartirTicketDigitalWhatsApp(
                        context,
                        contenido: digital,
                        telefono: telefono,
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _liquidar(venta);
                    },
                    child: const Text('Liquidar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _liquidar(Venta venta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liquidar crédito'),
        content: Text(
          'Confirmar que el cliente pagó ${formatearMoneda(venta.total)} '
          'en una sola exhibición.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marcar liquidado'),
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
      if (!mounted) {
        return;
      }
      final telefono = venta.clienteId == null
          ? null
          : _telefonosCliente[venta.clienteId!];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Crédito liquidado'),
          content: const Text('¿Desea enviar el comprobante por WhatsApp?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final digital = await obtenerTicketDigitalLiquidacionCredito(
                  venta: actualizada,
                  servicioAdmin: servicio,
                );
                await compartirTicketDigitalWhatsApp(
                  dialogContext,
                  contenido: digital,
                  telefono: telefono,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
            ),
          ],
        ),
      );
      _recargar();
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

  @override
  Widget build(BuildContext context) {
    final creditosAsync = ref.watch(creditosPendientesAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recargar),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevoCredito,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo crédito'),
      ),
      body: creditosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (ventas) {
          if (ventas.isNotEmpty) {
            unawaited(_cargarClientes(ventas));
          }
          if (ventas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 56.0),
                    const SizedBox(height: 12.0),
                    const Text(
                      'No hay créditos pendientes',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'Use el botón flotante o registre un fiado desde Caja '
                      'seleccionando cliente y pago a crédito.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
            itemCount: ventas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8.0),
            itemBuilder: (context, indice) {
              final venta = ventas[indice];
              final nombreCliente = venta.clienteId == null
                  ? 'Sin cliente'
                  : (_nombresCliente[venta.clienteId!] ?? 'Cliente');
              return Card(
                child: ListTile(
                  onTap: () => _mostrarDetalle(venta),
                  title: Text(nombreCliente),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatearMoneda(venta.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.0,
                        ),
                      ),
                      Text('Folio: ${venta.id.substring(0, 8).toUpperCase()}'),
                      Text('Fecha: ${venta.creadaEn.toLocal()}'),
                      if (venta.creditoVenceEn != null)
                        Text(
                          'Vence: ${formatearFechaCredito(venta.creditoVenceEn!.toLocal())}',
                        ),
                    ],
                  ),
                  trailing: FilledButton(
                    onPressed: () => _liquidar(venta),
                    child: const Text('Liquidar'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
