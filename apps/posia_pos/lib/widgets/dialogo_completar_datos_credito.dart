/// Dialogo para completar datos obligatorios de credito del cliente.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

/// Captura telefono, direccion y plazo si faltan para fiar.
Future<Cliente?> mostrarDialogoCompletarDatosCredito({
	required BuildContext context,
	required Cliente cliente,
}) async {
	final telefonoCtrl = TextEditingController(text: cliente.telefono);
	final direccionCtrl = TextEditingController(text: cliente.direccion);
	final diasCtrl = TextEditingController(
		text: cliente.diasCredito.toString(),
	);
	final resultado = await showDialog<Cliente>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text('Datos para crédito'),
			content: SizedBox(
				width: 420.0,
				child: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text('Cliente: ${cliente.nombre}'),
							const SizedBox(height: 8.0),
							const Text(
								'Para otorgar crédito se requiere teléfono y dirección.',
								style: TextStyle(color: Colors.grey),
							),
							const SizedBox(height: 12.0),
							TextField(
								controller: telefonoCtrl,
								keyboardType: TextInputType.phone,
								decoration: const InputDecoration(
									labelText: 'Teléfono *',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: direccionCtrl,
								maxLines: 2,
								decoration: const InputDecoration(
									labelText: 'Dirección *',
									border: OutlineInputBorder(),
								),
							),
							const SizedBox(height: 8.0),
							TextField(
								controller: diasCtrl,
								keyboardType: TextInputType.number,
								decoration: const InputDecoration(
									labelText: 'Días de crédito (predeterminado)',
									border: OutlineInputBorder(),
									suffixText: 'días',
								),
							),
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(ctx),
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: () {
						final telefono = telefonoCtrl.text.trim();
						final direccion = direccionCtrl.text.trim();
						final dias = int.tryParse(diasCtrl.text.trim()) ??
							DIAS_CREDITO_PREDETERMINADO;
						if (telefono.isEmpty || direccion.isEmpty) {
							ScaffoldMessenger.of(ctx).showSnackBar(
								const SnackBar(
									content: Text('Teléfono y dirección son obligatorios'),
									backgroundColor: PosiaColors.cancelar,
								),
							);
							return;
						}
						if (dias <= 0) {
							ScaffoldMessenger.of(ctx).showSnackBar(
								const SnackBar(
									content: Text('Los días de crédito deben ser mayores a cero'),
									backgroundColor: PosiaColors.cancelar,
								),
							);
							return;
						}
						Navigator.pop(
							ctx,
							cliente.copiarCon(
								telefono: telefono,
								direccion: direccion,
								diasCredito: dias,
								creditoHabilitado: true,
							),
						);
					},
					child: const Text('Guardar'),
				),
			],
		),
	);
	telefonoCtrl.dispose();
	direccionCtrl.dispose();
	diasCtrl.dispose();
	return resultado;
}
