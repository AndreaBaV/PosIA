/// Reportes de ventas e inventario con filtros y exportacion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../util/exportador_reportes.dart';

/// Parametros de consulta del reporte.
typedef ParametrosReporte = ({int dias, String? tiendaId});

/// Panel de reportes con KPIs, graficos simples y exportacion CSV.
class PantallaReportesAdmin extends ConsumerStatefulWidget {
	const PantallaReportesAdmin({super.key});

	@override
	ConsumerState<PantallaReportesAdmin> createState() =>
		_PantallaReportesAdminState();
}

class _PantallaReportesAdminState extends ConsumerState<PantallaReportesAdmin> {
	int _dias = 7;
	String? _tiendaId;
	_CriterioProducto _criterioProducto = _CriterioProducto.monto;

	String get _etiquetaPeriodo {
		switch (_dias) {
			case 1:
				return 'Hoy';
			case 7:
				return 'Últimos 7 días';
			case 30:
				return 'Últimos 30 días';
			default:
				return 'Últimos $_dias días';
		}
	}

	ParametrosReporte get _parametros => (dias: _dias, tiendaId: _tiendaId);

	@override
	Widget build(BuildContext context) {
		final reporteAsync = ref.watch(_reporteProvider(_parametros));
		return Scaffold(
			appBar: AppBar(
				title: const Text('Reportes'),
				actions: [
					PopupMenuButton<_AccionExportar>(
						icon: const Icon(Icons.download),
						tooltip: 'Exportar',
						enabled: reporteAsync.hasValue,
						onSelected: (accion) {
							if (!reporteAsync.hasValue) {
								return;
							}
							_ejecutarExportacion(context, reporteAsync.requireValue, accion);
						},
						itemBuilder: (context) => const [
							PopupMenuItem(
								value: _AccionExportar.guardar,
								child: ListTile(
									leading: Icon(Icons.save_alt),
									title: Text('Guardar CSV'),
									subtitle: Text('Carpeta de descargas'),
									contentPadding: EdgeInsets.zero,
								),
							),
							PopupMenuItem(
								value: _AccionExportar.copiar,
								child: ListTile(
									leading: Icon(Icons.content_copy),
									title: Text('Copiar CSV'),
									contentPadding: EdgeInsets.zero,
								),
							),
						],
					),
				],
			),
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
							selected: {_dias},
							onSelectionChanged: (s) => setState(() => _dias = s.first),
						),
					),
					const SizedBox(height: 8.0),
					Expanded(
						child: reporteAsync.when(
							data: (datos) => _construirContenido(context, datos),
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(child: Text('$e')),
						),
					),
				],
			),
		);
	}

	Widget _construirContenido(BuildContext context, _DatosReporte datos) {
		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				_filtroTienda(datos),
				const SizedBox(height: 12.0),
				_filaKpis(context, datos),
				const SizedBox(height: 16.0),
				_seccionCard(
					context,
					titulo: 'Ventas por tienda',
					icono: Icons.store,
					vacio: datos.resumenTiendas.isEmpty,
					mensajeVacio: 'Sin ventas en el período',
					children: datos.resumenTiendas.map((r) {
						final fraccion = datos.totalVendido > 0
							? r.totalVendido / datos.totalVendido
							: 0.0;
						return _filaConBarra(
							titulo: r.nombreTienda,
							subtitulo: '${r.cantidadVentas} ventas',
							valor: formatearMoneda(r.totalVendido),
							fraccion: fraccion,
							color: PosiaColors.cobrar,
						);
					}).toList(),
				),
				const SizedBox(height: 12.0),
				_seccionFlujoHorario(context, datos),
				const SizedBox(height: 12.0),
				_seccionProductos(context, datos),
				const SizedBox(height: 12.0),
				_seccionCard(
					context,
					titulo: 'Ventas por vendedor',
					icono: Icons.badge,
					vacio: datos.resumenVendedores.isEmpty,
					mensajeVacio: 'Sin ventas en el período',
					children: datos.resumenVendedores.map((r) {
						final maxVendedor = datos.resumenVendedores.first.totalVendido;
						final fraccion = maxVendedor > 0 ? r.totalVendido / maxVendedor : 0.0;
						return _filaConBarra(
							titulo: r.nombreVendedor,
							subtitulo: '${r.cantidadVentas} ventas',
							valor: formatearMoneda(r.totalVendido),
							fraccion: fraccion,
							color: Colors.indigo,
						);
					}).toList(),
				),
				const SizedBox(height: 12.0),
				_seccionCard(
					context,
					titulo: 'Métodos de pago',
					icono: Icons.payments,
					vacio: datos.porMetodoPago.isEmpty,
					mensajeVacio: 'Sin pagos registrados',
					children: _ordenarPagos(datos.porMetodoPago).map((e) {
						final fraccion = datos.totalVendido > 0
							? e.value / datos.totalVendido
							: 0.0;
						return _filaConBarra(
							titulo: etiquetaMetodoPago(e.key),
							subtitulo: '${(fraccion * 100).toStringAsFixed(1)}% del total',
							valor: formatearMoneda(e.value),
							fraccion: fraccion,
							color: Colors.deepPurple,
						);
					}).toList(),
				),
				const SizedBox(height: 12.0),
				_seccionCard(
					context,
					titulo: 'Alertas de inventario',
					icono: Icons.warning_amber,
					colorIcono: Colors.orange,
					vacio: datos.alertas.isEmpty,
					mensajeVacio: 'Sin productos bajo mínimo',
					children: datos.alertas.map((a) {
						final nombreTienda =
							datos.nombresTienda[a.tiendaId] ?? a.tiendaId;
						final deficit = a.stockMinimo - a.cantidadActual;
						return ListTile(
							dense: true,
							leading: const Icon(Icons.warning, color: Colors.orange, size: 22.0),
							title: Text(a.nombreProducto),
							subtitle: Text(
								'$nombreTienda · Actual ${a.cantidadActual} · '
								'Mín ${a.stockMinimo} · Faltan ${deficit.toStringAsFixed(1)}',
							),
						);
					}).toList(),
				),
				const SizedBox(height: 24.0),
			],
		);
	}

	Widget _filtroTienda(_DatosReporte datos) {
		return DropdownButtonFormField<String?>(
			initialValue: _tiendaId,
			decoration: const InputDecoration(
				labelText: 'Tienda',
				border: OutlineInputBorder(),
				isDense: true,
				prefixIcon: Icon(Icons.filter_alt),
			),
			items: [
				const DropdownMenuItem<String?>(
					value: null,
					child: Text('Todas las tiendas'),
				),
				...datos.tiendas.map(
					(t) => DropdownMenuItem<String?>(
						value: t.id,
						child: Text(t.nombre),
					),
				),
			],
			onChanged: (v) => setState(() => _tiendaId = v),
		);
	}

	Widget _filaKpis(BuildContext context, _DatosReporte datos) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final ancho = constraints.maxWidth;
				final columnas = ancho >= 700 ? 4 : 2;
				final tarjetas = [
					_kpi(
						context,
						icono: Icons.attach_money,
						etiqueta: 'Total vendido',
						valor: formatearMoneda(datos.totalVendido),
						color: PosiaColors.cobrar,
					),
					_kpi(
						context,
						icono: Icons.receipt_long,
						etiqueta: 'Ventas',
						valor: '${datos.cantidadVentas}',
						color: Colors.blue,
					),
					_kpi(
						context,
						icono: Icons.shopping_cart_checkout,
						etiqueta: 'Ticket promedio',
						valor: formatearMoneda(datos.ticketPromedio),
						color: Colors.indigo,
					),
					_kpi(
						context,
						icono: Icons.warning_amber,
						etiqueta: 'Alertas stock',
						valor: '${datos.alertas.length}',
						color: datos.alertas.isEmpty ? Colors.green : Colors.orange,
					),
				];
				return GridView.count(
					crossAxisCount: columnas,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					mainAxisSpacing: 8.0,
					crossAxisSpacing: 8.0,
					childAspectRatio: columnas == 4 ? 1.6 : 1.4,
					children: tarjetas,
				);
			},
		);
	}

	Widget _kpi(
		BuildContext context, {
		required IconData icono,
		required String etiqueta,
		required String valor,
		required Color color,
	}) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(icono, color: color, size: 28.0),
						const SizedBox(height: 6.0),
						Text(
							valor,
							style: Theme.of(context).textTheme.titleLarge?.copyWith(
								fontWeight: FontWeight.bold,
								color: color,
							),
							textAlign: TextAlign.center,
						),
						const SizedBox(height: 2.0),
						Text(
							etiqueta,
							style: Theme.of(context).textTheme.bodySmall,
							textAlign: TextAlign.center,
						),
					],
				),
			),
		);
	}

	Widget _seccionFlujoHorario(BuildContext context, _DatosReporte datos) {
		final horasActivas =
			datos.resumenPorHora.where((h) => h.cantidadVentas > 0).toList();
		final horaPico = datos.horaPico;
		final maxTotal = horasActivas.isEmpty
			? 0.0
			: horasActivas.map((h) => h.totalVendido).reduce((a, b) => a > b ? a : b);
		return Card(
			child: Padding(
				padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								const Icon(Icons.schedule, color: Colors.orange, size: 22.0),
								const SizedBox(width: 8.0),
								Expanded(
									child: Text(
										'Flujo de ventas por hora',
										style: Theme.of(context).textTheme.titleMedium,
									),
								),
								if (horaPico != null)
									Chip(
										avatar: const Icon(Icons.trending_up, size: 16.0),
										label: Text(
											'Pico ${horaPico.etiquetaFranja.split(' ').first}',
										),
										visualDensity: VisualDensity.compact,
									),
							],
						),
						if (horaPico != null) ...[
							const SizedBox(height: 4.0),
							Text(
								'Mayor actividad: ${horaPico.etiquetaFranja} · '
								'${horaPico.cantidadVentas} ventas · '
								'${formatearMoneda(horaPico.totalVendido)}',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: Theme.of(context).colorScheme.outline,
								),
							),
						],
						const SizedBox(height: 8.0),
						if (horasActivas.isEmpty)
							Padding(
								padding: const EdgeInsets.symmetric(vertical: 12.0),
								child: Center(
									child: Text(
										'Sin ventas en el período',
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: Theme.of(context).colorScheme.outline,
										),
									),
								),
							)
						else
							...horasActivas.map((h) {
								final fraccion = maxTotal > 0 ? h.totalVendido / maxTotal : 0.0;
								return _filaConBarra(
									titulo: h.etiquetaFranja,
									subtitulo: '${h.cantidadVentas} ventas',
									valor: formatearMoneda(h.totalVendido),
									fraccion: fraccion,
									color: Colors.orange,
								);
							}),
					],
				),
			),
		);
	}

	Widget _seccionProductos(BuildContext context, _DatosReporte datos) {
		final masVendidos = _ordenarProductos(
			datos.topProductos,
			_criterioProducto,
			ascendente: false,
		).take(10);
		final menosVendidos = _ordenarProductos(
			datos.topProductos,
			_criterioProducto,
			ascendente: true,
		).take(10);
		final maxValor = _valorProducto(
			_ordenarProductos(datos.topProductos, _criterioProducto, ascendente: false)
				.firstOrNull,
		);
		return Card(
			child: Padding(
				padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								const Icon(Icons.inventory_2, color: Colors.teal, size: 22.0),
								const SizedBox(width: 8.0),
								Expanded(
									child: Text(
										'Artículos vendidos',
										style: Theme.of(context).textTheme.titleMedium,
									),
								),
							],
						),
						const SizedBox(height: 8.0),
						SegmentedButton<_CriterioProducto>(
							segments: const [
								ButtonSegment(
									value: _CriterioProducto.monto,
									label: Text('Por monto'),
									icon: Icon(Icons.attach_money, size: 18.0),
								),
								ButtonSegment(
									value: _CriterioProducto.unidades,
									label: Text('Por unidades'),
									icon: Icon(Icons.shopping_basket, size: 18.0),
								),
							],
							selected: {_criterioProducto},
							onSelectionChanged: (s) => setState(() => _criterioProducto = s.first),
						),
						const SizedBox(height: 12.0),
						if (datos.topProductos.isEmpty)
							Padding(
								padding: const EdgeInsets.symmetric(vertical: 12.0),
								child: Center(
									child: Text(
										'Sin productos vendidos',
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: Theme.of(context).colorScheme.outline,
										),
									),
								),
							)
						else ...[
							Text(
								'Más vendidos',
								style: Theme.of(context).textTheme.titleSmall?.copyWith(
									fontWeight: FontWeight.w600,
									color: Colors.teal,
								),
							),
							const SizedBox(height: 4.0),
							...masVendidos.map((r) => _filaProducto(r, maxValor, Colors.teal)),
							const SizedBox(height: 12.0),
							Text(
								'Menos vendidos',
								style: Theme.of(context).textTheme.titleSmall?.copyWith(
									fontWeight: FontWeight.w600,
									color: Colors.blueGrey,
								),
							),
							const SizedBox(height: 4.0),
							...menosVendidos.map(
								(r) => _filaProducto(r, maxValor, Colors.blueGrey),
							),
						],
					],
				),
			),
		);
	}

	Widget _filaProducto(
		ResumenProductoVenta r,
		double maxValor,
		Color color,
	) {
		final valor = _valorProducto(r);
		final fraccion = maxValor > 0 ? valor / maxValor : 0.0;
		final subtitulo =
			'${r.cantidadVendida.toStringAsFixed(1)} uds · ${formatearMoneda(r.totalVendido)}';
		final valorTexto = _criterioProducto == _CriterioProducto.monto
			? formatearMoneda(r.totalVendido)
			: '${r.cantidadVendida.toStringAsFixed(1)} uds';
		return _filaConBarra(
			titulo: r.nombreProducto,
			subtitulo: subtitulo,
			valor: valorTexto,
			fraccion: fraccion,
			color: color,
		);
	}

	double _valorProducto(ResumenProductoVenta? producto) {
		if (producto == null) {
			return 0.0;
		}
		return _criterioProducto == _CriterioProducto.monto
			? producto.totalVendido
			: producto.cantidadVendida;
	}

	List<ResumenProductoVenta> _ordenarProductos(
		List<ResumenProductoVenta> productos,
		_CriterioProducto criterio, {
		required bool ascendente,
	}) {
		final copia = List<ResumenProductoVenta>.from(productos);
		int comparar(ResumenProductoVenta a, ResumenProductoVenta b) {
			final va = criterio == _CriterioProducto.monto
				? a.totalVendido
				: a.cantidadVendida;
			final vb = criterio == _CriterioProducto.monto
				? b.totalVendido
				: b.cantidadVendida;
			return va.compareTo(vb);
		}

		copia.sort(comparar);
		if (!ascendente) {
			return copia.reversed.toList();
		}
		return copia;
	}

	Widget _seccionCard(
		BuildContext context, {
		required String titulo,
		required IconData icono,
		Color colorIcono = PosiaColors.cobrar,
		required bool vacio,
		required String mensajeVacio,
		required List<Widget> children,
	}) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								Icon(icono, color: colorIcono, size: 22.0),
								const SizedBox(width: 8.0),
								Text(titulo, style: Theme.of(context).textTheme.titleMedium),
							],
						),
						const SizedBox(height: 8.0),
						if (vacio)
							Padding(
								padding: const EdgeInsets.symmetric(vertical: 12.0),
								child: Center(
									child: Text(
										mensajeVacio,
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: Theme.of(context).colorScheme.outline,
										),
									),
								),
							)
						else
							...children,
					],
				),
			),
		);
	}

	Widget _filaConBarra({
		required String titulo,
		required String subtitulo,
		required String valor,
		required double fraccion,
		required Color color,
	}) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 6.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
										Text(
											subtitulo,
											style: TextStyle(
												fontSize: 12.0,
												color: Colors.grey.shade600,
											),
										),
									],
								),
							),
							Text(
								valor,
								style: TextStyle(fontWeight: FontWeight.bold, color: color),
							),
						],
					),
					const SizedBox(height: 4.0),
					ClipRRect(
						borderRadius: BorderRadius.circular(4.0),
						child: LinearProgressIndicator(
							value: fraccion.clamp(0.0, 1.0),
							minHeight: 6.0,
							backgroundColor: color.withValues(alpha: 0.12),
							color: color,
						),
					),
				],
			),
		);
	}

	List<MapEntry<MetodoPago, double>> _ordenarPagos(Map<MetodoPago, double> pagos) {
		return pagos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
	}

	Future<void> _ejecutarExportacion(
		BuildContext context,
		_DatosReporte datos,
		_AccionExportar accion,
	) async {
		final csv = ExportadorReportes.generarCsv(
			etiquetaPeriodo: _etiquetaPeriodo,
			etiquetaTienda: datos.etiquetaTienda,
			totalVendido: datos.totalVendido,
			cantidadVentas: datos.cantidadVentas,
			ticketPromedio: datos.ticketPromedio,
			resumenTiendas: datos.resumenTiendas,
			resumenVendedores: datos.resumenVendedores,
			topProductos: datos.topProductos,
			resumenPorHora: datos.resumenPorHora,
			horaPico: datos.horaPico,
			porMetodoPago: datos.porMetodoPago,
			alertas: datos.alertas,
			nombresTienda: datos.nombresTienda,
		);
		final messenger = ScaffoldMessenger.of(context);
		switch (accion) {
			case _AccionExportar.copiar:
				await ExportadorReportes.copiarPortapapeles(csv);
				if (!context.mounted) {
					return;
				}
				messenger.showSnackBar(
					const SnackBar(content: Text('Reporte copiado al portapapeles')),
				);
			case _AccionExportar.guardar:
				final ruta = await ExportadorReportes.guardarArchivo(csv);
				if (!context.mounted) {
					return;
				}
				if (ruta == null) {
					messenger.showSnackBar(
						const SnackBar(
							content: Text('No se pudo guardar el archivo en esta plataforma'),
						),
					);
				} else {
					messenger.showSnackBar(
						SnackBar(content: Text('Reporte guardado: $ruta')),
					);
				}
		}
	}
}

