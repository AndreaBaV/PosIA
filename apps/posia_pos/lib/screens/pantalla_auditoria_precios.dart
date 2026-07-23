/// Reporte de auditoría de precios manuales (sobreprecio / descuento) por
/// empleado. Lee la BD local (ya sincronizada desde Neon), así el admin ve lo
/// mismo desde cualquier dispositivo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';

/// Lista las líneas vendidas con precio manual, agrupadas por vendedor.
class PantallaAuditoriaPrecios extends ConsumerStatefulWidget {
	const PantallaAuditoriaPrecios({super.key});

	@override
	ConsumerState<PantallaAuditoriaPrecios> createState() =>
		_PantallaAuditoriaPreciosState();
}

class _PantallaAuditoriaPreciosState
	extends ConsumerState<PantallaAuditoriaPrecios> {
	int _dias = 30;

	@override
	Widget build(BuildContext context) {
		final asyncRegistros = ref.watch(preciosManualesProvider(_dias));
		return Scaffold(
			appBar: AppBar(title: const Text('Precios manuales')),
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
					const Padding(
						padding: EdgeInsets.symmetric(horizontal: 12.0),
						child: Text(
							'Ventas donde se fijó el precio a mano. El precio "normal" es el '
							'base actual del producto (referencia; pudo cambiar desde la venta).',
							style: TextStyle(fontSize: 12.0, color: Colors.grey),
						),
					),
					const SizedBox(height: 8.0),
					Expanded(
						child: asyncRegistros.when(
							loading: () =>
								const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(child: Text('Error: $e')),
							data: (registros) => _construirLista(context, registros),
						),
					),
				],
			),
		);
	}

	Widget _construirLista(
		BuildContext context,
		List<RegistroPrecioManual> registros,
	) {
		if (registros.isEmpty) {
			return const Center(
				child: Padding(
					padding: EdgeInsets.all(24.0),
					child: Text(
						'Sin precios manuales en el periodo.',
						textAlign: TextAlign.center,
					),
				),
			);
		}
		final porVendedor = <String, List<RegistroPrecioManual>>{};
		for (final r in registros) {
			porVendedor.putIfAbsent(r.vendedorNombre, () => []).add(r);
		}
		final vendedores = porVendedor.keys.toList()..sort();
		return ListView(
			padding: const EdgeInsets.all(8.0),
			children: [
				for (final vendedor in vendedores)
					_seccionVendedor(context, vendedor, porVendedor[vendedor]!),
			],
		);
	}

	Widget _seccionVendedor(
		BuildContext context,
		String vendedor,
		List<RegistroPrecioManual> filas,
	) {
		final totalDelta = filas.fold<double>(
			0.0,
			(suma, r) => suma + (r.diferenciaTotal ?? 0.0),
		);
		return Card(
			margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
			child: ExpansionTile(
				initiallyExpanded: filas.length <= 3,
				title: Text(
					vendedor,
					style: const TextStyle(fontWeight: FontWeight.bold),
				),
				subtitle: Text(
					'${filas.length} línea(s) · Total ${_signo(totalDelta)}'
					'${formatearMoneda(totalDelta.abs())}',
					style: TextStyle(
						color: totalDelta >= 0
							? Colors.orange.shade900
							: PosiaColors.cancelar,
						fontWeight: FontWeight.w600,
					),
				),
				children: [
					for (final r in filas) _filaRegistro(context, r),
				],
			),
		);
	}

	Widget _filaRegistro(BuildContext context, RegistroPrecioManual r) {
		final delta = r.diferenciaTotal;
		return ListTile(
			dense: true,
			title: Text(r.nombreProducto),
			subtitle: Text(
				'${_fecha(r.fecha)} · ${_cantidad(r.cantidad)} × '
				'${formatearMoneda(r.precioCobrado)}',
			),
			trailing: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				crossAxisAlignment: CrossAxisAlignment.end,
				children: [
					if (r.precioReferencia != null)
						Text(
							'normal ${formatearMoneda(r.precioReferencia!)}',
							style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
						),
					if (delta != null)
						Text(
							'${_signo(delta)}${formatearMoneda(delta.abs())}',
							style: TextStyle(
								fontWeight: FontWeight.bold,
								color: delta >= 0
									? Colors.orange.shade900
									: PosiaColors.cancelar,
							),
						),
				],
			),
		);
	}

	String _signo(double valor) => valor >= 0 ? '+' : '−';

	String _fecha(DateTime fecha) {
		final l = fecha.toLocal();
		final hh = l.hour.toString().padLeft(2, '0');
		final mm = l.minute.toString().padLeft(2, '0');
		return '${l.day}/${l.month} $hh:$mm';
	}

	String _cantidad(double c) {
		if (c == c.roundToDouble()) {
			return c.toStringAsFixed(0);
		}
		return c
			.toStringAsFixed(3)
			.replaceAll(RegExp(r'0+$'), '')
			.replaceAll(RegExp(r'\.$'), '');
	}
}
