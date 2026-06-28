/// Panel visual de nomina por horas trabajadas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

/// Dashboard de nomina con KPIs, graficos y filtros.
class PantallaNominaAdmin extends ConsumerStatefulWidget {
	const PantallaNominaAdmin({super.key});

	@override
	ConsumerState<PantallaNominaAdmin> createState() => _PantallaNominaAdminState();
}

class _PantallaNominaAdminState extends ConsumerState<PantallaNominaAdmin> {
	static const _coloresEmpleado = [
		Color(0xFF00897B),
		Color(0xFF5E35B1),
		Color(0xFFFB8C00),
		Color(0xFF1E88E5),
		Color(0xFFE53935),
		Color(0xFF43A047),
		Color(0xFF8E24AA),
		Color(0xFF546E7A),
	];

	String? _periodoFiltroId;
	String? _empleadoFiltroId;
	_CriterioNomina _criterio = _CriterioNomina.monto;
	var _calculando = false;

	@override
	Widget build(BuildContext context) {
		final datosAsync = ref.watch(_datosNominaProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Nómina'),
				actions: [
					IconButton(
						icon: _calculando
							? const SizedBox(
								width: 22.0,
								height: 22.0,
								child: CircularProgressIndicator(strokeWidth: 2.0),
							)
							: const Icon(Icons.calculate_outlined),
						tooltip: 'Calcular período',
						onPressed: _calculando ? null : () => _mostrarCalcularPeriodo(context),
					),
				],
			),
			body: datosAsync.when(
				data: (datos) => _construirContenido(context, datos),
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('$e')),
			),
		);
	}

	Widget _construirContenido(BuildContext context, _DatosNomina datos) {
		if (datos.periodos.isEmpty) {
			return _estadoVacio(context);
		}
		final lineas = _lineasFiltradas(datos);
		final resumenes = _agruparPorEmpleado(lineas, datos.nombres);
		final totalMonto = resumenes.fold(0.0, (a, r) => a + r.monto);
		final totalHoras = resumenes.fold(0.0, (a, r) => a + r.horas);
		final empleadosActivos = resumenes.length;
		final promedioHora = totalHoras > 0 ? totalMonto / totalHoras : 0.0;
		final periodoEtiqueta = _etiquetaPeriodo(datos);

		return ListView(
			padding: const EdgeInsets.all(16.0),
			children: [
				_filtros(context, datos),
				const SizedBox(height: 12.0),
				Text(
					periodoEtiqueta,
					style: Theme.of(context).textTheme.bodySmall?.copyWith(
						color: Theme.of(context).colorScheme.outline,
					),
				),
				const SizedBox(height: 8.0),
				_filaKpis(
					context,
					totalMonto: totalMonto,
					totalHoras: totalHoras,
					empleados: empleadosActivos,
					promedioHora: promedioHora,
				),
				const SizedBox(height: 16.0),
				_graficoPeriodos(context, datos),
				const SizedBox(height: 12.0),
				_seccionCard(
					context,
					titulo: 'Pago por empleado',
					icono: Icons.payments,
					colorIcono: Colors.teal,
					vacio: resumenes.isEmpty,
					mensajeVacio: 'Sin horas registradas en el filtro',
					extra: SegmentedButton<_CriterioNomina>(
						segments: const [
							ButtonSegment(
								value: _CriterioNomina.monto,
								label: Text('Por monto'),
								icon: Icon(Icons.attach_money, size: 18.0),
							),
							ButtonSegment(
								value: _CriterioNomina.horas,
								label: Text('Por horas'),
								icon: Icon(Icons.schedule, size: 18.0),
							),
						],
						selected: {_criterio},
						onSelectionChanged: (s) => setState(() => _criterio = s.first),
					),
					children: _filasEmpleado(resumenes),
				),
				if (_empleadoFiltroId != null && _periodoFiltroId == null) ...[
					const SizedBox(height: 12.0),
					_historialEmpleado(context, datos),
				],
				const SizedBox(height: 12.0),
				_distribucionPago(context, resumenes, totalMonto),
				const SizedBox(height: 12.0),
				_seccionCard(
					context,
					titulo: 'Detalle de líneas',
					icono: Icons.receipt_long,
					colorIcono: Colors.indigo,
					vacio: lineas.isEmpty,
					mensajeVacio: 'Sin líneas de nómina',
					children: lineas.map((l) => _filaLinea(l, datos.nombres)).toList(),
				),
				const SizedBox(height: 12.0),
				_listaPeriodos(context, datos),
				const SizedBox(height: 24.0),
			],
		);
	}

	Widget _estadoVacio(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(32.0),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(
							Icons.payments_outlined,
							size: 72.0,
							color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
						),
						const SizedBox(height: 16.0),
						Text(
							'Sin períodos de nómina',
							style: Theme.of(context).textTheme.titleLarge,
						),
						const SizedBox(height: 8.0),
						Text(
							'Calcule la nómina semanal a partir de las entradas '
							'de asistencia y las tarifas en Equipo.',
							textAlign: TextAlign.center,
							style: Theme.of(context).textTheme.bodyMedium?.copyWith(
								color: Theme.of(context).colorScheme.outline,
							),
						),
						const SizedBox(height: 24.0),
						FilledButton.icon(
							onPressed: _calculando ? null : () => _mostrarCalcularPeriodo(context),
							icon: _calculando
								? const SizedBox(
									width: 18.0,
									height: 18.0,
									child: CircularProgressIndicator(strokeWidth: 2.0),
								)
								: const Icon(Icons.calculate),
							label: Text(_calculando ? 'Calculando...' : 'Calcular última semana'),
						),
					],
				),
			),
		);
	}

	Widget _filtros(BuildContext context, _DatosNomina datos) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							children: [
								Icon(Icons.filter_alt, color: Theme.of(context).colorScheme.primary),
								const SizedBox(width: 8.0),
								Text(
									'Filtros',
									style: Theme.of(context).textTheme.titleSmall?.copyWith(
										fontWeight: FontWeight.w600,
									),
								),
							],
						),
						const SizedBox(height: 12.0),
						DropdownButtonFormField<String?>(
							key: ValueKey('periodo_$_periodoFiltroId'),
							initialValue: _periodoFiltroId,
							decoration: const InputDecoration(
								labelText: 'Período',
								border: OutlineInputBorder(),
								isDense: true,
								prefixIcon: Icon(Icons.date_range),
							),
							items: [
								const DropdownMenuItem<String?>(
									value: null,
									child: Text('Todos los períodos'),
								),
								...datos.periodos.map(
									(p) => DropdownMenuItem<String?>(
										value: p.id,
										child: Text(_formatoRangoPeriodo(p)),
									),
								),
							],
							onChanged: (v) => setState(() => _periodoFiltroId = v),
						),
						const SizedBox(height: 12.0),
						DropdownButtonFormField<String?>(
							key: ValueKey('empleado_$_empleadoFiltroId'),
							initialValue: _empleadoFiltroId,
							decoration: const InputDecoration(
								labelText: 'Empleado',
								border: OutlineInputBorder(),
								isDense: true,
								prefixIcon: Icon(Icons.person),
							),
							items: [
								const DropdownMenuItem<String?>(
									value: null,
									child: Text('Todos los empleados'),
								),
								...datos.empleados.map(
									(u) => DropdownMenuItem<String?>(
										value: u.id,
										child: Text(u.nombre),
									),
								),
							],
							onChanged: (v) => setState(() => _empleadoFiltroId = v),
						),
					],
				),
			),
		);
	}

	Widget _filaKpis(
		BuildContext context, {
		required double totalMonto,
		required double totalHoras,
		required int empleados,
		required double promedioHora,
	}) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final columnas = constraints.maxWidth >= 600 ? 4 : 2;
				return GridView.count(
					crossAxisCount: columnas,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					mainAxisSpacing: 8.0,
					crossAxisSpacing: 8.0,
					childAspectRatio: columnas == 4 ? 1.55 : 1.35,
					children: [
						_kpi(
							context,
							icono: Icons.payments,
							etiqueta: 'Total a pagar',
							valor: formatearMoneda(totalMonto),
							color: Colors.teal,
						),
						_kpi(
							context,
							icono: Icons.schedule,
							etiqueta: 'Horas trabajadas',
							valor: totalHoras.toStringAsFixed(1),
							color: Colors.orange,
						),
						_kpi(
							context,
							icono: Icons.groups,
							etiqueta: 'Empleados',
							valor: '$empleados',
							color: Colors.indigo,
						),
						_kpi(
							context,
							icono: Icons.trending_up,
							etiqueta: 'Promedio / hora',
							valor: formatearMoneda(promedioHora),
							color: Colors.deepPurple,
						),
					],
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
			elevation: 0.0,
			color: color.withValues(alpha: 0.08),
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(icono, color: color, size: 26.0),
						const SizedBox(height: 6.0),
						Text(
							valor,
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
							maxLines: 2,
						),
					],
				),
			),
		);
	}

	Widget _graficoPeriodos(BuildContext context, _DatosNomina datos) {
		final recientes = datos.periodos.take(6).toList().reversed.toList();
		if (recientes.isEmpty) {
			return const SizedBox.shrink();
		}
		final totales = recientes.map((p) {
			final lineas = datos.lineasPorPeriodo[p.id] ?? [];
			return lineas.fold(0.0, (a, l) => a + l.montoNeto);
		}).toList();
		final maxTotal = totales.isEmpty
			? 0.0
			: totales.reduce((a, b) => a > b ? a : b);

		return Card(
			child: Padding(
				padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								const Icon(Icons.bar_chart, color: Colors.teal, size: 22.0),
								const SizedBox(width: 8.0),
								Text(
									'Evolución por período',
									style: Theme.of(context).textTheme.titleMedium,
								),
							],
						),
						const SizedBox(height: 16.0),
						SizedBox(
							height: 140.0,
							child: Row(
								crossAxisAlignment: CrossAxisAlignment.end,
								children: [
									for (var i = 0; i < recientes.length; i++) ...[
										if (i > 0) const SizedBox(width: 8.0),
										Expanded(
											child: _columnaPeriodo(
												context,
												periodo: recientes[i],
												monto: totales[i],
												fraccion: maxTotal > 0 ? totales[i] / maxTotal : 0.0,
												seleccionado: _periodoFiltroId == recientes[i].id,
												alTocar: () => setState(
													() => _periodoFiltroId = recientes[i].id,
												),
											),
										),
									],
								],
							),
						),
					],
				),
			),
		);
	}

	Widget _columnaPeriodo(
		BuildContext context, {
		required PeriodoNomina periodo,
		required double monto,
		required double fraccion,
		required bool seleccionado,
		required VoidCallback alTocar,
	}) {
		final inicio = periodo.inicioEn.toLocal();
		final etiqueta = '${inicio.day}/${inicio.month}';
		return InkWell(
			onTap: alTocar,
			borderRadius: BorderRadius.circular(8.0),
			child: Column(
				mainAxisAlignment: MainAxisAlignment.end,
				children: [
					if (monto > 0)
						Text(
							formatearMoneda(monto),
							style: Theme.of(context).textTheme.labelSmall?.copyWith(
								fontWeight: FontWeight.w600,
								color: seleccionado ? Colors.teal : null,
							),
							textAlign: TextAlign.center,
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
						),
					const SizedBox(height: 4.0),
					AnimatedContainer(
						duration: const Duration(milliseconds: 300),
						height: (fraccion * 80.0).clamp(4.0, 80.0),
						decoration: BoxDecoration(
							color: seleccionado
								? Colors.teal
								: Colors.teal.withValues(alpha: 0.45),
							borderRadius: BorderRadius.circular(6.0),
							border: seleccionado
								? Border.all(color: Colors.teal.shade700, width: 2.0)
								: null,
						),
					),
					const SizedBox(height: 6.0),
					Text(
						etiqueta,
						style: Theme.of(context).textTheme.labelSmall,
						textAlign: TextAlign.center,
					),
				],
			),
		);
	}

	List<Widget> _filasEmpleado(List<_ResumenEmpleadoNomina> resumenes) {
		final ordenados = [...resumenes]
		  ..sort((a, b) {
				final va = _criterio == _CriterioNomina.monto ? a.monto : a.horas;
				final vb = _criterio == _CriterioNomina.monto ? b.monto : b.horas;
				return vb.compareTo(va);
			});
		if (ordenados.isEmpty) {
			return [];
		}
		final maxValor = _criterio == _CriterioNomina.monto
			? ordenados.first.monto
			: ordenados.first.horas;
		return ordenados.asMap().entries.map((entry) {
			final i = entry.key;
			final r = entry.value;
			final valor = _criterio == _CriterioNomina.monto ? r.monto : r.horas;
			final fraccion = maxValor > 0 ? valor / maxValor : 0.0;
			final color = _coloresEmpleado[i % _coloresEmpleado.length];
			return _filaConBarra(
				titulo: r.nombre,
				subtitulo: '${r.horas.toStringAsFixed(1)} h · '
					'${formatearMoneda(r.tarifaPromedio)}/h',
				valor: _criterio == _CriterioNomina.monto
					? formatearMoneda(r.monto)
					: '${r.horas.toStringAsFixed(1)} h',
				fraccion: fraccion,
				color: color,
			);
		}).toList();
	}

	Widget _historialEmpleado(BuildContext context, _DatosNomina datos) {
		final empleadoId = _empleadoFiltroId!;
		final nombre = datos.nombres[empleadoId] ?? empleadoId;
		final puntos = <({PeriodoNomina periodo, LineaNomina? linea})>[];
		for (final p in datos.periodos) {
			final linea = (datos.lineasPorPeriodo[p.id] ?? [])
				.where((l) => l.usuarioId == empleadoId)
				.firstOrNull;
			puntos.add((periodo: p, linea: linea));
		}
		final conDatos = puntos.where((p) => p.linea != null).toList();
		if (conDatos.isEmpty) {
			return const SizedBox.shrink();
		}
		final maxHoras = conDatos
			.map((p) => p.linea!.horasTrabajadas)
			.reduce((a, b) => a > b ? a : b);

		return _seccionCard(
			context,
			titulo: 'Historial de $nombre',
			icono: Icons.timeline,
			colorIcono: Colors.deepPurple,
			vacio: false,
			mensajeVacio: '',
			children: conDatos.map((p) {
				final l = p.linea!;
				return _filaConBarra(
					titulo: _formatoRangoPeriodo(p.periodo),
					subtitulo: formatearMoneda(l.montoNeto),
					valor: '${l.horasTrabajadas.toStringAsFixed(1)} h',
					fraccion: maxHoras > 0 ? l.horasTrabajadas / maxHoras : 0.0,
					color: Colors.deepPurple,
				);
			}).toList(),
		);
	}

	Widget _distribucionPago(
		BuildContext context,
		List<_ResumenEmpleadoNomina> resumenes,
		double totalMonto,
	) {
		if (resumenes.isEmpty || totalMonto <= 0) {
			return const SizedBox.shrink();
		}
		return Card(
			child: Padding(
				padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								const Icon(Icons.pie_chart_outline, color: Colors.deepPurple, size: 22.0),
								const SizedBox(width: 8.0),
								Text(
									'Distribución del pago',
									style: Theme.of(context).textTheme.titleMedium,
								),
							],
						),
						const SizedBox(height: 12.0),
						ClipRRect(
							borderRadius: BorderRadius.circular(8.0),
							child: Row(
								children: [
									for (var i = 0; i < resumenes.length; i++)
										Expanded(
											flex: (resumenes[i].monto / totalMonto * 100).round().clamp(1, 100),
											child: Container(
												height: 28.0,
												color: _coloresEmpleado[i % _coloresEmpleado.length],
											),
										),
								],
							),
						),
						const SizedBox(height: 12.0),
						Wrap(
							spacing: 12.0,
							runSpacing: 8.0,
							children: resumenes.asMap().entries.map((entry) {
								final i = entry.key;
								final r = entry.value;
								final pct = totalMonto > 0 ? r.monto / totalMonto * 100 : 0.0;
								return Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Container(
											width: 12.0,
											height: 12.0,
											decoration: BoxDecoration(
												color: _coloresEmpleado[i % _coloresEmpleado.length],
												borderRadius: BorderRadius.circular(2.0),
											),
										),
										const SizedBox(width: 6.0),
										Text(
											'${r.nombre} ${pct.toStringAsFixed(0)}%',
											style: Theme.of(context).textTheme.bodySmall,
										),
									],
								);
							}).toList(),
						),
					],
				),
			),
		);
	}

	Widget _filaLinea(LineaNomina linea, Map<String, String> nombres) {
		return ListTile(
			dense: true,
			contentPadding: EdgeInsets.zero,
			leading: CircleAvatar(
				radius: 18.0,
				backgroundColor: Colors.teal.withValues(alpha: 0.12),
				child: const Icon(Icons.person, size: 20.0, color: Colors.teal),
			),
			title: Text(nombres[linea.usuarioId] ?? linea.usuarioId),
			subtitle: Text(
				'${linea.horasTrabajadas.toStringAsFixed(1)} h × '
				'${formatearMoneda(linea.tarifaHora)}',
			),
			trailing: Text(
				formatearMoneda(linea.montoNeto),
				style: const TextStyle(fontWeight: FontWeight.w600),
			),
		);
	}

	Widget _listaPeriodos(BuildContext context, _DatosNomina datos) {
		return _seccionCard(
			context,
			titulo: 'Períodos cerrados',
			icono: Icons.history,
			colorIcono: Colors.blueGrey,
			vacio: datos.periodos.isEmpty,
			mensajeVacio: 'Sin períodos',
			children: datos.periodos.map((p) {
				final lineas = datos.lineasPorPeriodo[p.id] ?? [];
				final total = lineas.fold(0.0, (a, l) => a + l.montoNeto);
				final horas = lineas.fold(0.0, (a, l) => a + l.horasTrabajadas);
				return Card(
					margin: const EdgeInsets.only(bottom: 8.0),
					elevation: 0.0,
					color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
					child: ListTile(
						leading: CircleAvatar(
							backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
							child: const Icon(Icons.calendar_month, color: Colors.blueGrey),
						),
						title: Text(_formatoRangoPeriodo(p)),
						subtitle: Text(
							'${lineas.length} empleados · '
							'${horas.toStringAsFixed(1)} h · '
							'${formatearMoneda(total)}',
						),
						trailing: IconButton(
							icon: const Icon(Icons.download_outlined),
							tooltip: 'Copiar CSV',
							onPressed: () => _exportar(context, p.id),
						),
						onTap: () => setState(() => _periodoFiltroId = p.id),
					),
				);
			}).toList(),
		);
	}

	Widget _seccionCard(
		BuildContext context, {
		required String titulo,
		required IconData icono,
		Color colorIcono = PosiaColors.cobrar,
		required bool vacio,
		required String mensajeVacio,
		required List<Widget> children,
		Widget? extra,
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
								Expanded(
									child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
								),
							],
						),
						if (extra != null) ...[
							const SizedBox(height: 10.0),
							extra,
						],
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
											style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
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
					const SizedBox(height: 6.0),
					ClipRRect(
						borderRadius: BorderRadius.circular(4.0),
						child: LinearProgressIndicator(
							value: fraccion.clamp(0.0, 1.0),
							minHeight: 8.0,
							backgroundColor: color.withValues(alpha: 0.12),
							color: color,
						),
					),
				],
			),
		);
	}

	List<LineaNomina> _lineasFiltradas(_DatosNomina datos) {
		final acumulado = <LineaNomina>[];
		if (_periodoFiltroId != null) {
			acumulado.addAll(datos.lineasPorPeriodo[_periodoFiltroId] ?? []);
		} else {
			for (final lineas in datos.lineasPorPeriodo.values) {
				acumulado.addAll(lineas);
			}
		}
		if (_empleadoFiltroId != null) {
			return acumulado.where((l) => l.usuarioId == _empleadoFiltroId).toList();
		}
		return acumulado;
	}

	List<_ResumenEmpleadoNomina> _agruparPorEmpleado(
		List<LineaNomina> lineas,
		Map<String, String> nombres,
	) {
		final mapa = <String, _ResumenEmpleadoNomina>{};
		for (final l in lineas) {
			final previo = mapa[l.usuarioId];
			if (previo == null) {
				mapa[l.usuarioId] = _ResumenEmpleadoNomina(
					usuarioId: l.usuarioId,
					nombre: nombres[l.usuarioId] ?? l.usuarioId,
					horas: l.horasTrabajadas,
					monto: l.montoNeto,
				);
			} else {
				final horas = previo.horas + l.horasTrabajadas;
				final monto = previo.monto + l.montoNeto;
				mapa[l.usuarioId] = _ResumenEmpleadoNomina(
					usuarioId: l.usuarioId,
					nombre: previo.nombre,
					horas: horas,
					monto: monto,
				);
			}
		}
		return mapa.values.toList();
	}

	String _etiquetaPeriodo(_DatosNomina datos) {
		if (_periodoFiltroId != null) {
			final p = datos.periodos.where((x) => x.id == _periodoFiltroId).firstOrNull;
			if (p != null) {
				return 'Período: ${_formatoRangoPeriodo(p)}';
			}
		}
		if (_empleadoFiltroId != null) {
			final nombre = datos.nombres[_empleadoFiltroId] ?? _empleadoFiltroId!;
			return 'Empleado: $nombre · Todos los períodos';
		}
		return 'Todos los períodos y empleados';
	}

	String _formatoRangoPeriodo(PeriodoNomina p) {
		final i = p.inicioEn.toLocal();
		final f = p.finEn.toLocal();
		return '${i.day.toString().padLeft(2, '0')}/${i.month.toString().padLeft(2, '0')}/${i.year} — '
			'${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
	}

	Future<void> _mostrarCalcularPeriodo(BuildContext context) async {
		final dias = await showModalBottomSheet<int>(
			context: context,
			showDragHandle: true,
			builder: (ctx) => SafeArea(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Padding(
							padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
							child: Text(
								'Calcular nómina',
								style: Theme.of(ctx).textTheme.titleMedium,
							),
						),
						ListTile(
							leading: const Icon(Icons.date_range),
							title: const Text('Últimos 7 días'),
							onTap: () => Navigator.pop(ctx, 7),
						),
						ListTile(
							leading: const Icon(Icons.date_range),
							title: const Text('Últimos 14 días'),
							onTap: () => Navigator.pop(ctx, 14),
						),
						ListTile(
							leading: const Icon(Icons.calendar_month),
							title: const Text('Últimos 30 días'),
							onTap: () => Navigator.pop(ctx, 30),
						),
						const SizedBox(height: 8.0),
					],
				),
			),
		);
		if (dias == null || !mounted) {
			return;
		}
		await _cerrarPeriodo(dias: dias);
	}

	Future<void> _cerrarPeriodo({required int dias}) async {
		if (!mounted) {
			return;
		}
		final messenger = ScaffoldMessenger.of(context);
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario == null) {
			return;
		}
		setState(() => _calculando = true);
		try {
			final fin = DateTime.now().toUtc();
			final inicio = fin.subtract(Duration(days: dias));
			final contenedor = await ref.read(contenedorServiciosProvider.future);
			final nomina = contenedor.servicioNomina;
			if (nomina == null) {
				return;
			}
			final periodo = await nomina.cerrarPeriodo(
				inicio: inicio,
				fin: fin,
				cerradoPor: usuario.id,
			);
			ref.invalidate(_datosNominaProvider);
			if (mounted) {
				setState(() => _periodoFiltroId = periodo.id);
				messenger.showSnackBar(
					SnackBar(
						content: Text(
							'Período calculado (${_formatoRangoPeriodo(periodo)})',
						),
					),
				);
			}
		} finally {
			if (mounted) {
				setState(() => _calculando = false);
			}
		}
	}

	Future<void> _exportar(BuildContext context, String periodoId) async {
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final csv = await contenedor.servicioNomina?.exportarPeriodoCsv(periodoId);
		if (csv == null || !context.mounted) {
			return;
		}
		await Clipboard.setData(ClipboardData(text: csv));
		if (!context.mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('CSV copiado al portapapeles')),
		);
	}
}

