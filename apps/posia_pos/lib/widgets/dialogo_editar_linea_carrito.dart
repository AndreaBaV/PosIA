/// Dialogo para editar cantidad, precio y descuento de una linea en caja.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';

/// Resultado de edicion de linea en carrito.
class ResultadoEditarLineaCarrito {
	const ResultadoEditarLineaCarrito({
		required this.confirmado,
		this.cantidad,
		this.precioUnitario,
		this.descuentoLinea,
		this.quitarDescuentoLinea = false,
	});

	final bool confirmado;
	final double? cantidad;
	final double? precioUnitario;
	final double? descuentoLinea;
	final bool quitarDescuentoLinea;
}

enum _CampoActivoEditarLinea { cantidad, precio, descuento }

/// Captura cantidad, precio (admin) y descuento opcional en linea.
class DialogoEditarLineaCarrito extends StatefulWidget {
	const DialogoEditarLineaCarrito({
		required this.linea,
		required this.puedeEditarPrecio,
		required this.puedeDescuentoLinea,
		super.key,
	});

	final LineaCarrito linea;
	final bool puedeEditarPrecio;
	final bool puedeDescuentoLinea;

	static Future<ResultadoEditarLineaCarrito> mostrar({
		required BuildContext context,
		required LineaCarrito linea,
		required bool puedeEditarPrecio,
		required bool puedeDescuentoLinea,
	}) {
		return showDialog<ResultadoEditarLineaCarrito>(
			context: context,
			builder: (_) => DialogoEditarLineaCarrito(
				linea: linea,
				puedeEditarPrecio: puedeEditarPrecio,
				puedeDescuentoLinea: puedeDescuentoLinea,
			),
		).then(
			(r) => r ?? const ResultadoEditarLineaCarrito(confirmado: false),
		);
	}

	@override
	State<DialogoEditarLineaCarrito> createState() =>
		_DialogoEditarLineaCarritoState();
}

class _DialogoEditarLineaCarritoState extends State<DialogoEditarLineaCarrito> {
	late final TextEditingController _cantidadCtrl;
	late final TextEditingController _precioCtrl;
	late final TextEditingController _descuentoCtrl;
	late final FocusNode _cantidadFocus;
	late final FocusNode _precioFocus;
	late final FocusNode _descuentoFocus;
	var _campoActivo = _CampoActivoEditarLinea.cantidad;
	var _cerrado = false;
	String? _mensajeError;

	@override
	void initState() {
		super.initState();
		final linea = widget.linea;
		_cantidadCtrl = TextEditingController(
			text: _formatearCantidad(linea.cantidad),
		);
		_precioCtrl = TextEditingController(
			text: linea.precioUnitario.toStringAsFixed(2),
		);
		_descuentoCtrl = TextEditingController(
			text: linea.descuentoLinea > 0.0
				? linea.descuentoLinea.toStringAsFixed(2)
				: '',
		);
		_cantidadFocus = FocusNode(onKeyEvent: _manejarTecla);
		_precioFocus = FocusNode(onKeyEvent: _manejarTecla);
		_descuentoFocus = FocusNode(onKeyEvent: _manejarTecla);
	}

	@override
	void dispose() {
		_cantidadCtrl.dispose();
		_precioCtrl.dispose();
		_descuentoCtrl.dispose();
		_cantidadFocus.dispose();
		_precioFocus.dispose();
		_descuentoFocus.dispose();
		super.dispose();
	}

	String _formatearCantidad(double cantidad) {
		if (cantidad == cantidad.roundToDouble()) {
			return cantidad.toStringAsFixed(0);
		}
		return cantidad.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
	}

	String _etiquetaUnidad() {
		return switch (widget.linea.producto.unidadMedida) {
			UnidadMedida.pieza => 'pza',
			UnidadMedida.kilogramo => 'kg',
			UnidadMedida.litro => 'L',
			UnidadMedida.caja => 'caja',
		};
	}

	TextEditingController _ctrlActivo() => switch (_campoActivo) {
		_CampoActivoEditarLinea.cantidad => _cantidadCtrl,
		_CampoActivoEditarLinea.precio => _precioCtrl,
		_CampoActivoEditarLinea.descuento => _descuentoCtrl,
	};

	FocusNode _focoActivo() => switch (_campoActivo) {
		_CampoActivoEditarLinea.cantidad => _cantidadFocus,
		_CampoActivoEditarLinea.precio => _precioFocus,
		_CampoActivoEditarLinea.descuento => _descuentoFocus,
	};

