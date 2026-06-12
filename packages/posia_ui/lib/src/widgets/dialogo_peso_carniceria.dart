/// Dialogo de captura de peso para venta en carniceria.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../theme/posia_theme.dart';
import 'teclado_numerico_simple.dart';

/// Resultado del dialogo de peso carniceria.
class ResultadoDialogoPeso {
	/// Crea resultado del dialogo.
	///
	/// [confirmado] Indica si usuario confirmo venta.
	/// [pesoKg] Peso capturado en kilogramos.
	const ResultadoDialogoPeso({
		required this.confirmado,
		required this.pesoKg,
	});

	/// Usuario confirmo accion.
	final bool confirmado;

	/// Peso en kilogramos.
	final double pesoKg;
}

/// Muestra dialogo iconografico para capturar peso en kg.
class DialogoPesoCarniceria extends StatefulWidget {
	/// Crea dialogo de peso para producto carniceria.
	///
	/// [producto] Producto vendido por kilogramo.
	const DialogoPesoCarniceria({required this.producto, super.key});

	/// Producto seleccionado.
	final Producto producto;

	/// Presenta dialogo modal y retorna peso confirmado.
	///
	/// [context] Contexto de navegacion.
	/// [producto] Producto de carniceria.
	/// Retorna [ResultadoDialogoPeso] con decision del cajero.
	static Future<ResultadoDialogoPeso> mostrar(
		BuildContext context,
		Producto producto,
	) async {
		final resultado = await showDialog<ResultadoDialogoPeso>(
			context: context,
			builder: (_) => DialogoPesoCarniceria(producto: producto),
		);
		return resultado ?? const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0);
	}

	@override
	State<DialogoPesoCarniceria> createState() => _DialogoPesoCarniceriaState();
}

/// Estado del dialogo de peso carniceria.
class _DialogoPesoCarniceriaState extends State<DialogoPesoCarniceria> {
	String _valorPeso = '';

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: Row(
				children: [
					const Icon(Icons.scale, color: PosiaColors.cobrar, size: 32.0),
					const SizedBox(width: 8.0),
					Expanded(child: Text(widget.producto.nombre)),
				],
			),
			content: TecladoNumericoSimple(
				valorActual: _valorPeso,
				alPresionarTecla: _agregarTecla,
				alBorrar: _borrarTecla,
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(
						const ResultadoDialogoPeso(confirmado: false, pesoKg: 0.0),
					),
					child: const Text('Cancelar'),
				),
				FilledButton(
					onPressed: _confirmar,
					child: const Text('Agregar'),
				),
			],
		);
	}

	/// Agrega caracter al valor de peso respetando formato decimal.
	///
	/// [tecla] Caracter pulsado.
	void _agregarTecla(String tecla) {
		if (tecla == '.' && _valorPeso.contains('.')) {
			return;
		}
		setState(() {
			_valorPeso = _valorPeso + tecla;
		});
	}

	/// Elimina ultimo caracter del valor parcial.
	void _borrarTecla() {
		if (_valorPeso.isEmpty) {
			return;
		}
		setState(() {
			_valorPeso = _valorPeso.substring(0, _valorPeso.length - 1);
		});
	}

	/// Confirma peso ingresado y cierra dialogo.
	void _confirmar() {
		final peso = double.tryParse(_valorPeso.isEmpty ? '0' : _valorPeso) ?? 0.0;
		Navigator.of(context).pop(
			ResultadoDialogoPeso(confirmado: true, pesoKg: peso),
		);
	}
}
