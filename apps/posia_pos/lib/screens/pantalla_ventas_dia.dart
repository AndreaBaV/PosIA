/// Pantalla de resumen de ventas del dia por tienda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

/// Muestra total vendido y detalle de ventas por sucursal.
class PantallaVentasDia extends ConsumerWidget {
	const PantallaVentasDia({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final resumenesAsync = ref.watch(_resumenVentasProvider);
		return Scaffold(
			appBar: AppBar(title: const Text('Ventas de hoy')),
			body: resumenesAsync.when(
				data: (datos) => _ConstruirContenido(datos: datos),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (error, _) => Center(child: Text(error.toString())),
			),
		);
	}
}

final _resumenVentasProvider = FutureProvider<_DatosVentasDia>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final resumenes = await servicio.obtenerResumenVentasDelDia();
	final ventasPorTienda = <String, List<Venta>>{};
	for (final resumen in resumenes) {
		ventasPorTienda[resumen.tiendaId] =
			await servicio.listarVentasDelDiaTienda(resumen.tiendaId);
	}
	return _DatosVentasDia(resumenes: resumenes, ventasPorTienda: ventasPorTienda);
});

class _DatosVentasDia {
	const _DatosVentasDia({
		required this.resumenes,
		required this.ventasPorTienda,
	});

	final List<ResumenVentasDia> resumenes;
	final Map<String, List<Venta>> ventasPorTienda;
}

class _ConstruirContenido extends StatefulWidget {
	const _ConstruirContenido({required this.datos});

	final _DatosVentasDia datos;

	@override
	State<_ConstruirContenido> createState() => _ConstruirContenidoState();
}

class _ConstruirContenidoState extends State<_ConstruirContenido> {
	final _expandidas = <String>{};

	@override
	Widget build(BuildContext context) {
		final datos = widget.datos;
		var totalGlobal = 0.0;
		for (final resumen in datos.resumenes) {
			totalGlobal = totalGlobal + resumen.totalVendido;
		}
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				Card(
					child: Padding(
						padding: const EdgeInsets.all(20.0),
						child: Column(
							children: [
								const Icon(Icons.trending_up, size: 48.0, color: PosiaColors.cobrar),
								const SizedBox(height: 8.0),
								Text(
									formatearMoneda(redondearMonto(totalGlobal)),
									style: Theme.of(context).textTheme.headlineLarge?.copyWith(
										color: PosiaColors.cobrar,
									),
								),
								const Text('Total todas las tiendas'),
							],
						),
					),
				),
				const SizedBox(height: 16.0),
				Text('Detalle por tienda', style: Theme.of(context).textTheme.titleLarge),
				const SizedBox(height: 8.0),
				...datos.resumenes.map((resumen) {
					final expandida = _expandidas.contains(resumen.tiendaId);
					final ventas = datos.ventasPorTienda[resumen.tiendaId] ?? [];
					return Card(
						margin: const EdgeInsets.only(bottom: 8.0),
						child: Column(
							children: [
								ListTile(
									leading: const Icon(Icons.store, color: PosiaColors.cobrar),
									title: Text(resumen.nombreTienda),
									subtitle: Text('${resumen.cantidadVentas} ventas'),
									trailing: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text(
												formatearMoneda(resumen.totalVendido),
												style: const TextStyle(
													fontWeight: FontWeight.bold,
													color: PosiaColors.cobrar,
												),
											),
											Icon(expandida ? Icons.expand_less : Icons.expand_more),
										],
									),
									onTap: () => setState(() {
										if (expandida) {
											_expandidas.remove(resumen.tiendaId);
										} else {
											_expandidas.add(resumen.tiendaId);
										}
									}),
								),
								if (expandida) ...[
									const Divider(height: 1.0),
									if (ventas.isEmpty)
										const Padding(
											padding: EdgeInsets.all(16.0),
											child: Text('Sin ventas hoy en esta tienda'),
										),
									...ventas.map(
										(venta) => ListTile(
											dense: true,
											leading: Icon(
												venta.estado == EstadoVenta.completada
													? Icons.receipt
													: Icons.cancel,
												size: 20.0,
											),
											title: Text(formatearMoneda(venta.total)),
											subtitle: Text(
												'${venta.lineas.length} productos · '
												'${venta.creadaEn.toLocal().toString().substring(0, 16)}',
											),
										),
									),
								],
							],
						),
					);
				}),
			],
		);
	}
}
