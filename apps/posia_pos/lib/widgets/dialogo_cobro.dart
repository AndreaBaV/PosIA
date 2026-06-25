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
	late final FocusNode _capturaFocus;
	var _aceptaCredito = false;
	var _cerrado = false;
	_CampoMontoCobro _campoMontoActivo = _CampoMontoCobro.recibido;

	@override
	void initState() {
		super.initState();
		_diasCreditoCtrl.text = (widget.cliente?.diasCredito ?? DIAS_CREDITO_PREDETERMINADO)
			.toString();
		_capturaFocus = FocusNode(onKeyEvent: _manejarTeclaCaptura);
		WidgetsBinding.instance.addPostFrameCallback((_) => _enfocarCaptura());
	}

	@override
	void dispose() {
		_capturaFocus.dispose();
		_recibidoCtrl.dispose();
		_efectivoCtrl.dispose();
		_tarjetaCtrl.dispose();
		_diasCreditoCtrl.dispose();
		super.dispose();
	}

	void _enfocarCaptura() {
		if (mounted && _capturaFocus.canRequestFocus) {
			_capturaFocus.requestFocus();
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
		_enfocarCaptura();
	}

	void _seleccionarCampoMonto(_CampoMontoCobro campo) {
		setState(() => _campoMontoActivo = campo);
		_enfocarCaptura();
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

	TextEditingController get _controladorCampoActivo => switch (_campoMontoActivo) {
		_CampoMontoCobro.recibido => _recibidoCtrl,
		_CampoMontoCobro.efectivoMixto => _efectivoCtrl,
		_CampoMontoCobro.tarjetaMixto => _tarjetaCtrl,
		_CampoMontoCobro.diasCredito => _diasCreditoCtrl,
	};

	KeyEventResult _manejarTeclaCaptura(FocusNode node, KeyEvent event) {
		if (_cerrado || event is! KeyDownEvent) {
			return KeyEventResult.ignored;
		}
		if (event.logicalKey == LogicalKeyboardKey.escape) {
			_cancelar();
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			_confirmar();
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.tab) {
			if (_metodo == MetodoPago.mixto) {
				setState(() {
					_campoMontoActivo = _campoMontoActivo == _CampoMontoCobro.efectivoMixto
						? _CampoMontoCobro.tarjetaMixto
						: _CampoMontoCobro.efectivoMixto;
				});
				return KeyEventResult.handled;
			}
			return KeyEventResult.ignored;
		}
		if (!_capturaMontoActiva) {
			return KeyEventResult.ignored;
		}
		final digito = digitoDesdeTeclaFisica(event.logicalKey);
		if (digito != null) {
			_agregarTeclaMonto(digito);
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.period ||
			event.logicalKey == LogicalKeyboardKey.numpadDecimal ||
			event.logicalKey == LogicalKeyboardKey.comma) {
			_agregarTeclaMonto('.');
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.backspace ||
			event.logicalKey == LogicalKeyboardKey.delete) {
			_borrarTeclaMonto();
			return KeyEventResult.handled;
		}
		return KeyEventResult.ignored;
	}

	void _agregarTeclaMonto(String tecla) {
		final ctrl = _controladorCampoActivo;
		var valor = ctrl.text;
		if (tecla == '.' && valor.contains('.')) {
			return;
		}
		if (_campoMontoActivo == _CampoMontoCobro.diasCredito && tecla == '.') {
			return;
		}
		valor = _normalizarEntradaMonto(valor + tecla);
		_establecerValorCampo(ctrl, valor);
	}

	void _borrarTeclaMonto() {
		final ctrl = _controladorCampoActivo;
		final valor = ctrl.text;
		if (valor.isEmpty) {
			return;
		}
		_establecerValorCampo(ctrl, valor.substring(0, valor.length - 1));
	}

	void _establecerValorCampo(TextEditingController ctrl, String valor) {
		setState(() {
			ctrl.value = TextEditingValue(
				text: valor,
				selection: TextSelection.collapsed(offset: valor.length),
			);
		});
	}

	String _normalizarEntradaMonto(String raw) {
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
				focusNode: _capturaFocus,
				autofocus: true,
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
									_campoMontoLectura(
										controlador: _diasCreditoCtrl,
										etiqueta: 'Días para pagar',
										sufijo: 'días',
										activo: _campoMontoActivo == _CampoMontoCobro.diasCredito,
										alSeleccionar: () =>
											_seleccionarCampoMonto(_CampoMontoCobro.diasCredito),
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
									_campoMontoLectura(
										controlador: _recibidoCtrl,
										etiqueta: 'Recibido (\$)',
										activo: _campoMontoActivo == _CampoMontoCobro.recibido,
										alSeleccionar: () =>
											_seleccionarCampoMonto(_CampoMontoCobro.recibido),
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
									_campoMontoLectura(
										controlador: _efectivoCtrl,
										etiqueta: 'Efectivo (\$)',
										activo: _campoMontoActivo == _CampoMontoCobro.efectivoMixto,
										alSeleccionar: () =>
											_seleccionarCampoMonto(_CampoMontoCobro.efectivoMixto),
									),
									const SizedBox(height: 8.0),
									_campoMontoLectura(
										controlador: _tarjetaCtrl,
										etiqueta: 'Tarjeta (\$)',
										activo: _campoMontoActivo == _CampoMontoCobro.tarjetaMixto,
										alSeleccionar: () =>
											_seleccionarCampoMonto(_CampoMontoCobro.tarjetaMixto),
									),
									const SizedBox(height: 4.0),
									const Text(
										'Tab alterna entre efectivo y tarjeta',
										style: TextStyle(color: Colors.grey, fontSize: 11.0),
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

	Widget _campoMontoLectura({
		required TextEditingController controlador,
		required String etiqueta,
		required bool activo,
		required VoidCallback alSeleccionar,
		String? sufijo,
	}) {
		return GestureDetector(
			onTap: alSeleccionar,
			child: InputDecorator(
				isFocused: activo,
				decoration: InputDecoration(
					labelText: etiqueta,
					suffixText: sufijo,
					border: const OutlineInputBorder(),
					filled: true,
					fillColor: activo ? PosiaColors.cobrar.withValues(alpha: 0.06) : null,
				),
				child: Text(
					controlador.text.isEmpty ? '—' : controlador.text,
					style: Theme.of(context).textTheme.titleLarge?.copyWith(
						fontWeight: FontWeight.w600,
					),
				),
			),
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
		_capturaFocus.unfocus();
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
		_capturaFocus.unfocus();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (!mounted) {
				return;
			}
			Navigator.of(context, rootNavigator: true).pop(request);
		});
	}
}
