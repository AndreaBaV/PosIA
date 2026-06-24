/// Campo para capturar y editar un atajo de teclado.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/posia_theme.dart';
import '../utils/teclas_caja_util.dart';

/// Muestra el atajo actual y permite capturarlo pulsando una combinacion.
class CampoAtajoTeclado extends StatefulWidget {
	const CampoAtajoTeclado({
		required this.valor,
		required this.alCambiar,
		this.habilitado = true,
		super.key,
	});

	final String valor;
	final ValueChanged<String> alCambiar;
	final bool habilitado;

	@override
	State<CampoAtajoTeclado> createState() => _CampoAtajoTecladoState();
}

class _CampoAtajoTecladoState extends State<CampoAtajoTeclado> {
	var _capturando = false;
	KeyEventCallback? _manejadorCaptura;

	@override
	void dispose() {
		_detenerCaptura();
		super.dispose();
	}

	void _detenerCaptura() {
		if (_manejadorCaptura != null) {
			HardwareKeyboard.instance.removeHandler(_manejadorCaptura!);
			_manejadorCaptura = null;
		}
		_capturando = false;
	}

	void _iniciarCaptura() {
		if (!widget.habilitado) {
			return;
		}
		_detenerCaptura();
		setState(() => _capturando = true);
		_manejadorCaptura = (KeyEvent event) {
			if (event is! KeyDownEvent) {
				return false;
			}
			if (event.logicalKey == LogicalKeyboardKey.escape) {
				_detenerCaptura();
				if (mounted) {
					setState(() {});
				}
				return true;
			}
			final serializado = serializarAtajoDesdeEvento(event);
			if (serializado.isEmpty) {
				return false;
			}
			widget.alCambiar(serializado);
			_detenerCaptura();
			if (mounted) {
				setState(() {});
			}
			return true;
		};
		HardwareKeyboard.instance.addHandler(_manejadorCaptura!);
	}

	@override
	Widget build(BuildContext context) {
		final etiqueta = etiquetaAtajoConfigurado(widget.valor);
		return Row(
			children: [
				Expanded(
					child: InputDecorator(
						decoration: InputDecoration(
							labelText: 'Atajo',
							border: const OutlineInputBorder(),
							helperText: _capturando
								? 'Pulsa la combinacion · Esc cancela'
								: 'Ej. F2, CTRL+T, ESCAPE',
							filled: true,
							fillColor: _capturando
								? PosiaColors.cobrar.withValues(alpha: 0.08)
								: null,
						),
						child: Text(
							_capturando ? 'Escuchando…' : etiqueta,
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
								fontWeight: FontWeight.w700,
								letterSpacing: 0.5,
							),
						),
					),
				),
				const SizedBox(width: 8.0),
				FilledButton.tonal(
					onPressed: widget.habilitado
						? (_capturando ? () {
							_detenerCaptura();
							setState(() {});
						} : _iniciarCaptura)
						: null,
					child: Text(_capturando ? 'Cancelar' : 'Capturar'),
				),
				if (widget.valor.isNotEmpty) ...[
					const SizedBox(width: 4.0),
					IconButton(
						tooltip: 'Restablecer',
						onPressed: widget.habilitado
							? () => widget.alCambiar('')
							: null,
						icon: const Icon(Icons.restart_alt),
					),
				],
			],
		);
	}
}
