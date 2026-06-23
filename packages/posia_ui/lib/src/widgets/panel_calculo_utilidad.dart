/// Panel compacto para sugerir precio de venta segun costo y utilidad.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// Campo de utilidad (%) y boton para aplicar precio sugerido sobre costo.
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
	final _utilidadController = TextEditingController(
		text: UTILIDAD_SUGERIDA_PORCENTAJE.toStringAsFixed(0),
	);

	@override
	void dispose() {
		_utilidadController.dispose();
		super.dispose();
	}

	double get _utilidad =>
		double.tryParse(_utilidadController.text.replaceAll(',', '.')) ??
		UTILIDAD_SUGERIDA_PORCENTAJE;

	double? get _precioSugerido {
		if (widget.costoUnitario <= 0) {
			return null;
		}
		try {
			return calcularPrecioVentaDesdeUtilidad(
				costoUnitario: widget.costoUnitario,
				porcentajeUtilidad: _utilidad,
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
			return const SizedBox.shrink();
		}

		final sugerido = _precioSugerido;
		final etiquetaBoton = sugerido != null
			? 'Usar ${formatearMoneda(sugerido)}'
			: 'Calcular precio';

		return Padding(
			padding: const EdgeInsets.only(top: 4.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Text(
						'Costo ${formatearMoneda(widget.costoUnitario)} · utilidad sobre costo',
						style: Theme.of(context).textTheme.bodySmall?.copyWith(
							color: Colors.grey.shade700,
						),
					),
					const SizedBox(height: 8.0),
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							SizedBox(
								width: 96.0,
								child: TextField(
									controller: _utilidadController,
									keyboardType: const TextInputType.numberWithOptions(decimal: true),
									decoration: const InputDecoration(
										labelText: 'Utilidad',
										suffixText: '%',
										isDense: true,
										border: OutlineInputBorder(),
									),
									onChanged: (_) => setState(() {}),
								),
							),
							const SizedBox(width: 8.0),
							Expanded(
								child: FilledButton.tonal(
									onPressed: sugerido == null ? null : _aplicarPrecioSugerido,
									style: FilledButton.styleFrom(
										padding: const EdgeInsets.symmetric(vertical: 14.0),
									),
									child: Text(etiquetaBoton),
								),
							),
						],
					),
				],
			),
		);
	}
}
