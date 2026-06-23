/// Dialogo de captura de peso para venta por kilogramo o gramos.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';
import 'teclado_numerico_simple.dart';

/// Resultado del dialogo de peso.
class ResultadoDialogoPeso {
	const ResultadoDialogoPeso({
		required this.confirmado,
		required this.pesoKg,
	});

	final bool confirmado;
	final double pesoKg;
}

enum _UnidadCapturaPeso { kilogramos, gramos }

/// Muestra dialogo para capturar peso en kg o gramos.
class DialogoPesoCarniceria extends StatefulWidget {
	const DialogoPesoCarniceria({required this.producto, super.key});

	final Producto producto;

	static Future<ResultadoDialogoPeso> mostrar(
		BuildContext context,
		Producto producto,
	) async {
		final resultado = await showDialog<ResultadoDialogoPeso>(
			context: context,
			builder: (_) => DialogoPesoCarniceria(producto: producto),
		);
		return resultado ?? const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0);
	}

	@override
	State<DialogoPesoCarniceria> createState() => _DialogoPesoCarniceriaState();
}

class _DialogoPesoCarniceriaState extends State<DialogoPesoCarniceria> {
	String _valorPeso = '';
	_UnidadCapturaPeso _unidad = _UnidadCapturaPeso.kilogramos;

	@override
	Widget build(BuildContext context) {
		final etiquetaUnidad = _unidad == _UnidadCapturaPeso.kilogramos ? 'kg' : 'g';
		return AlertDialog(
			title: Row(
				children: [
					const Icon(Icons.scale, color: PosiaColors.cobrar, size: 32.0),
					const SizedBox(width: 8.0),
					Expanded(child: Text(widget.producto.nombre)),
				],
			),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					SegmentedButton<_UnidadCapturaPeso>(
						segments: const [
							ButtonSegment(
								value: _UnidadCapturaPeso.kilogramos,
								label: Text('Kilogramos'),
							),
							ButtonSegment(
								value: _UnidadCapturaPeso.gramos,
								label: Text('Gramos'),
							),
						],
						selected: {_unidad},
						onSelectionChanged: (s) => setState(() {
							_unidad = s.first;
							_valorPeso = '';
						}),
					),
					const SizedBox(height: 8.0),
					Text(
						_valorPeso.isEmpty ? '0 $etiquetaUnidad' : '$_valorPeso $etiquetaUnidad',
						style: Theme.of(context).textTheme.headlineSmall,
					),
					const SizedBox(height: 8.0),
					TecladoNumericoSimple(
						valorActual: _valorPeso,
						alPresionarTecla: _agregarTecla,
						alBorrar: _borrarTecla,
					),
				],
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(
						const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0),
					),
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: _confirmar,
					child: const Text('Agregar'),
				),
			],
		);
	}

	void _agregarTecla(String tecla) {
		if (tecla == '.' && _valorPeso.contains('.')) {
			return;
		}
		setState(() {
			_valorPeso = _valorPeso + tecla;
		});
	}

	void _borrarTecla() {
		if (_valorPeso.isEmpty) {
			return;
		}
		setState(() {
			_valorPeso = _valorPeso.substring(0, _valorPeso.length - 1);
		});
	}

	void _confirmar() {
		final cantidad = double.tryParse(_valorPeso.isEmpty ? '0' : _valorPeso) ?? 0.0;
		if (cantidad <= 0.0) {
			return;
		}
		final pesoKg = _unidad == _UnidadCapturaPeso.gramos
			? cantidad / 1000.0
			: cantidad;
		Navigator.of(context).pop(
			ResultadoDialogoPeso(confirmado: true, pesoKg: pesoKg),
		);
	}
}
