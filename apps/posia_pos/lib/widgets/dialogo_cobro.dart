/// Dialogo de cobro con multipago, credito y cambio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

/// Muestra dialogo de cobro y retorna [CobroRequest] o null si cancela.
Future<CobroRequest?> mostrarDialogoCobro({
	required BuildContext context,
	required double subtotal,
	Cliente? cliente,
}) async {
	return showDialog<CobroRequest>(
		context: context,
		barrierDismissible: false,
		useRootNavigator: true,
		builder: (ctx) => _DialogoCobro(
			subtotal: subtotal,
			cliente: cliente,
		),
	);
}

enum _CampoMontoCobro { recibido, efectivoMixto, tarjetaMixto, diasCredito }

class _DialogoCobro extends StatefulWidget {
	const _DialogoCobro({
		required this.subtotal,
		this.cliente,
	});

	final double subtotal;
	final Cliente? cliente;

	@override
	State<_DialogoCobro> createState() => _DialogoCobroState();
}

class _DialogoCobroState extends State<_DialogoCobro> {
	MetodoPago _metodo = MetodoPago.efectivo;
	final _recibidoCtrl = TextEditingController();
	final _efectivoCtrl = TextEditingController();
	final _tarjetaCtrl = TextEditingController();
	final _diasCreditoCtrl = TextEditingController();
	final _recibidoFocus = FocusNode(debugLabel: 'cobro-recibido');
	final _efectivoFocus = FocusNode(debugLabel: 'cobro-efectivo-mixto');
	final _tarjetaFocus = FocusNode(debugLabel: 'cobro-tarjeta-mixto');
	final _diasCreditoFocus = FocusNode(debugLabel: 'cobro-dias-credito');
	late final FocusNode _atajosFocus;
	var _aceptaCredito = false;
	var _cerrado = false;
	_CampoMontoCobro _campoMontoActivo = _CampoMontoCobro.recibido;

	@override
	void initState() {
		super.initState();
		_diasCreditoCtrl.text = (widget.cliente?.diasCredito ?? DIAS_CREDITO_PREDETERMINADO)
			.toString();
		_atajosFocus = FocusNode(
			debugLabel: 'cobro-atajos',
			onKeyEvent: _manejarAtajoTeclado,
			skipTraversal: true,
			canRequestFocus: false,
		);
		_recibidoFocus.addListener(() {
			if (_recibidoFocus.hasFocus) {
				_actualizarCampoActivo(_CampoMontoCobro.recibido);
			}
		});
		_efectivoFocus.addListener(() {
			if (_efectivoFocus.hasFocus) {
				_actualizarCampoActivo(_CampoMontoCobro.efectivoMixto);
			}
		});
		_tarjetaFocus.addListener(() {
			if (_tarjetaFocus.hasFocus) {
				_actualizarCampoActivo(_CampoMontoCobro.tarjetaMixto);
			}
		});
		_diasCreditoFocus.addListener(() {
			if (_diasCreditoFocus.hasFocus) {
				_actualizarCampoActivo(_CampoMontoCobro.diasCredito);
			}
		});
		WidgetsBinding.instance.addPostFrameCallback((_) => _enfocarCampoActivo());
	}

	@override
	void dispose() {
		_atajosFocus.dispose();
		_recibidoFocus.dispose();
		_efectivoFocus.dispose();
		_tarjetaFocus.dispose();
		_diasCreditoFocus.dispose();
		_recibidoCtrl.dispose();
		_efectivoCtrl.dispose();
		_tarjetaCtrl.dispose();
		_diasCreditoCtrl.dispose();
		super.dispose();
	}

	void _actualizarCampoActivo(_CampoMontoCobro campo) {
		if (_campoMontoActivo == campo) {
			return;
		}
		setState(() => _campoMontoActivo = campo);
	}

	FocusNode _focoDelCampo(_CampoMontoCobro campo) => switch (campo) {
		_CampoMontoCobro.recibido => _recibidoFocus,
		_CampoMontoCobro.efectivoMixto => _efectivoFocus,
		_CampoMontoCobro.tarjetaMixto => _tarjetaFocus,
		_CampoMontoCobro.diasCredito => _diasCreditoFocus,
	};

	void _enfocarCampoActivo() {
		if (!mounted || _cerrado) {
			return;
		}
		final foco = _focoDelCampo(_campoMontoActivo);
		if (foco.canRequestFocus) {
			foco.requestFocus();
		}
	}

	void _seleccionarMetodo(MetodoPago metodo) {
		setState(() {
			_metodo = metodo;
			if (metodo != MetodoPago.credito) {
				_aceptaCredito = false;
			}
			_campoMontoActivo = switch (metodo) {
				MetodoPago.mixto => _CampoMontoCobro.efectivoMixto,
				MetodoPago.credito => _CampoMontoCobro.diasCredito,
				_ => _CampoMontoCobro.recibido,
			};
		});
		WidgetsBinding.instance.addPostFrameCallback((_) => _enfocarCampoActivo());
	}

