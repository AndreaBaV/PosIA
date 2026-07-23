/// Precio final manual de una línea del carrito (doble clic en el precio).
///
/// Permite fijar directamente el monto a cobrar por la línea —como sobreprecio
/// ("descuento inverso") o descuento— SIN recalcular el peso/cantidad. El precio
/// resultante se marca como manual (se pinta distinto para el cajero); el piso
/// de costo lo sigue validando `actualizarPrecioLinea`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';

/// Muestra el diálogo de precio final y lo aplica a la línea [indice].
Future<void> mostrarEditarPrecioFinalCaja(
	BuildContext context,
	WidgetRef ref,
	int indice,
) async {
	final estado = ref.read(carritoNotifierProvider).value;
	if (estado == null || indice < 0 || indice >= estado.lineas.length) {
		return;
	}
	final linea = estado.lineas[indice];
	if (linea.cantidad <= 0.0) {
		return;
	}
	final montoFinal = await showDialog<double>(
		context: context,
		builder: (_) => _DialogoPrecioFinal(linea: linea),
	);
	if (montoFinal == null || !context.mounted) {
		return;
	}
	// El precio unitario que produce el monto final pedido con la misma cantidad.
	final precioUnitario = montoFinal / linea.cantidad;
	final error = await ref
		.read(carritoNotifierProvider.notifier)
		.actualizarPrecioLinea(indice, precioUnitario);
	if (error != null && context.mounted) {
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text(error), backgroundColor: PosiaColors.cancelar),
		);
	}
}

class _DialogoPrecioFinal extends StatefulWidget {
	const _DialogoPrecioFinal({required this.linea});

	final LineaCarrito linea;

	@override
	State<_DialogoPrecioFinal> createState() => _DialogoPrecioFinalState();
}

class _DialogoPrecioFinalState extends State<_DialogoPrecioFinal> {
	late final TextEditingController _ctrl;
	late final FocusNode _focus;
	String? _error;

	@override
	void initState() {
		super.initState();
		_ctrl = TextEditingController(
			text: widget.linea.calcularSubtotal().toStringAsFixed(2),
		);
		_focus = FocusNode(onKeyEvent: _teclas);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted && _focus.canRequestFocus) {
				_focus.requestFocus();
				_ctrl.selection = TextSelection(
					baseOffset: 0,
					extentOffset: _ctrl.text.length,
				);
			}
		});
	}

	@override
	void dispose() {
		_ctrl.dispose();
		_focus.dispose();
		super.dispose();
	}

	KeyEventResult _teclas(FocusNode node, KeyEvent event) {
		if (event is! KeyDownEvent) {
			return KeyEventResult.ignored;
		}
		if (event.logicalKey == LogicalKeyboardKey.enter ||
			event.logicalKey == LogicalKeyboardKey.numpadEnter) {
			_aplicar();
			return KeyEventResult.handled;
		}
		if (event.logicalKey == LogicalKeyboardKey.escape) {
			Navigator.of(context).pop();
			return KeyEventResult.handled;
		}
		return KeyEventResult.ignored;
	}

	void _aplicar() {
		final monto = parsearPrecioTexto(_ctrl.text);
		if (monto == null || monto <= 0.0) {
			setState(() => _error = 'Ingrese un monto válido');
			return;
		}
		Navigator.of(context).pop(redondearMonto(monto));
	}

	@override
	Widget build(BuildContext context) {
		final linea = widget.linea;
		final costoMin = redondearMonto(
			linea.producto.costoUnitario * linea.cantidad,
		);
		return AlertDialog(
			title: Text('Precio de venta · ${linea.producto.nombre}'),
			content: SizedBox(
				width: 320.0,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Text(
							'Monto a cobrar por esta línea, sin recalcular el peso ni la '
							'cantidad. El cliente solo ve el monto final.',
							style: Theme.of(context).textTheme.bodySmall,
						),
						const SizedBox(height: 12.0),
						TextField(
							controller: _ctrl,
							focusNode: _focus,
							autofocus: true,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							decoration: const InputDecoration(
								labelText: 'Cobrar',
								prefixText: '\$ ',
								border: OutlineInputBorder(),
								helperText: 'Enter aplica · Esc cancela',
							),
							onChanged: (_) {
								if (_error != null) {
									setState(() => _error = null);
								}
							},
						),
						if (costoMin > 0.0) ...[
							const SizedBox(height: 8.0),
							Text(
								'Mínimo (costo): ${formatearMoneda(costoMin)}',
								style: TextStyle(fontSize: 12.0, color: Colors.grey.shade700),
							),
						],
						if (_error != null) ...[
							const SizedBox(height: 8.0),
							BannerMensajeDialogo(mensaje: _error!),
						],
					],
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(),
					child: const Text('Cancelar'),
				),
				FilledButton(onPressed: _aplicar, child: const Text('Aplicar')),
			],
		);
	}
}
