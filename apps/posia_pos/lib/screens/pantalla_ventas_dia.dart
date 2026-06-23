/// Pantalla de resumen de ventas por tienda con filtros y detalle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

/// Muestra total vendido y detalle de ventas por sucursal.
class PantallaVentasDia extends ConsumerStatefulWidget {
	const PantallaVentasDia({super.key});

	@override
	ConsumerState<PantallaVentasDia> createState() => _PantallaVentasDiaState();
}

class _PantallaVentasDiaState extends ConsumerState<PantallaVentasDia> {
	int _diasAtras = 1;
	final _busquedaController = TextEditingController();
	String _busqueda = '';
	String? _tiendaFiltroId;
	EstadoVenta? _estadoFiltro;
	final _expandidas = <String>{};

	@override
	void dispose() {
		_busquedaController.dispose();
		super.dispose();
	}

	String get _etiquetaPeriodo {
		switch (_diasAtras) {
			case 1:
				return 'Hoy';
			case 7:
				return 'Últimos 7 días';
			case 30:
				return 'Últimos 30 días';
			default:
				return 'Últimos $_diasAtras días';
		}
	}

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(_ventasTiendaProvider(_diasAtras));
		return Scaffold(
			appBar: AppBar(title: const Text('Ventas por tienda')),
			body: Column(
				children: [
					Padding(
						padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
						child: SegmentedButton<int>(
							segments: const [
								ButtonSegment(value: 1, label: Text('Hoy')),
								ButtonSegment(value: 7, label: Text('7 días')),
								ButtonSegment(value: 30, label: Text('30 días')),
							],
							selected: {_diasAtras},
							onSelectionChanged: (s) => setState(() {
								_diasAtras = s.first;
								_expandidas.clear();
							}),
						),
					),
					CampoBusqueda(
						controlador: _busquedaController,
						sugerencia: 'Buscar producto, monto o ticket...',
						alCambiar: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
					),
					Expanded(
						child: datosAsync.when(
							data: (datos) => _construirContenido(context, datos),
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (error, _) => Center(child: Text(error.toString())),
						),
					),
				],
			),
		);
	}

	Widget _construirContenido(BuildContext context, _DatosVentasTienda datos) {
		final resumenesVisibles = datos.resumenes.where((resumen) {
			if (_tiendaFiltroId != null && resumen.tiendaId != _tiendaFiltroId) {
				return false;
			}
			if (_busqueda.isEmpty && _estadoFiltro == null) {
				return true;
			}
			final ventas = _filtrarVentas(datos.ventasPorTienda[resumen.tiendaId] ?? []);
			return ventas.isNotEmpty;
		}).toList();

		var totalGlobal = 0.0;
		var ventasGlobal = 0;
		for (final resumen in resumenesVisibles) {
			totalGlobal = totalGlobal + resumen.totalVendido;
			ventasGlobal = ventasGlobal + resumen.cantidadVentas;
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
								Text('Total todas las tiendas · $_etiquetaPeriodo'),
								const SizedBox(height: 4.0),
								Text(
									'$ventasGlobal ventas en ${resumenesVisibles.length} tienda(s)',
									style: Theme.of(context).textTheme.bodySmall,
								),
							],
						),
					),
				),
				const SizedBox(height: 12.0),
				_filtrosSecundarios(datos),
				const SizedBox(height: 12.0),
				Text('Detalle por tienda', style: Theme.of(context).textTheme.titleLarge),
				const SizedBox(height: 8.0),
				if (resumenesVisibles.isEmpty)
					const Card(
						child: Padding(
							padding: EdgeInsets.all(24.0),
							child: Center(child: Text('Sin ventas que coincidan con los filtros')),
						),
					),
				...resumenesVisibles.map((resumen) {
					final expandida = _expandidas.contains(resumen.tiendaId);
					final ventas = _filtrarVentas(datos.ventasPorTienda[resumen.tiendaId] ?? []);
					final productos = datos.productosPorTienda[resumen.tiendaId] ?? [];
					final pagos = datos.pagosPorTienda[resumen.tiendaId] ?? {};
					final productosFiltrados = _filtrarProductos(productos);
					return Card(
						margin: const EdgeInsets.only(bottom: 8.0),
						child: Column(
							children: [
								ListTile(
									leading: const Icon(Icons.store, color: PosiaColors.cobrar),
									title: Text(resumen.nombreTienda),
									subtitle: Text(
										_tieneFiltrosActivos
											? '${ventas.length} de ${resumen.cantidadVentas} ventas'
											: '${resumen.cantidadVentas} ventas',
									),
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
									_seccionTitulo(context, 'Productos más vendidos'),
									if (productosFiltrados.isEmpty)
										const Padding(
											padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
											child: Text('Sin productos en el período'),
										)
									else
										...productosFiltrados.take(8).map(
											(producto) => ListTile(
												dense: true,
												leading: const Icon(Icons.inventory_2, size: 20.0),
												title: Text(producto.nombreProducto),
												subtitle: Text(
													'${producto.cantidadVendida.toStringAsFixed(1)} uds vendidas',
												),
												trailing: Text(
													formatearMoneda(producto.totalVendido),
													style: const TextStyle(fontWeight: FontWeight.w600),
												),
											),
										),
									if (pagos.isNotEmpty) ...[
										_seccionTitulo(context, 'Por método de pago'),
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 16.0),
											child: Wrap(
												spacing: 8.0,
												runSpacing: 4.0,
												children: pagos.entries.map((entry) {
													return Chip(
														avatar: const Icon(Icons.payments, size: 16.0),
														label: Text(
															'${etiquetaMetodoPago(entry.key)}: '
															'${formatearMoneda(entry.value)}',
														),
													);
												}).toList(),
											),
										),
										const SizedBox(height: 8.0),
									],
									_seccionTitulo(context, 'Ventas'),
									if (ventas.isEmpty)
										const Padding(
											padding: EdgeInsets.all(16.0),
											child: Text('Sin ventas que coincidan con los filtros'),
										),
									...ventas.map(
										(venta) => ListTile(
											dense: true,
											leading: Icon(
												venta.estado == EstadoVenta.completada
													? Icons.receipt
													: Icons.cancel,
												size: 20.0,
												color: venta.estado == EstadoVenta.completada
													? PosiaColors.cobrar
													: PosiaColors.cancelar,
											),
											title: Text(formatearMoneda(venta.total)),
											subtitle: Text(
												'${venta.lineas.length} productos · '
												'${etiquetaMetodoPago(venta.metodoPago)} · '
												'${venta.creadaEn.toLocal().toString().substring(0, 16)}',
											),
											trailing: Text(
												etiquetaEstadoVenta(venta.estado),
												style: TextStyle(
													fontSize: 12.0,
													color: venta.estado == EstadoVenta.completada
														? PosiaColors.cobrar
														: PosiaColors.cancelar,
												),
											),
											onTap: () => _mostrarDetalleVenta(context, venta),
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

	Widget _filtrosSecundarios(_DatosVentasTienda datos) {
		return Row(
			children: [
				Expanded(
					child: DropdownButtonFormField<String?>(
						initialValue: _tiendaFiltroId,
						decoration: const InputDecoration(
							labelText: 'Tienda',
							border: OutlineInputBorder(),
							isDense: true,
							contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
						),
						items: [
							const DropdownMenuItem(value: null, child: Text('Todas')),
							...datos.resumenes.map(
								(r) => DropdownMenuItem(value: r.tiendaId, child: Text(r.nombreTienda)),
							),
						],
						onChanged: (v) => setState(() => _tiendaFiltroId = v),
					),
				),
				const SizedBox(width: 8.0),
				Expanded(
					child: DropdownButtonFormField<EstadoVenta?>(
						initialValue: _estadoFiltro,
						decoration: const InputDecoration(
							labelText: 'Estado',
							border: OutlineInputBorder(),
							isDense: true,
							contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
						),
						items: const [
							DropdownMenuItem(value: null, child: Text('Todos')),
							DropdownMenuItem(
								value: EstadoVenta.completada,
								child: Text('Completadas'),
							),
							DropdownMenuItem(
								value: EstadoVenta.cancelada,
								child: Text('Canceladas'),
							),
							DropdownMenuItem(
								value: EstadoVenta.devuelta,
								child: Text('Devueltas'),
							),
						],
						onChanged: (v) => setState(() => _estadoFiltro = v),
					),
				),
			],
		);
	}

	Widget _seccionTitulo(BuildContext context, String titulo) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
			child: Align(
				alignment: Alignment.centerLeft,
				child: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
			),
		);
	}

	bool get _tieneFiltrosActivos =>
		_busqueda.isNotEmpty || _estadoFiltro != null || _tiendaFiltroId != null;

	List<Venta> _filtrarVentas(List<Venta> ventas) {
		return ventas.where((venta) {
			if (_estadoFiltro != null && venta.estado != _estadoFiltro) {
				return false;
			}
			if (_busqueda.isEmpty) {
				return true;
			}
			if (formatearMoneda(venta.total).toLowerCase().contains(_busqueda)) {
				return true;
			}
			if (venta.id.toLowerCase().contains(_busqueda)) {
				return true;
			}
			for (final linea in venta.lineas) {
				if (linea.nombreProducto.toLowerCase().contains(_busqueda)) {
					return true;
				}
			}
			return false;
		}).toList();
	}

	List<ResumenProductoVenta> _filtrarProductos(List<ResumenProductoVenta> productos) {
		if (_busqueda.isEmpty) {
			return productos;
		}
		return productos
			.where((p) => p.nombreProducto.toLowerCase().contains(_busqueda))
			.toList();
	}

	Future<void> _mostrarDetalleVenta(BuildContext context, Venta venta) async {
		String? nombreVendedor;
		if (venta.vendedorId != null) {
			final servicio = await ref.read(servicioAdminProvider.future);
			final vendedor = await servicio.obtenerVendedor(venta.vendedorId!);
			nombreVendedor = vendedor?.nombre;
		}
		if (!context.mounted) {
			return;
		}
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
							_filaInfo('Estado', etiquetaEstadoVenta(venta.estado)),
							_filaInfo('Método de pago', etiquetaMetodoPago(venta.metodoPago)),
							_filaInfo('Fecha', venta.creadaEn.toLocal().toString().substring(0, 19)),
							if (venta.vendedorId != null)
								_filaInfo('Vendedor', nombreVendedor ?? 'Sin vendedor'),
							const Divider(height: 24.0),
							Text('Productos', style: Theme.of(context).textTheme.titleMedium),
							const SizedBox(height: 8.0),
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
											trailing: Text(
												formatearMoneda(linea.calcularSubtotal()),
												style: const TextStyle(fontWeight: FontWeight.w600),
											),
										);
									}).toList(),
								),
							),
							Align(
								alignment: Alignment.centerRight,
								child: FilledButton(
									onPressed: () => Navigator.pop(ctx),
									child: const Text('Cerrar'),
								),
							),
						],
					),
				),
			),
		);
	}

	Widget _filaInfo(String etiqueta, String valor) {
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
}