	bool get _creditoDisponible =>
		widget.cliente != null && clientePuedeRecibirCredito(widget.cliente!);

	bool get _creditoRequiereDatos =>
		widget.cliente != null &&
		widget.cliente!.creditoHabilitado &&
		!clienteTieneDatosCredito(widget.cliente!);

	double get _total => redondearMonto(widget.subtotal);

	int get _diasCredito =>
		int.tryParse(_diasCreditoCtrl.text.trim()) ??
		widget.cliente?.diasCredito ??
		DIAS_CREDITO_PREDETERMINADO;

	DateTime? get _fechaVencimientoCredito {
		if (_metodo != MetodoPago.credito || widget.cliente == null) {
			return null;
		}
		return calcularFechaVencimientoCredito(DateTime.now().toUtc(), _diasCredito);
	}

	double? get _cambio {
		if (_metodo != MetodoPago.efectivo) {
			return null;
		}
		final recibido = double.tryParse(_recibidoCtrl.text);
		if (recibido == null) {
			return null;
		}
		return recibido - _total;
	}

	bool get _capturaMontoActiva => switch (_metodo) {
		MetodoPago.efectivo || MetodoPago.mixto || MetodoPago.credito => true,
		_ => false,
	};

	bool get _campoActivoAceptaDecimal =>
		_campoMontoActivo != _CampoMontoCobro.diasCredito;

	TextEditingController get _controladorCampoActivo => switch (_campoMontoActivo) {
		_CampoMontoCobro.recibido => _recibidoCtrl,
		_CampoMontoCobro.efectivoMixto => _efectivoCtrl,
		_CampoMontoCobro.tarjetaMixto => _tarjetaCtrl,
		_CampoMontoCobro.diasCredito => _diasCreditoCtrl,
	};

	KeyEventResult _manejarAtajoTeclado(FocusNode node, KeyEvent event) {
		if (_cerrado || event is! KeyDownEvent) {
			return KeyEventResult.ignored;
		}
		if (event.logicalKey == LogicalKeyboardKey.escape) {
			_cancelar();
			return KeyEventResult.handled;
		}
		return KeyEventResult.ignored;
	}

	void _agregarTeclaTouchpad(String tecla) {
		if (!_capturaMontoActiva) {
			return;
		}
		final ctrl = _controladorCampoActivo;
		if (tecla == '.') {
			if (!_campoActivoAceptaDecimal || ctrl.text.contains('.')) {
				return;
			}
		}
		final valor = _normalizarEntradaMonto(
			ctrl.text + tecla,
			admiteDecimal: _campoActivoAceptaDecimal,
		);
		_establecerValorCampo(ctrl, valor);
	}

	void _borrarTeclaTouchpad() {
		if (!_capturaMontoActiva) {
			return;
		}
		final ctrl = _controladorCampoActivo;
		final valor = ctrl.text;
		if (valor.isEmpty) {
			return;
		}
		_establecerValorCampo(ctrl, valor.substring(0, valor.length - 1));
	}

	void _establecerValorCampo(TextEditingController ctrl, String valor) {
		if (ctrl.text == valor) {
			setState(() {});
			return;
		}
		ctrl.value = TextEditingValue(
			text: valor,
			selection: TextSelection.collapsed(offset: valor.length),
		);
		setState(() {});
		_enfocarCampoActivo();
	}

	String _normalizarEntradaMonto(String raw, {bool admiteDecimal = true}) {
		final texto = raw.replaceAll(',', '.');
		final buffer = StringBuffer();
		var puntoVisto = false;
		for (final caracter in texto.split('')) {
			if (caracter == '.') {
				if (!admiteDecimal || puntoVisto) {
					continue;
				}
				puntoVisto = true;
				buffer.write(caracter);
			} else if (RegExp(r'\d').hasMatch(caracter)) {
				buffer.write(caracter);
			}
		}
		return buffer.toString();
	}

