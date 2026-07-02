/// Dialogo de captura de peso para venta por kilogramo o gramos.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';
import 'banner_mensaje_dialogo.dart';
import 'contenido_dialogo_teclado.dart';

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
	const DialogoPesoCarniceria({
		required this.producto,
		this.resolverPrecio,
		super.key,
	});

	final Producto producto;

	/// Resuelve precio por kg segun peso capturado (escalas, cliente, etc.).
	final Future<ResultadoPrecio> Function(double pesoKg)? resolverPrecio;

	static Future<ResultadoDialogoPeso> mostrar(
		BuildContext context,
		Producto producto, {
		Future<ResultadoPrecio> Function(double pesoKg)? resolverPrecio,
	}) async {
		final resultado = await showDialog<ResultadoDialogoPeso>(
			context: context,
			builder: (_) => DialogoPesoCarniceria(
				producto: producto,
				resolverPrecio: resolverPrecio,
			),
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
	ResultadoPrecio? _precioResuelto;
	var _resolviendoPrecio = false;
	String? _mensajeError;

	@override
	void initState() {
		super.initState();
		_pesoFocus = FocusNode(onKeyEvent: _manejarTeclaPeso);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted && _pesoFocus.canRequestFocus) {
				_pesoFocus.requestFocus();
			}
			_actualizarPrecioResuelto();
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

	double? _pesoKgCapturado() {
		final cantidad = double.tryParse(_valorPeso.isEmpty ? '0' : _valorPeso) ?? 0.0;
		if (cantidad <= 0.0) {
			return null;
		}
		return _unidad == _UnidadCapturaPeso.gramos
			? cantidad / 1000.0
			: cantidad;
	}

	Future<void> _actualizarPrecioResuelto() async {
		final pesoKg = _pesoKgCapturado();
		final resolver = widget.resolverPrecio;
		if (pesoKg == null || resolver == null) {
			if (!mounted) {
				return;
			}
			setState(() {
				_precioResuelto = null;
				_resolviendoPrecio = false;
			});
			return;
		}
		setState(() => _resolviendoPrecio = true);
		try {
			final resultado = await resolver(pesoKg);
			if (!mounted) {
				return;
			}
			setState(() {
				_precioResuelto = resultado;
				_resolviendoPrecio = false;
			});
		} catch (_) {
			if (!mounted) {
				return;
			}
			setState(() {
				_precioResuelto = null;
				_resolviendoPrecio = false;
			});
		}
	}

	Widget _buildResumenPrecio() {
		final pesoKg = _pesoKgCapturado();
		if (pesoKg == null) {
			return Text(
				'${formatearMoneda(widget.producto.precioBase)} / kg',
				style: Theme.of(context).textTheme.titleMedium?.copyWith(
					color: PosiaColors.cobrar,
					fontWeight: FontWeight.w600,
				),
			);
		}
		if (_resolviendoPrecio) {
			return const SizedBox(
				height: 24.0,
				width: 24.0,
				child: CircularProgressIndicator(strokeWidth: 2.0),
			);
		}
		final precioKg = _precioResuelto?.precioUnitario ?? widget.producto.precioBase;
		final total = redondearMonto(precioKg * pesoKg);
		final regla = _precioResuelto?.reglaAplicada;
		return Column(
			children: [
				Text(
					'${formatearMoneda(precioKg)} / kg',
					style: Theme.of(context).textTheme.titleMedium?.copyWith(
						color: PosiaColors.cobrar,
						fontWeight: FontWeight.w600,
					),
				),
				const SizedBox(height: 4.0),
				Text(
					'${formatearPesoKg(pesoKg)} · Total ${formatearMoneda(total)}',
					style: Theme.of(context).textTheme.bodyLarge?.copyWith(
						fontWeight: FontWeight.w600,
					),
				),
				if (regla == ReglaPrecio.escalaMayoreo) ...[
					const SizedBox(height: 4.0),
					Text(
						'Precio según tramo de peso',
						style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
					),
				],
			],
		);
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
			content: ContenidoDialogoTeclado(
				ancho: 320.0,
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
						_buildResumenPrecio(),
						const SizedBox(height: 12.0),
						TextField(
							controller: _pesoController,
							focusNode: _pesoFocus,
							autofocus: true,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							showCursor: true,
							textInputAction: TextInputAction.done,
							decoration: InputDecoration(
								labelText: 'Peso',
								suffixText: etiquetaUnidad,
								hintText: _unidad == _UnidadCapturaPeso.gramos ? '250' : '0.250',
								border: const OutlineInputBorder(),
								helperText: 'Enter agrega · Esc cancela',
							),
							onChanged: (texto) {
								_limpiarError();
								_establecerValor(_normalizarEntradaPeso(texto));
								_actualizarPrecioResuelto();
							},
						),
						if (_mensajeError != null)
							BannerMensajeDialogo(
								mensaje: _mensajeError!,
								padding: const EdgeInsets.only(top: 8.0),
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
		final pesoKg = _pesoKgCapturado();
		if (pesoKg == null) {
			_mostrarError('Indique un peso mayor a cero');
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			ResultadoDialogoPeso(confirmado: true, pesoKg: pesoKg),
		);
	}

	void _mostrarError(String mensaje) {
		if (!mounted) {
			return;
		}
		setState(() => _mensajeError = mensaje);
	}

	void _limpiarError() {
		if (_mensajeError == null) {
			return;
		}
		setState(() => _mensajeError = null);
	}
}
