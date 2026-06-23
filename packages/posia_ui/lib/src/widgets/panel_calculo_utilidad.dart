/// Panel para calcular precio de venta segun costo y utilidad.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// Selector de modo, porcentaje y aplicacion de precio sugerido.
class PanelCalculoUtilidad extends StatefulWidget {
	const PanelCalculoUtilidad({
		required this.costoUnitario,
		required this.precioController,
		this.alCambiarPrecio,
		super.key,
	});

	final double costoUnitario;
	final TextEditingController precioController;
	final VoidCallback? alCambiarPrecio;

	@override
	State<PanelCalculoUtilidad> createState() => _PanelCalculoUtilidadState();
}

class _PanelCalculoUtilidadState extends State<PanelCalculoUtilidad> {
	ModoCalculoUtilidad _modo = ModoCalculoUtilidad.sobreCosto;
	final _utilidadController = TextEditingController(
		text: UTILIDAD_SUGERIDA_PORCENTAJE.toStringAsFixed(0),
	);

	static const _presets = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0];

	@override
	void initState() {
		super.initState();
		widget.precioController.addListener(_onPrecioCambiado);
	}

	@override
	void didUpdateWidget(PanelCalculoUtilidad oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.precioController != widget.precioController) {
			oldWidget.precioController.removeListener(_onPrecioCambiado);
			widget.precioController.addListener(_onPrecioCambiado);
		}
	}

	void _onPrecioCambiado() => setState(() {});

	@override
	void dispose() {
		widget.precioController.removeListener(_onPrecioCambiado);
		_utilidadController.dispose();
		super.dispose();
	}

	double get _utilidad =>
		double.tryParse(_utilidadController.text.replaceAll(',', '.')) ??
		UTILIDAD_SUGERIDA_PORCENTAJE;

	double? get _precioActual =>
		double.tryParse(widget.precioController.text.replaceAll(',', '.'));

	double? get _precioSugerido {
		if (widget.costoUnitario <= 0) {
			return null;
		}
		try {
			return calcularPrecioVentaDesdeUtilidad(
				costoUnitario: widget.costoUnitario,
				porcentajeUtilidad: _utilidad,
				modo: _modo,
			);
		} catch (_) {
			return null;
		}
	}

	void _aplicarPrecioSugerido() {
		final sugerido = _precioSugerido;
		if (sugerido == null) {
			return;
		}
		widget.precioController.text = sugerido.toStringAsFixed(2);
		widget.alCambiarPrecio?.call();
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		if (widget.costoUnitario <= 0) {
			return const Card(
				child: Padding(
					padding: EdgeInsets.all(12.0),
					child: Text(
						'Registre el costo de compra para calcular utilidad.',
						style: TextStyle(color: Colors.grey),
					),
				),
			);
		}

		final precioActual = _precioActual;
		final utilidadActual = precioActual != null && precioActual > 0
			? calcularUtilidadPorcentaje(
				costoUnitario: widget.costoUnitario,
				precioVenta: precioActual,
				modo: _modo,
			)
			: null;
		final sugerido = _precioSugerido;
		final minimo = calcularPrecioMinimoVenta(widget.costoUnitario);

		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						const Text(
							'Calculo de utilidad',
							style: TextStyle(fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 8.0),
						Text('Costo: ${formatearMoneda(widget.costoUnitario)}'),
						Text('Precio minimo: ${formatearMoneda(minimo)}'),
						if (utilidadActual != null)
							Text('Utilidad actual: ${utilidadActual.toStringAsFixed(1)}%'),
						const SizedBox(height: 8.0),
						DropdownButtonFormField<ModoCalculoUtilidad>(
							initialValue: _modo,
							decoration: const InputDecoration(
								labelText: 'Modo de calculo',
								isDense: true,
								border: OutlineInputBorder(),
							),
							items: ModoCalculoUtilidad.values
								.map(
									(m) => DropdownMenuItem(
										value: m,
										child: Text(etiquetaModoCalculoUtilidad(m)),
									),
								)
								.toList(),
							onChanged: (v) => setState(() => _modo = v!),
						),
						const SizedBox(height: 8.0),
						TextField(
							controller: _utilidadController,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							decoration: InputDecoration(
								labelText: _modo == ModoCalculoUtilidad.sobreCosto
									? 'Utilidad (%) sobre costo'
									: 'Margen (%) sobre venta',
								border: const OutlineInputBorder(),
								suffixText: '%',
							),
							onChanged: (_) => setState(() {}),
						),
						const SizedBox(height: 8.0),
						Wrap(
							spacing: 6.0,
							runSpacing: 4.0,
							children: _presets.map((p) {
								return ActionChip(
									label: Text('${p.toStringAsFixed(0)}%'),
									onPressed: () {
										_utilidadController.text = p.toStringAsFixed(0);
										setState(() {});
									},
								);
							}).toList(),
						),
						if (sugerido != null) ...[
							const SizedBox(height: 8.0),
							Text(
								'Precio sugerido: ${formatearMoneda(sugerido)}',
								style: const TextStyle(fontWeight: FontWeight.w600),
							),
						],
						const SizedBox(height: 8.0),
						OutlinedButton.icon(
							onPressed: sugerido == null ? null : _aplicarPrecioSugerido,
							icon: const Icon(Icons.calculate),
							label: const Text('Aplicar precio sugerido'),
						),
					],
				),
			),
		);
	}
}