	@override
	Widget build(BuildContext context) {
		final leyendaCredito = _metodo == MetodoPago.credito &&
			widget.cliente != null &&
			_fechaVencimientoCredito != null
			? generarLeyendaCompromisoCredito(
				total: _total,
				diasCredito: _diasCredito,
				fechaVencimiento: _fechaVencimientoCredito!,
				nombreCliente: widget.cliente!.nombre,
			)
			: null;

		return PopScope(
			canPop: !_cerrado,
			child: Focus(
				focusNode: _atajosFocus,
				child: AlertDialog(
				title: const Text('Cobrar venta'),
				content: SizedBox(
					width: 420.0,
					child: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text(
									formatearMoneda(_total),
									style: Theme.of(context).textTheme.headlineMedium?.copyWith(
										color: PosiaColors.cobrar,
										fontWeight: FontWeight.bold,
									),
									textAlign: TextAlign.center,
								),
								Text(
									'Subtotal ${formatearMoneda(widget.subtotal)}',
									textAlign: TextAlign.center,
									style: const TextStyle(color: Colors.grey),
								),
								if (widget.cliente != null) ...[
									const SizedBox(height: 8.0),
									Text(
										'Cliente: ${widget.cliente!.nombre}',
										textAlign: TextAlign.center,
									),
								],
								const SizedBox(height: 8.0),
								Text(
									_capturaMontoActiva
										? 'Escriba el monto · Enter cobra · Esc cancela'
										: 'Enter confirma el cobro · Esc cancela',
									textAlign: TextAlign.center,
									style: TextStyle(fontSize: 12.0, color: Colors.grey.shade700),
								),
								const SizedBox(height: 12.0),
								const Text('Forma de pago', style: TextStyle(fontWeight: FontWeight.w600)),
								const SizedBox(height: 8.0),
								Wrap(
									spacing: 8.0,
									runSpacing: 8.0,
									children: [
										_metodoChip(MetodoPago.efectivo, 'Efectivo', Icons.payments),
										_metodoChip(MetodoPago.tarjeta, 'Tarjeta', Icons.credit_card),
										_metodoChip(
											MetodoPago.transferencia,
											'Transferencia',
											Icons.account_balance,
										),
										_metodoChip(MetodoPago.mixto, 'Mixto', Icons.call_split),
										if (_creditoDisponible)
											_metodoChip(MetodoPago.credito, 'Crédito', Icons.handshake),
									],
								),
								if (widget.cliente == null)
									const Padding(
										padding: EdgeInsets.only(top: 8.0),
										child: Text(
											'Seleccione un cliente para venta a crédito.',
											style: TextStyle(color: Colors.grey, fontSize: 12.0),
										),
									),
								if (_creditoRequiereDatos)
									Padding(
										padding: const EdgeInsets.only(top: 8.0),
										child: Text(
											'Faltan datos: ${camposFaltantesCredito(widget.cliente!).join(', ')}. '
											'Complete la ficha del cliente.',
											style: const TextStyle(
												color: PosiaColors.cancelar,
												fontSize: 12.0,
											),
										),
									),
								if (_metodo == MetodoPago.credito && _creditoDisponible) ...[
									const SizedBox(height: 12.0),
									_campoMontoEditable(
										controlador: _diasCreditoCtrl,
										foco: _diasCreditoFocus,
										etiqueta: 'Días para pagar',
										sufijo: 'días',
										hint: '30',
										aceptaDecimales: false,
										alPresionarSubmit: _confirmar,
									),
									if (leyendaCredito != null) ...[
										const SizedBox(height: 8.0),
										Card(
											color: Colors.amber.shade50,
											child: Padding(
												padding: const EdgeInsets.all(10.0),
												child: Text(
													leyendaCredito,
													style: const TextStyle(fontSize: 12.0),
												),
											),
										),
									],
									CheckboxListTile(
										contentPadding: EdgeInsets.zero,
										title: const Text(
											'El cliente acepta pagar en el plazo indicado',
											style: TextStyle(fontSize: 13.0),
										),
										value: _aceptaCredito,
										onChanged: (v) => setState(() => _aceptaCredito = v ?? false),
									),
									const Text(
										'Se imprimiran 2 pagares (administrador y cliente) con espacio para firma.',
										style: TextStyle(color: Colors.grey, fontSize: 11.0),
									),
								],
								if (_metodo == MetodoPago.efectivo) ...[
									const SizedBox(height: 12.0),
									_campoMontoEditable(
										controlador: _recibidoCtrl,
										foco: _recibidoFocus,
										etiqueta: r'Recibido ($)',
										hint: '0.00',
										alPresionarSubmit: _confirmar,
									),
									if (_cambio != null && _cambio! >= 0)
										Padding(
											padding: const EdgeInsets.only(top: 8.0),
											child: Text(
												'Cambio: ${formatearMoneda(_cambio!)}',
												style: const TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 16.0,
												),
											),
										),
								],
								if (_metodo == MetodoPago.mixto) ...[
									const SizedBox(height: 12.0),
									_campoMontoEditable(
										controlador: _efectivoCtrl,
										foco: _efectivoFocus,
										etiqueta: r'Efectivo ($)',
										hint: '0.00',
										alPresionarSubmit: () => _tarjetaFocus.requestFocus(),
									),
									const SizedBox(height: 8.0),
									_campoMontoEditable(
										controlador: _tarjetaCtrl,
										foco: _tarjetaFocus,
										etiqueta: r'Tarjeta ($)',
										hint: '0.00',
										alPresionarSubmit: _confirmar,
									),
									const SizedBox(height: 4.0),
									const Text(
										'Toque cada campo para editarlo · Tab alterna con teclado físico',
										style: TextStyle(color: Colors.grey, fontSize: 11.0),
									),
								],
								if (_capturaMontoActiva) ...[
									const SizedBox(height: 12.0),
									Align(
										alignment: Alignment.center,
										child: TecladoNumericoSimple(
											valorActual: _controladorCampoActivo.text,
											mostrarValor: false,
											alPresionarTecla: _agregarTeclaTouchpad,
											alBorrar: _borrarTeclaTouchpad,
										),
									),
								],
							],
						),
					),
				),
				actions: [
					TextButton(
						onPressed: _cancelar,
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: _confirmar,
						style: FilledButton.styleFrom(backgroundColor: PosiaColors.cobrar),
						child: const Text('COBRAR (Enter)'),
					),
				],
			),
		),
		);
	}

	Widget _campoMontoEditable({
		required TextEditingController controlador,
		required FocusNode foco,
		required String etiqueta,
		required VoidCallback alPresionarSubmit,
		String? sufijo,
		String? hint,
		bool aceptaDecimales = true,
	}) {
		return TextField(
			controller: controlador,
			focusNode: foco,
			keyboardType: TextInputType.numberWithOptions(decimal: aceptaDecimales),
			textInputAction: TextInputAction.done,
			inputFormatters: [
				FilteringTextInputFormatter.allow(
					aceptaDecimales ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
				),
			],
			decoration: InputDecoration(
				labelText: etiqueta,
				suffixText: sufijo,
				hintText: hint,
				border: const OutlineInputBorder(),
				filled: true,
			),
			style: Theme.of(context).textTheme.titleLarge?.copyWith(
				fontWeight: FontWeight.w600,
			),
			onChanged: (texto) {
				final normalizado = _normalizarEntradaMonto(
					texto,
					admiteDecimal: aceptaDecimales,
				);
				if (normalizado != texto) {
					controlador.value = TextEditingValue(
						text: normalizado,
						selection: TextSelection.collapsed(offset: normalizado.length),
					);
				}
				setState(() {});
			},
			onSubmitted: (_) => alPresionarSubmit(),
		);
	}

	Widget _metodoChip(MetodoPago metodo, String etiqueta, IconData icono) {
		final seleccionado = _metodo == metodo;
		return FilterChip(
			selected: seleccionado,
			label: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(icono, size: 18.0),
					const SizedBox(width: 4.0),
					Text(etiqueta),
				],
			),
			onSelected: (_) => _seleccionarMetodo(metodo),
		);
	}

	void _cancelar() {
		if (_cerrado || !mounted) {
			return;
		}
		_cerrado = true;
		FocusManager.instance.primaryFocus?.unfocus();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) {
				return;
			}
			Navigator.of(context, rootNavigator: true).pop();
		});
	}

	void _confirmar() {
		if (_cerrado || !mounted) {
			return;
		}
		if (_total <= 0.0) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No hay monto por cobrar')),
			);
			return;
		}
		if (_metodo == MetodoPago.efectivo) {
			final recibido = double.tryParse(_recibidoCtrl.text.trim());
			if (recibido == null || recibido <= 0.0) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Indique el monto recibido en efectivo')),
				);
				return;
			}
			if (recibido < _total) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Monto recibido insuficiente')),
				);
				return;
			}
		}
		if (_metodo == MetodoPago.credito) {
			if (!_creditoDisponible) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('No se puede otorgar crédito con los datos actuales'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
			if (_diasCredito <= 0) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('Indique días de crédito válidos'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
			if (!_aceptaCredito) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('Confirme que el cliente acepta el plazo de pago'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
		}
		final request = CobroRequest(
			metodoPago: _metodo,
			descuentoTicket: 0.0,
			montoEfectivo: _metodo == MetodoPago.mixto
				? double.tryParse(_efectivoCtrl.text)
				: null,
			montoTarjeta: _metodo == MetodoPago.mixto
				? double.tryParse(_tarjetaCtrl.text)
				: null,
			montoRecibido: double.tryParse(_recibidoCtrl.text),
			diasCredito: _metodo == MetodoPago.credito ? _diasCredito : null,
		);
		_cerrado = true;
		FocusManager.instance.primaryFocus?.unfocus();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) {
				return;
			}
			Navigator.of(context, rootNavigator: true).pop(request);
		});
	}
}