	KeyEventResult _manejarTecla(FocusNode node, KeyEvent event) {
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

	void _seleccionarCampo(_CampoActivoEditarLinea campo) {
		setState(() => _campoActivo = campo);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			final foco = _focoActivo();
			if (foco.canRequestFocus) {
				foco.requestFocus();
			}
		});
	}

	void _alPresionarTecla(String tecla) {
		_limpiarError();
		final ctrl = _ctrlActivo();
		var texto = ctrl.text;
		if (tecla == '.') {
			if (texto.contains('.')) {
				return;
			}
			texto = texto.isEmpty ? '0.' : '$texto.';
		} else {
			texto = texto == '0' ? tecla : '$texto$tecla';
		}
		ctrl.text = texto;
		ctrl.selection = TextSelection.collapsed(offset: texto.length);
		setState(() {});
	}

	void _alBorrar() {
		_limpiarError();
		final ctrl = _ctrlActivo();
		final texto = ctrl.text;
		if (texto.isEmpty) {
			return;
		}
		final nuevo = texto.substring(0, texto.length - 1);
		ctrl.text = nuevo;
		ctrl.selection = TextSelection.collapsed(offset: nuevo.length);
		setState(() {});
	}

	void _limpiarError() {
		if (_mensajeError == null) {
			return;
		}
		setState(() => _mensajeError = null);
	}

	void _mostrarError(String mensaje) {
		if (!mounted) {
			return;
		}
		setState(() => _mensajeError = mensaje);
	}

	void _cancelar() {
		if (_cerrado) {
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			const ResultadoEditarLineaCarrito(confirmado: false),
		);
	}

	void _confirmar() {
		if (_cerrado) {
			return;
		}
		final cantidad = double.tryParse(_cantidadCtrl.text.trim().replaceAll(',', '.'));
		if (cantidad == null || cantidad <= 0.0) {
			_mostrarError('Indique una cantidad válida');
			return;
		}

		double? precioNuevo;
		if (widget.puedeEditarPrecio) {
			precioNuevo = parsearPrecioTexto(_precioCtrl.text);
			if (precioNuevo == null || precioNuevo <= 0.0) {
				_mostrarError('Indique un precio válido');
				return;
			}
			precioNuevo = redondearMonto(precioNuevo);
			final linea = widget.linea;
			final costo = linea.producto.costoUnitario;
			final String? errorPrecio;
			if (linea.factorABase > 1.0) {
				errorPrecio = precioPresentacionEsValido(
					precioNuevo,
					costo,
					linea.factorABase,
				)
					? null
					: mensajePrecioMinimoPresentacionInvalido(costo, linea.factorABase);
			} else {
				errorPrecio = precioVentaEsValido(precioNuevo, costo)
					? null
					: mensajePrecioMinimoInvalido(costo);
			}
			if (errorPrecio != null) {
				_mostrarError(errorPrecio);
				return;
			}
		}

		double? descuentoNuevo;
		var quitarDescuento = false;
		if (widget.puedeDescuentoLinea) {
			final textoDesc = _descuentoCtrl.text.trim();
			if (textoDesc.isEmpty) {
				if (widget.linea.descuentoLinea > 0.0) {
					quitarDescuento = true;
				}
			} else {
				descuentoNuevo = parsearPrecioTexto(textoDesc);
				if (descuentoNuevo == null || descuentoNuevo < 0.0) {
					_mostrarError('Indique un descuento válido');
					return;
				}
				descuentoNuevo = redondearMonto(descuentoNuevo);
				var lineaPrueba = widget.linea.copiarCon(
					cantidad: cantidad,
					precioUnitario: precioNuevo ?? widget.linea.precioUnitario,
					descuentoLinea: descuentoNuevo,
				);
				if (precioNuevo != null) {
					lineaPrueba = lineaPrueba.copiarCon(
						reglaPrecio: ReglaPrecio.precioManual,
					);
				}
				final error = errorDescuentoLinea(lineaPrueba, descuentoNuevo);
				if (error != null) {
					_mostrarError(error);
					return;
				}
			}
		}

		_cerrado = true;
		Navigator.of(context).pop(
			ResultadoEditarLineaCarrito(
				confirmado: true,
				cantidad: cantidad,
				precioUnitario: precioNuevo,
				descuentoLinea: descuentoNuevo,
				quitarDescuentoLinea: quitarDescuento,
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final linea = widget.linea;
		final minimo = calcularPrecioMinimoUnitarioLinea(linea);
		final maxDescuento = calcularDescuentoMaximoLinea(linea);
		return AlertDialog(
			title: Text(linea.producto.nombre),
			content: SizedBox(
				width: 360.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						const SizedBox(height: 4.0),
						TextField(
							controller: _cantidadCtrl,
							focusNode: _cantidadFocus,
							keyboardType: TextInputType.none,
							decoration: InputDecoration(
								labelText: 'Cantidad',
								suffixText: _etiquetaUnidad(),
								border: const OutlineInputBorder(),
							),
							onTap: () => _seleccionarCampo(_CampoActivoEditarLinea.cantidad),
						),
						const SizedBox(height: 10.0),
						TextField(
							controller: _precioCtrl,
							focusNode: _precioFocus,
							readOnly: !widget.puedeEditarPrecio,
							keyboardType: TextInputType.none,
							decoration: InputDecoration(
								labelText: 'Precio unitario',
								suffixText: widget.puedeEditarPrecio ? null : 'Solo admin',
								helperText: widget.puedeEditarPrecio
									? 'Mínimo: ${formatearMoneda(minimo)}'
									: formatearMoneda(linea.precioUnitario),
								border: const OutlineInputBorder(),
							),
							onTap: widget.puedeEditarPrecio
								? () => _seleccionarCampo(_CampoActivoEditarLinea.precio)
								: null,
						),
						if (widget.puedeDescuentoLinea) ...[
							const SizedBox(height: 10.0),
							TextField(
								controller: _descuentoCtrl,
								focusNode: _descuentoFocus,
								keyboardType: TextInputType.none,
								decoration: InputDecoration(
									labelText: 'Descuento en producto',
									helperText: 'Máximo: ${formatearMoneda(maxDescuento)}',
									border: const OutlineInputBorder(),
								),
								onTap: () =>
									_seleccionarCampo(_CampoActivoEditarLinea.descuento),
							),
						],
						const SizedBox(height: 12.0),
						TecladoNumericoSimple(
							valorActual: _ctrlActivo().text,
							mostrarValor: false,
							alPresionarTecla: _alPresionarTecla,
							alBorrar: _alBorrar,
						),
						if (_mensajeError != null) ...[
							const SizedBox(height: 8.0),
							BannerMensajeDialogo(mensaje: _mensajeError!),
						],
					],
				),
			),
			actions: [
				TextButton(onPressed: _cancelar, child: const Text('Cancelar')),
				FilledButton(onPressed: _confirmar, child: const Text('Guardar')),
			],
		);
	}
}