enum _CriterioNomina { monto, horas }

class _ResumenEmpleadoNomina {
	const _ResumenEmpleadoNomina({
		required this.usuarioId,
		required this.nombre,
		required this.horas,
		required this.monto,
	});

	final String usuarioId;
	final String nombre;
	final double horas;
	final double monto;

	double get tarifaPromedio => horas > 0 ? monto / horas : 0.0;
}

class _DatosNomina {
	const _DatosNomina({
		required this.periodos,
		required this.lineasPorPeriodo,
		required this.nombres,
		required this.empleados,
	});

	final List<PeriodoNomina> periodos;
	final Map<String, List<LineaNomina>> lineasPorPeriodo;
	final Map<String, String> nombres;
	final List<Usuario> empleados;
}

final _datosNominaProvider = FutureProvider<_DatosNomina>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final nomina = contenedor.servicioNomina;
	if (nomina == null) {
		return const _DatosNomina(
			periodos: [],
			lineasPorPeriodo: {},
			nombres: {},
			empleados: [],
		);
	}
	final servicio = await ref.watch(servicioAdminProvider.future);
	final periodos = await nomina.listarPeriodos();
	final usuarios = await servicio.listarUsuarios();
	final empleados = usuarios
		.where((u) => u.activo && u.rol != RolUsuario.administrador)
		.toList()
	  ..sort((a, b) => a.nombre.compareTo(b.nombre));
	final nombres = {for (final u in usuarios) u.id: u.nombre};
	final lineasPorPeriodo = <String, List<LineaNomina>>{};
	for (final p in periodos) {
		lineasPorPeriodo[p.id] = await nomina.listarLineasPeriodo(p.id);
	}
	return _DatosNomina(
		periodos: periodos,
		lineasPorPeriodo: lineasPorPeriodo,
		nombres: nombres,
		empleados: empleados,
	);
});
