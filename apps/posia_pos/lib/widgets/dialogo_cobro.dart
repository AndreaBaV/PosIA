/// Dialogo de cobro con multipago, credito y cambio.
library;

import 'package:flutter/material.dart';
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
		builder: (ctx) => _DialogoCobro(
			subtotal: subtotal,
			cliente: cliente,
		),
	);
}

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
	var _aceptaCredito = false;

	@override
	void initState() {
		super.initState();
		_diasCreditoCtrl.text = (widget.cliente?.diasCredito ?? DIAS_CREDITO_PREDETERMINADO)
			.toString();
	}

	@override
	void dispose() {
		_recibidoCtrl.dispose();
		_efectivoCtrl.dispose();
		_tarjetaCtrl.dispose();
		_diasCreditoCtrl.dispose();
		super.dispose();
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

		return AlertDialog(
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
										_metodoChip(MetodoPago.credito, 'Credito', Icons.handshake),
								],
							),
							if (widget.cliente == null)
								const Padding(
									padding: EdgeInsets.only(top: 8.0),
									child: Text(
										'Seleccione un cliente para venta a credito.',
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
								TextField(
									controller: _diasCreditoCtrl,
									keyboardType: TextInputType.number,
									decoration: const InputDecoration(
										labelText: 'Dias para pagar',
										border: OutlineInputBorder(),
										suffixText: 'dias',
									),
									onChanged: (_) => setState(() {}),
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
								TextField(
									controller: _recibidoCtrl,
									keyboardType: const TextInputType.numberWithOptions(decimal: true),
									decoration: const InputDecoration(
										labelText: 'Recibido (\$)',
										border: OutlineInputBorder(),
									),
									onChanged: (_) => setState(() {}),
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
								TextField(
									controller: _efectivoCtrl,
									keyboardType: const TextInputType.numberWithOptions(decimal: true),
									decoration: const InputDecoration(
										labelText: 'Efectivo (\$)',
										border: OutlineInputBorder(),
									),
								),
								const SizedBox(height: 8.0),
								TextField(
									controller: _tarjetaCtrl,
									keyboardType: const TextInputType.numberWithOptions(decimal: true),
									decoration: const InputDecoration(
										labelText: 'Tarjeta (\$)',
										border: OutlineInputBorder(),
									),
								),
							],
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(context),
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: _confirmar,
					style: FilledButton.styleFrom(backgroundColor: PosiaColors.cobrar),
					child: const Text('COBRAR'),
				),
			],
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
			onSelected: (_) => setState(() {
				_metodo = metodo;
				if (metodo != MetodoPago.credito) {
					_aceptaCredito = false;
				}
			}),
		);
	}

	void _confirmar() {
		if (_total <= 0.0) {
			return;
		}
		if (_metodo == MetodoPago.efectivo) {
			final recibido = double.tryParse(_recibidoCtrl.text);
			if (recibido != null && recibido < _total) {
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
						content: Text('No se puede otorgar credito con los datos actuales'),
						backgroundColor: PosiaColors.cancelar,
					),
				);
				return;
			}
			if (_diasCredito <= 0) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('Indique dias de credito validos'),
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
		Navigator.pop(
			context,
			CobroRequest(
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
			),
		);
	}
}
