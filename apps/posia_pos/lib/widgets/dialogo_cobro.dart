/// Dialogo de cobro con multipago, descuento y cambio.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

/// Muestra dialogo de cobro y retorna [CobroRequest] o null si cancela.
Future<CobroRequest?> mostrarDialogoCobro({
	required BuildContext context,
	required double subtotal,
	required bool creditoDisponible,
}) async {
	return showDialog<CobroRequest>(
		context: context,
		builder: (ctx) => _DialogoCobro(
			subtotal: subtotal,
			creditoDisponible: creditoDisponible,
		),
	);
}

class _DialogoCobro extends StatefulWidget {
	const _DialogoCobro({
		required this.subtotal,
		required this.creditoDisponible,
	});

	final double subtotal;
	final bool creditoDisponible;

	@override
	State<_DialogoCobro> createState() => _DialogoCobroState();
}

class _DialogoCobroState extends State<_DialogoCobro> {
	MetodoPago _metodo = MetodoPago.efectivo;
	final _descuentoCtrl = TextEditingController(text: '0');
	final _recibidoCtrl = TextEditingController();
	final _efectivoCtrl = TextEditingController();
	final _tarjetaCtrl = TextEditingController();

	@override
	void dispose() {
		_descuentoCtrl.dispose();
		_recibidoCtrl.dispose();
		_efectivoCtrl.dispose();
		_tarjetaCtrl.dispose();
		super.dispose();
	}

	double get _descuento => double.tryParse(_descuentoCtrl.text) ?? 0.0;

	double get _total => redondearMonto(
		(widget.subtotal - _descuento).clamp(0.0, double.infinity),
	);

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
							const SizedBox(height: 12.0),
							TextField(
								controller: _descuentoCtrl,
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								decoration: const InputDecoration(
									labelText: 'Descuento ticket (\$)',
									border: OutlineInputBorder(),
								),
								onChanged: (_) => setState(() {}),
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
									if (widget.creditoDisponible)
										_metodoChip(MetodoPago.credito, 'Crédito', Icons.handshake),
								],
							),
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
			onSelected: (_) => setState(() => _metodo = metodo),
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
		Navigator.pop(
			context,
			CobroRequest(
				metodoPago: _metodo,
				descuentoTicket: _descuento,
				montoEfectivo: _metodo == MetodoPago.mixto
					? double.tryParse(_efectivoCtrl.text)
					: null,
				montoTarjeta: _metodo == MetodoPago.mixto
					? double.tryParse(_tarjetaCtrl.text)
					: null,
				montoRecibido: double.tryParse(_recibidoCtrl.text),
			),
		);
	}
}
