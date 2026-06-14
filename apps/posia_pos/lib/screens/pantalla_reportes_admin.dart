/// Reportes de ventas e inventario.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../providers/admin_providers.dart';

class PantallaReportesAdmin extends ConsumerWidget {
	const PantallaReportesAdmin({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final reporteAsync = ref.watch(_reporteProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Reportes'),
				actions: [
					IconButton(
						icon: const Icon(Icons.download),
						tooltip: 'Exportar CSV',
						onPressed: reporteAsync.hasValue
							? () => _exportarCsv(context, reporteAsync.requireValue)
							: null,
					),
				],
			),
			body: reporteAsync.when(
				data: (datos) => ListView(
					padding: const EdgeInsets.all(16.0),
					children: [
						Text('Ventas por vendedor (7 dias)',
							style: Theme.of(context).textTheme.titleLarge),
						...datos.resumenVendedores.map(
							(r) => ListTile(
								leading: const Icon(Icons.badge),
								title: Text(r.nombreVendedor),
								subtitle: Text('${r.cantidadVentas} ventas'),
								trailing: Text(formatearMoneda(r.totalVendido)),
							),
						),
						const Divider(),
						Text('Top productos (7 dias)',
							style: Theme.of(context).textTheme.titleLarge),
						if (datos.topProductos.isEmpty)
							const ListTile(title: Text('Sin ventas en el periodo')),
						...datos.topProductos.take(10).map(
							(r) => ListTile(
								leading: const Icon(Icons.inventory_2),
								title: Text(r.nombreProducto),
								subtitle: Text('${r.cantidadVendida.toStringAsFixed(1)} uds'),
								trailing: Text(formatearMoneda(r.totalVendido)),
							),
						),
						const Divider(),
						Text('Ventas por metodo de pago',
							style: Theme.of(context).textTheme.titleLarge),
						...datos.porMetodoPago.entries.map(
							(e) => ListTile(
								leading: const Icon(Icons.payments),
								title: Text(_etiquetaMetodo(e.key)),
								trailing: Text(formatearMoneda(e.value)),
							),
						),
						const Divider(),
						Text('Alertas de faltantes',
							style: Theme.of(context).textTheme.titleLarge),
						if (datos.alertas.isEmpty)
							const ListTile(title: Text('Sin alertas de stock bajo')),
						...datos.alertas.map(
							(a) => ListTile(
								leading: const Icon(Icons.warning, color: Colors.orange),
								title: Text(a.nombreProducto),
								subtitle: Text(
									'Actual: ${a.cantidadActual} · Min: ${a.stockMinimo}',
								),
							),
						),
					],
				),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	String _etiquetaMetodo(MetodoPago metodo) {
		switch (metodo) {
			case MetodoPago.efectivo:
				return 'Efectivo';
			case MetodoPago.tarjeta:
				return 'Tarjeta';
			case MetodoPago.mixto:
				return 'Mixto';
			case MetodoPago.credito:
				return 'Credito / Fiado';
			case MetodoPago.transferencia:
				return 'Transferencia';
		}
	}

	void _exportarCsv(BuildContext context, _DatosReporte datos) {
		final lineas = <String>[
			'tipo,nombre,detalle,valor',
			...datos.resumenVendedores.map(
				(r) =>
					'vendedor,"${r.nombreVendedor}",${r.cantidadVentas} ventas,${r.totalVendido}',
			),
			...datos.topProductos.map(
				(r) =>
					'producto,"${r.nombreProducto}",${r.cantidadVendida} uds,${r.totalVendido}',
			),
			...datos.porMetodoPago.entries.map(
				(e) => 'pago,${_etiquetaMetodo(e.key)},,${e.value}',
			),
			...datos.alertas.map(
				(a) =>
					'alerta,"${a.nombreProducto}","actual ${a.cantidadActual} min ${a.stockMinimo}",',
			),
		];
		Clipboard.setData(ClipboardData(text: lineas.join('\n')));
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Reporte copiado al portapapeles (CSV)')),
		);
	}
}

class _DatosReporte {
	const _DatosReporte({
		required this.resumenVendedores,
		required this.topProductos,
		required this.porMetodoPago,
		required this.alertas,
	});

	final List<ResumenVendedor> resumenVendedores;
	final List<ResumenProductoVenta> topProductos;
	final Map<MetodoPago, double> porMetodoPago;
	final List<AlertaFaltante> alertas;
}

final _reporteProvider = FutureProvider<_DatosReporte>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final filtro = servicio.filtroVentasPeriodo(dias: 7);
	return _DatosReporte(
		resumenVendedores: await servicio.obtenerResumenPorVendedor(filtro),
		topProductos: await servicio.obtenerResumenPorProducto(filtro),
		porMetodoPago: await servicio.obtenerTotalesPorMetodoPago(filtro),
		alertas: await servicio.obtenerAlertasFaltantes(),
	);
});
