/// Pantalla de creditos pendientes de liquidar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/ticket_credito_util.dart';

class PantallaCreditosPendientes extends ConsumerStatefulWidget {
  const PantallaCreditosPendientes({super.key});

  @override
  ConsumerState<PantallaCreditosPendientes> createState() =>
      _PantallaCreditosPendientesState();
}

class _PantallaCreditosPendientesState extends ConsumerState<PantallaCreditosPendientes> {
  List<Venta>? _ventas;
  var _cargando = true;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    setState(() => _cargando = true);
    final servicio = await ref.read(servicioAdminProvider.future);
    final ventas = await servicio.listarCreditosPendientes();
    if (mounted) {
      setState(() {
        _ventas = ventas;
        _cargando = false;
      });
    }
  }

  Future<void> _liquidar(Venta venta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liquidar credito'),
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
      await _recargar();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credito liquidado e impreso')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creditos pendientes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _ventas == null || _ventas!.isEmpty
          ? const Center(child: Text('No hay creditos pendientes'))
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: _ventas!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8.0),
              itemBuilder: (context, indice) {
                final venta = _ventas![indice];
                return Card(
                  child: ListTile(
                    title: Text(formatearMoneda(venta.total)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
            ),
    );
  }
}
