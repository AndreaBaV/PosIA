/// Dialogo de captura de peso para venta por kilogramo o gramos.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
	final _pesoController = TextEditingController();
	late final FocusNode _pesoFocus;
	String _valorPeso = '';
	_UnidadCapturaPeso _unidad = _UnidadCapturaPeso.kilogramos;
	var _cerrado = false;

	@override
	void initState() {
		super.initState();
		_pesoFocus = FocusNode(onKeyEvent: _manejarTeclaPeso);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted && _pesoFocus.canRequestFocus) {
				_pesoFocus.requestFocus();
			}
		});
	}

	@override
	void dispose() {
		_pesoController.dispose();
		_pesoFocus.dispose();
		super.dispose();
	}

	KeyEventResult _manejarTeclaPeso(FocusNode node, KeyEvent event) {
		if (event is! KeyDownEvent) {
			return KeyEventResult.ignored;
		}
		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			_confirmar();
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.escape) {
			_cancelar();
			return KeyEventResult.handled;
		}
		return KeyEventResult.ignored;
	}

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
			content: SizedBox(
				width: 320.0,
				child: Column(
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
								_establecerValor('');
							}),
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: _pesoController,
							focusNode: _pesoFocus,
							autofocus: true,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							textInputAction: TextInputAction.done,
							decoration: InputDecoration(
								labelText: 'Peso',
								suffixText: etiquetaUnidad,
								hintText: _unidad == _UnidadCapturaPeso.gramos ? '250' : '0.250',
								border: const OutlineInputBorder(),
								helperText: 'Enter agrega · Esc cancela',
							),
							onChanged: (texto) =>
								_establecerValor(_normalizarEntradaPeso(texto)),
						),
						const SizedBox(height: 8.0),
						TecladoNumericoSimple(
							valorActual: _valorPeso,
							mostrarValor: false,
							alPresionarTecla: _agregarTecla,
							alBorrar: _borrarTecla,
						),
					],
				),
			),
			actions: [
				TextButton(
					onPressed: _cancelar,
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: _confirmar,
					child: const Text('Agregar'),
				),
			],
		);
	}

	void _establecerValor(String valor) {
		setState(() => _valorPeso = valor);
		if (_pesoController.text == valor) {
			return;
		}
		_pesoController.value = TextEditingValue(
			text: valor,
			selection: TextSelection.collapsed(offset: valor.length),
		);
	}

	String _normalizarEntradaPeso(String raw) {
		final texto = raw.replaceAll(',', '.');
		final buffer = StringBuffer();
		var puntoVisto = false;
		for (final caracter in texto.split('')) {
			if (caracter == '.' && !puntoVisto) {
				puntoVisto = true;
				buffer.write(caracter);
			} else if (RegExp(r'\d').hasMatch(caracter)) {
				buffer.write(caracter);
			}
		}
		return buffer.toString();
	}

	void _agregarTecla(String tecla) {
		if (tecla == '.' && _valorPeso.contains('.')) {
			return;
		}
		_establecerValor(_valorPeso + tecla);
	}

	void _borrarTecla() {
		if (_valorPeso.isEmpty) {
			return;
		}
		_establecerValor(_valorPeso.substring(0, _valorPeso.length - 1));
	}

	void _cancelar() {
		if (_cerrado || !mounted) {
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0),
		);
	}

	void _confirmar() {
		if (_cerrado || !mounted) {
			return;
		}
		final cantidad = double.tryParse(_valorPeso.isEmpty ? '0' : _valorPeso) ?? 0.0;
		if (cantidad <= 0.0) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Indique un peso mayor a cero')),
			);
			return;
		}
		final pesoKg = _unidad == _UnidadCapturaPeso.gramos
			? cantidad / 1000.0
			: cantidad;
		_cerrado = true;
		Navigator.of(context).pop(
			ResultadoDialogoPeso(confirmado: true, pesoKg: pesoKg),
		);
	}
}