enum _AccionExportar { guardar, copiar }

enum _CriterioProducto { monto, unidades }

class _DatosReporte {
	const _DatosReporte({
		required this.etiquetaTienda,
		required this.totalVendido,
		required this.cantidadVentas,
		required this.ticketPromedio,
		required this.tiendas,
		required this.nombresTienda,
		required this.resumenTiendas,
		required this.resumenVendedores,
		required this.topProductos,
		required this.resumenPorHora,
		required this.horaPico,
		required this.porMetodoPago,
		required this.alertas,
	});

	final String etiquetaTienda;
	final double totalVendido;
	final int cantidadVentas;
	final double ticketPromedio;
	final List<Tienda> tiendas;
	final Map<String, String> nombresTienda;
	final List<ResumenVentasDia> resumenTiendas;
	final List<ResumenVendedor> resumenVendedores;
	final List<ResumenProductoVenta> topProductos;
	final List<ResumenVentasHora> resumenPorHora;
	final ResumenVentasHora? horaPico;
	final Map<MetodoPago, double> porMetodoPago;
	final List<AlertaFaltante> alertas;
}

final _reporteProvider = FutureProvider.family<_DatosReporte, ParametrosReporte>(
	(ref, params) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final filtro = servicio.filtroVentasReporte(
			dias: params.dias,
			tiendaId: params.tiendaId,
		);
		final tiendas = await servicio.listarTiendasActivas();
		final nombresTienda = {for (final t in tiendas) t.id: t.nombre};
		var resumenTiendas = await servicio.obtenerResumenVentasPeriodo(dias: params.dias);
		if (params.tiendaId != null) {
			resumenTiendas =
				resumenTiendas.where((r) => r.tiendaId == params.tiendaId).toList();
		}
		resumenTiendas.sort((a, b) => b.totalVendido.compareTo(a.totalVendido));

		final resumenVendedores = await servicio.obtenerResumenPorVendedor(filtro);
		final topProductos = await servicio.obtenerResumenPorProducto(filtro);
		final resumenPorHora = await servicio.obtenerResumenPorHora(filtro);
		final porMetodoPago = await servicio.obtenerTotalesPorMetodoPago(filtro);
		final alertas = await servicio.obtenerAlertasFaltantes(tiendaId: params.tiendaId);

		ResumenVentasHora? horaPico;
		for (final h in resumenPorHora) {
			if (h.cantidadVentas == 0) {
				continue;
			}
			if (horaPico == null ||
				h.totalVendido > horaPico.totalVendido ||
				(h.totalVendido == horaPico.totalVendido &&
					h.cantidadVentas > horaPico.cantidadVentas)) {
				horaPico = h;
			}
		}

		var totalVendido = 0.0;
		var cantidadVentas = 0;
		for (final r in resumenTiendas) {
			totalVendido = totalVendido + r.totalVendido;
			cantidadVentas = cantidadVentas + r.cantidadVentas;
		}
		totalVendido = redondearMonto(totalVendido);
		final ticketPromedio = cantidadVentas > 0
			? redondearMonto(totalVendido / cantidadVentas)
			: 0.0;

		final etiquetaTienda = params.tiendaId == null
			? 'Todas las tiendas'
			: (nombresTienda[params.tiendaId] ?? params.tiendaId!);

		return _DatosReporte(
			etiquetaTienda: etiquetaTienda,
			totalVendido: totalVendido,
			cantidadVentas: cantidadVentas,
			ticketPromedio: ticketPromedio,
			tiendas: tiendas,
			nombresTienda: nombresTienda,
			resumenTiendas: resumenTiendas,
			resumenVendedores: resumenVendedores,
			topProductos: topProductos,
			resumenPorHora: resumenPorHora,
			horaPico: horaPico,
			porMetodoPago: porMetodoPago,
			alertas: alertas,
		);
	},
);
