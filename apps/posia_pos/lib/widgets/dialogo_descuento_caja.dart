/// Dialogo para capturar descuento manual en caja.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';

/// Resultado del dialogo de descuento en caja.
class ResultadoDialogoDescuento {
	const ResultadoDialogoDescuento({
		required this.confirmado,
		this.quitar = false,
		this.esPorcentaje = false,
		this.valor = 0.0,
	});

	final bool confirmado;
	final bool quitar;
	final bool esPorcentaje;
	final double valor;
}

/// Muestra dialogo para aplicar descuento a linea o ticket.
class DialogoDescuentoCaja extends StatefulWidget {
	const DialogoDescuentoCaja({
		required this.titulo,
		required this.subtitulo,
		required this.descuentoActual,
		required this.descuentoMaximo,
		this.precioMinimoUnitario,
		this.linea,
		this.lineasTicket = const [],
		super.key,
	});

	final String titulo;
	final String subtitulo;
	final double descuentoActual;
	final double descuentoMaximo;
	final double? precioMinimoUnitario;
	final LineaCarrito? linea;
	final List<LineaCarrito> lineasTicket;

	static Future<ResultadoDialogoDescuento> mostrarLinea({
		required BuildContext context,
		required LineaCarrito linea,
	}) {
		return showDialog<ResultadoDialogoDescuento>(
			context: context,
			builder: (_) => DialogoDescuentoCaja(
				titulo: 'Descuento en producto',
				subtitulo: linea.producto.nombre,
				descuentoActual: linea.descuentoLinea,
				descuentoMaximo: calcularDescuentoMaximoLinea(linea),
				precioMinimoUnitario: calcularPrecioMinimoUnitarioLinea(linea),
				linea: linea,
			),
		).then(
			(r) => r ?? const ResultadoDialogoDescuento(confirmado: false),
		);
	}

	static Future<ResultadoDialogoDescuento> mostrarTicket({
		required BuildContext context,
		required List<LineaCarrito> lineas,
		required double descuentoActual,
	}) {
		return showDialog<ResultadoDialogoDescuento>(
			context: context,
			builder: (_) => DialogoDescuentoCaja(
				titulo: 'Descuento en nota',
				subtitulo: 'Aplica al total del carrito',
				descuentoActual: descuentoActual,
				descuentoMaximo: calcularDescuentoMaximoTicket(lineas),
				lineasTicket: lineas,
			),
		).then(
			(r) => r ?? const ResultadoDialogoDescuento(confirmado: false),
		);
	}

	@override
	State<DialogoDescuentoCaja> createState() => _DialogoDescuentoCajaState();
}

class _DialogoDescuentoCajaState extends State<DialogoDescuentoCaja> {
	final _valorController = TextEditingController();
	late final FocusNode _valorFocus;
	var _esPorcentaje = false;
	var _cerrado = false;
	String? _mensajeError;

