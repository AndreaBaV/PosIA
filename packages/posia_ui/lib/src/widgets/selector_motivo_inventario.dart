/// Selector de motivo normalizado para movimientos de inventario.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// Lista desplegable con motivos estandar por tipo de movimiento.
class SelectorMotivoInventario extends StatelessWidget {
	const SelectorMotivoInventario({
		required this.tipo,
		required this.valor,
		required this.alCambiar,
		super.key,
	});

	final TipoMovimientoInventario tipo;
	final String valor;
	final ValueChanged<String> alCambiar;

	@override
	Widget build(BuildContext context) {
		final opciones = motivosInventarioPorTipo(tipo);
		final seleccionado = opciones.contains(valor) ? valor : opciones.first;
		return DropdownButtonFormField<String>(
			initialValue: seleccionado,
			decoration: const InputDecoration(
				labelText: 'Motivo',
				border: OutlineInputBorder(),
			),
			items: opciones
				.map(
					(motivo) => DropdownMenuItem(
						value: motivo,
						child: Text(motivo),
					),
				)
				.toList(),
			onChanged: (nuevo) {
				if (nuevo != null) {
					alCambiar(nuevo);
				}
			},
		);
	}
}