class _DatosVentasTienda {
	const _DatosVentasTienda({
		required this.resumenes,
		required this.ventasPorTienda,
		required this.productosPorTienda,
		required this.pagosPorTienda,
	});

	final List<ResumenVentasDia> resumenes;
	final Map<String, List<Venta>> ventasPorTienda;
	final Map<String, List<ResumenProductoVenta>> productosPorTienda;
	final Map<String, Map<MetodoPago, double>> pagosPorTienda;
}

final _ventasTiendaProvider = FutureProvider.family<_DatosVentasTienda, int>((ref, dias) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final resumenes = await servicio.obtenerResumenVentasPeriodo(dias: dias);
	final ventasPorTienda = <String, List<Venta>>{};
	final productosPorTienda = <String, List<ResumenProductoVenta>>{};
	final pagosPorTienda = <String, Map<MetodoPago, double>>{};
	for (final resumen in resumenes) {
		final filtro = servicio.filtroVentasPeriodoTienda(resumen.tiendaId, dias: dias);
		ventasPorTienda[resumen.tiendaId] = await servicio.listarHistorialVentas(filtro);
		productosPorTienda[resumen.tiendaId] = await servicio.obtenerResumenPorProducto(filtro);
		pagosPorTienda[resumen.tiendaId] = await servicio.obtenerTotalesPorMetodoPago(filtro);
	}
	return _DatosVentasTienda(
		resumenes: resumenes,
		ventasPorTienda: ventasPorTienda,
		productosPorTienda: productosPorTienda,
		pagosPorTienda: pagosPorTienda,
	);
});