	@override
	void initState() {
		super.initState();
		_valorFocus = FocusNode(onKeyEvent: _manejarTecla);
		if (widget.descuentoActual > 0.0) {
			_valorController.text = widget.descuentoActual.toStringAsFixed(2);
		}
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted && _valorFocus.canRequestFocus) {
				_valorFocus.requestFocus();
				if (_valorController.text.isNotEmpty) {
					_valorController.selection = TextSelection(
						baseOffset: 0,
						extentOffset: _valorController.text.length,
					);
				}
			}
		});
	}

	@override
	void dispose() {
		_valorController.dispose();
		_valorFocus.dispose();
		super.dispose();
	}

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

	double? _parsearValor() {
		return parsearPrecioTexto(_valorController.text);
	}

	String? _validarDescuento(double descuentoMonto) {
		if (widget.linea != null) {
			return errorDescuentoLinea(widget.linea!, descuentoMonto);
		}
		return errorDescuentoTicket(widget.lineasTicket, descuentoMonto);
	}

	double _calcularMontoDesdeEntrada(double valor) {
		if (!_esPorcentaje) {
			return redondearMonto(valor);
		}
		if (widget.linea != null) {
			return calcularDescuentoLineaDesdePorcentaje(widget.linea!, valor);
		}
		return calcularDescuentoTicketDesdePorcentaje(widget.lineasTicket, valor);
	}

	void _confirmar() {
		if (_cerrado) {
			return;
		}
		final valor = _parsearValor();
		if (valor == null || valor <= 0.0) {
			_mostrarError('Ingrese un valor válido');
			return;
		}
		if (_esPorcentaje && valor > 100.0) {
			_mostrarError('El porcentaje no puede superar 100%');
			return;
		}
		final monto = _calcularMontoDesdeEntrada(valor);
		final error = _validarDescuento(monto);
		if (error != null) {
			_mostrarError(error);
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			ResultadoDialogoDescuento(
				confirmado: true,
				esPorcentaje: _esPorcentaje,
				valor: valor,
			),
		);
	}

	void _quitar() {
		if (_cerrado) {
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			const ResultadoDialogoDescuento(confirmado: true, quitar: true),
		);
	}

	void _cancelar() {
		if (_cerrado) {
			return;
		}
		_cerrado = true;
		Navigator.of(context).pop(
			const ResultadoDialogoDescuento(confirmado: false),
		);
	}

	@override
	Widget build(BuildContext context) {
		final puedeDescontar = widget.descuentoMaximo > 0.0;
		return AlertDialog(
			title: Text(widget.titulo),
			content: SizedBox(
				width: 360.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							widget.subtitulo,
							style: Theme.of(context).textTheme.bodyMedium,
						),
						const SizedBox(height: 8.0),
						if (widget.precioMinimoUnitario != null)
							Text(
								'Precio mínimo: ${formatearMoneda(widget.precioMinimoUnitario!)}',
								style: TextStyle(
									fontSize: 13.0,
									color: Colors.grey.shade700,
								),
							),
						Text(
							'Descuento máximo: ${formatearMoneda(widget.descuentoMaximo)}',
							style: TextStyle(
								fontSize: 13.0,
								color: puedeDescontar
									? Colors.grey.shade700
									: PosiaColors.cancelar,
							),
						),
						if (widget.descuentoActual > 0.0) ...[
							const SizedBox(height: 4.0),
							Text(
								'Descuento actual: ${formatearMoneda(widget.descuentoActual)}',
								style: const TextStyle(
									fontWeight: FontWeight.w600,
									color: PosiaColors.cobrar,
								),
							),
						],
						const SizedBox(height: 12.0),
						SegmentedButton<bool>(
							segments: const [
								ButtonSegment(value: false, label: Text('Monto \$')),
								ButtonSegment(value: true, label: Text('Porcentaje %')),
							],
							selected: {_esPorcentaje},
							onSelectionChanged: puedeDescontar
								? (seleccion) {
									setState(() {
										_esPorcentaje = seleccion.first;
										_mensajeError = null;
									});
								}
								: null,
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: _valorController,
							focusNode: _valorFocus,
							enabled: puedeDescontar,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							decoration: InputDecoration(
								labelText: _esPorcentaje ? 'Porcentaje' : 'Monto de descuento',
								suffixText: _esPorcentaje ? '%' : null,
								border: const OutlineInputBorder(),
							),
							onChanged: (_) => _limpiarError(),
						),
						if (_mensajeError != null) ...[
							const SizedBox(height: 8.0),
							BannerMensajeDialogo(
								mensaje: _mensajeError!,
							),
						],
					],
				),
			),
			actions: [
				if (widget.descuentoActual > 0.0)
					TextButton(
						onPressed: _quitar,
						child: const Text('Quitar descuento'),
					),
				TextButton(
					onPressed: _cancelar,
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: puedeDescontar ? _confirmar : null,
					child: const Text('Aplicar'),
				),
			],
		);
	}
}
