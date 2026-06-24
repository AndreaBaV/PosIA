/// Historial de cotizaciones guardadas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../utils/compartir_whatsapp_util.dart';
import '../utils/ticket_venta_util.dart';

class PantallaCotizacionesAdmin extends ConsumerStatefulWidget {
  const PantallaCotizacionesAdmin({super.key});

  @override
  ConsumerState<PantallaCotizacionesAdmin> createState() =>
      _PantallaCotizacionesAdminState();
}

class _PantallaCotizacionesAdminState extends ConsumerState<PantallaCotizacionesAdmin> {
  int _dias = 30;
  final _busquedaController = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cotizacionesAsync = ref.watch(_cotizacionesProvider(_dias));
    return Scaffold(
      appBar: AppBar(title: const Text('Cotizaciones')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 días')),
                ButtonSegment(value: 30, label: Text('30 días')),
                ButtonSegment(value: 90, label: Text('90 días')),
              ],
              selected: {_dias},
              onSelectionChanged: (s) => setState(() => _dias = s.first),
            ),
          ),
          CampoBusqueda(
            controlador: _busquedaController,
            sugerencia: 'Buscar por cliente, folio o monto...',
            alCambiar: (v) => setState(() => _filtro = v.trim().toLowerCase()),
          ),
          Expanded(
            child: cotizacionesAsync.when(
              data: (cotizaciones) {
                final filtradas = cotizaciones.where((c) {
                  if (_filtro.isEmpty) {
                    return true;
                  }
                  if (c.id.toLowerCase().contains(_filtro)) {
                    return true;
                  }
                  if ((c.nombreCliente ?? '').toLowerCase().contains(_filtro)) {
                    return true;
                  }
                  return formatearMoneda(c.total).toLowerCase().contains(_filtro);
                }).toList();
                if (filtradas.isEmpty) {
                  return const Center(child: Text('Sin cotizaciones en el período'));
                }
                return ListView.builder(
                  itemCount: filtradas.length,
                  itemBuilder: (context, indice) {
                    final cotizacion = filtradas[indice];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.request_quote, color: PosiaColors.neutro),
                        title: Text(
                          formatearMoneda(cotizacion.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${cotizacion.lineas.length} productos · '
                          '${cotizacion.nombreCliente ?? 'Mostrador'} · '
                          '${cotizacion.creadaEn.toLocal().toString().substring(0, 16)}',
                        ),
                        trailing: Text(
                          cotizacion.id.substring(0, 8).toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        onTap: () => _mostrarDetalle(cotizacion),
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

  Future<void> _mostrarDetalle(Cotizacion cotizacion) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cotización ${cotizacion.id.substring(0, 8).toUpperCase()}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    formatearMoneda(cotizacion.total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PosiaColors.cobrar,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cotizacion.nombreCliente != null)
                    Text('Cliente: ${cotizacion.nombreCliente}'),
                  Text('Vigencia: ${cotizacion.vigenciaDias} días'),
                  Text('Fecha: ${cotizacion.creadaEn.toLocal()}'),
                  if (cotizacion.notas.isNotEmpty) Text('Notas: ${cotizacion.notas}'),
                  const Divider(height: 24.0),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: cotizacion.lineas.map((linea) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(linea.nombreProducto),
                          subtitle: Text(
                            '${linea.cantidad} x ${formatearMoneda(linea.precioUnitario)}',
                          ),
                          trailing: Text(formatearMoneda(linea.subtotal)),
                        );
                      }).toList(),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _reimprimir(cotizacion.id);
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Reimprimir'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _compartirWhatsApp(cotizacion.id);
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _compartirWhatsApp(String cotizacionId) async {
    try {
      final servicio = await ref.read(servicioAdminProvider.future);
      final texto = await construirTextoCotizacionPorId(
        cotizacionId: cotizacionId,
        servicioAdmin: servicio,
      );
      final ok = await compartirTextoWhatsApp(texto: texto);
      if (!mounted) {
        return;
      }
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
      );
    }
  }

  Future<void> _reimprimir(String cotizacionId) async {
    try {
      final servicio = await ref.read(servicioAdminProvider.future);
      final texto = await construirTextoCotizacionPorId(
        cotizacionId: cotizacionId,
        servicioAdmin: servicio,
      );
      final hardware = await ref.read(hardwareRegistryProvider.future);
      await hardware.obtenerImpresora().imprimirTicket(texto);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización reimpresa')),
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
}

final _cotizacionesProvider = FutureProvider.family<List<Cotizacion>, int>((ref, dias) async {
  final servicio = await ref.watch(servicioAdminProvider.future);
  return servicio.listarCotizaciones(dias: dias);
});
