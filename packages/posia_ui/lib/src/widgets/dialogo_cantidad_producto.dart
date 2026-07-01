/// Dialogo de captura de cantidad para agregar producto al carrito.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';
import 'banner_mensaje_dialogo.dart';
import 'teclado_numerico_simple.dart';

/// Resultado del dialogo de cantidad.
class ResultadoDialogoCantidad {
	const ResultadoDialogoCantidad({
		required this.confirmado,
		required this.cantidad,
	});

	final bool confirmado;
	final double cantidad;
}

/// Muestra dialogo para capturar cantidad con decimales.
class DialogoCantidadProducto extends StatefulWidget {
	const DialogoCantidadProducto({
		required this.producto,
		this.etiquetaUnidad,
		super.key,
	});

	final Producto producto;
	final String? etiquetaUnidad;

	static Future<ResultadoDialogoCantidad> mostrar(
		BuildContext context,
		Producto producto, {
		String? etiquetaUnidad,
	}) async {
		final resultado = await showDialog<ResultadoDialogoCantidad>(
			context: context,
			builder: (_) => DialogoCantidadProducto(
				producto: producto,
				etiquetaUnidad: etiquetaUnidad,
			),
		);
		return resultado ?? const ResultadoDialogoCantidad(confirmado: false, cantidad: 0.0);
	}

	@override
	State<DialogoCantidadProducto> createState() => _DialogoCantidadProductoState();
}

class _DialogoCantidadProductoState extends State<DialogoCantidadProducto> {
	final _cantidadController = TextEditingController(text: '1');
	late final FocusNode _cantidadFocus;
	String _valorCantidad = '1';
	var _cerrado = false;
	String? _mensajeError;

	@override
	void initState() {
		super.initState();
		_cantidadFocus = FocusNode(onKeyEvent: _manejarTeclaCantidad);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted && _cantidadFocus.canRequestFocus) {
				_cantidadFocus.requestFocus();
				_cantidadController.selection = TextSelection(
					baseOffset: 0,
					extentOffset: _cantidadController.text.length,
				);
			}
		});
	}

	@override
	void dispose() {
		_cantidadController.dispose();
		_cantidadFocus.dispose();
		super.dispose();
	}

	KeyEventResult _manejarTeclaCantidad(FocusNode node, KeyEvent event) {
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
		final unidad = widget.etiquetaUnidad ??
			_etiquetaUnidad(widget.producto.unidadMedida);
		final subtotal = (double.tryParse(_valorCantidad) ?? 0.0) * widget.producto.precioBase;
		return AlertDialog(
			title: Row(
				children: [
					const Icon(Icons.add_shopping_cart, color: PosiaColors.cobrar, size: 32.0),
					const SizedBox(width: 8.0),
					Expanded(child: Text(widget.producto.nombre)),
				],
			),
			content: SizedBox(
				width: 320.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Text(
							'${formatearMoneda(widget.producto.precioBase)} / $unidad',
							style: Theme.of(context).textTheme.titleMedium?.copyWith(
								color: PosiaColors.cobrar,
								fontWeight: FontWeight.w600,
							),
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: _cantidadController,
							focusNode: _cantidadFocus,
							autofocus: true,
							// Se suprime el teclado del sistema en móvil porque el
							// diálogo ya muestra un TecladoNumericoSimple embebido.
							// El teclado físico en escritorio sigue funcionando.
							keyboardType: TextInputType.none,
							showCursor: true,
							textInputAction: TextInputAction.done,
							decoration: InputDecoration(
								labelText: 'Cantidad',
								suffixText: unidad,
								hintText: '1',
								border: const OutlineInputBorder(),
								helperText: 'Enter agrega · Esc cancela',
							),
							onChanged: (texto) {
								_limpiarError();
								_establecerValor(_normalizarEntradaCantidad(texto));
							},
						),
						if (subtotal > 0.0) ...[
							const SizedBox(height: 8.0),
							Text(
								'Subtotal: ${formatearMoneda(subtotal)}',
								style: Theme.of(context).textTheme.bodyLarge?.copyWith(
									fontWeight: FontWeight.w600,
								),
							),
						],
						if (_mensajeError != null)
							BannerMensajeDialogo(
								mensaje: _mensajeError!,
								padding: const EdgeInsets.only(top: 8.0),
							),
						const SizedBox(height: 8.0),
						TecladoNumericoSimple(
							valorActual: _valorCantidad,
							mostrarValor: false,
							alPresionarTecla: (tecla) {
								_limpiarError();
								_agregarTecla(tecla);
							},
							alBorrar: () {
								_limpiarError();
								_borrarTecla();
							},
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

	String _etiquetaUnidad(UnidadMedida unidad) {
		return switch (unidad) {
			UnidadMedida.pieza => 'pza',
			UnidadMedida.kilogramo => 'kg',
			UnidadMedida.litro => 'L',
			UnidadMedida.caja => 'caja',
		};
	}

	void _establecerValor(String valor) {
		setState(() => _valorCantidad = valor);
		if (_cantidadController.text == valor) {
			return;
		}
		_cantidadController.value = TextEditingValue(
			text: valor,
			selection: TextSelection.collapsed(offset: valor.length),
		);
	}

	String _normalizarEntradaCantidad(String raw) {
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
		if (tecla == '.' && _valorCantidad.contains('.')) {
			return;
		}
		_establecerValor(_valorCantidad + tecla);
	}

	void _borrarTecla() {
		if (_valorCantidad.isEmpty) {
			return;
		}
		_establecerValor(_valorCantidad.substring(0, _valorCantidad.length - 1));
	}

	void _cancelar() {
		if (_cerrado || !mounted) {
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			const ResultadoDialogoCantidad(confirmado: false, cantidad: 0.0),
		);
	}

	void _confirmar() {
		if (_cerrado || !mounted) {
			return;
		}
		final cantidad = double.tryParse(_valorCantidad.isEmpty ? '0' : _valorCantidad) ?? 0.0;
		if (cantidad <= 0.0) {
			_mostrarError('Indique una cantidad mayor a cero');
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			ResultadoDialogoCantidad(confirmado: true, cantidad: cantidad),
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
