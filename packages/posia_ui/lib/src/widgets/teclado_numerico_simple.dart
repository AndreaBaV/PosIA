/// Teclado numerico simple con punto decimal para captura de peso.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Captura valores numericos con teclado visual grande.
class TecladoNumericoSimple extends StatelessWidget {
	/// Crea teclado numerico configurable.
	///
	/// [valorActual] Texto numerico parcial visible.
	/// [alPresionarTecla] Callback al pulsar tecla.
	/// [alBorrar] Callback al borrar ultimo caracter.
	const TecladoNumericoSimple({
		required this.valorActual,
		required this.alPresionarTecla,
		required this.alBorrar,
		super.key,
	});

	/// Valor parcial ingresado.
	final String valorActual;

	/// Accion al pulsar tecla.
	final ValueChanged<String> alPresionarTecla;

	/// Accion al borrar caracter.
	final VoidCallback alBorrar;

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Text(
					valorActual.isEmpty ? '0.0' : valorActual,
					style: Theme.of(context).textTheme.headlineLarge,
				),
				const SizedBox(height: 16.0),
				..._construirFilas(),
			],
		);
	}

	/// Construye filas del teclado numerico.
	///
	/// Retorna lista de filas de botones.
	List<Widget> _construirFilas() {
		final filasTeclas = [
			['1', '2', '3'],
			['4', '5', '6'],
			['7', '8', '9'],
			['.', '0', 'del'],
		];
		final filas = <Widget>[];
		for (final fila in filasTeclas) {
			filas.add(
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: fila.map(_construirTecla).toList(),
				),
			);
			filas.add(const SizedBox(height: 8.0));
		}
		return filas;
	}

	/// Construye tecla individual del teclado.
	///
	/// [valor] Caracter o accion especial.
	/// Retorna widget tactil.
	Widget _construirTecla(String valor) {
		if (valor == 'del') {
			return _TeclaNumerica(
				contenido: const Icon(Icons.backspace),
				alPresionar: alBorrar,
			);
		}
		return _TeclaNumerica(
			contenido: Text(valor, style: const TextStyle(fontSize: 24.0)),
			alPresionar: () => alPresionarTecla(valor),
		);
	}
}

/// Tecla tactil del teclado numerico simple.
class _TeclaNumerica extends StatelessWidget {
	const _TeclaNumerica({
		required this.contenido,
		required this.alPresionar,
	});

	final Widget contenido;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(4.0),
			child: Material(
				color: PosiaColors.tarjeta,
				borderRadius: BorderRadius.circular(12.0),
				elevation: 1.0,
				child: InkWell(
					onTap: alPresionar,
					borderRadius: BorderRadius.circular(12.0),
					child: SizedBox(
						width: 72.0,
						height: 56.0,
						child: Center(child: contenido),
					),
				),
			),
		);
	}
}
