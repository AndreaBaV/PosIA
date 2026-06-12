/// Teclado numerico visual para acceso admin con PIN.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Captura PIN numerico mediante botones grandes.
class TecladoPinAdmin extends StatelessWidget {
	/// Crea teclado PIN con callback de digitos.
	///
	/// [pinActual] Cadena parcial ingresada.
	/// [alPresionarDigito] Callback al pulsar digito 0-9.
	/// [alBorrar] Callback al borrar ultimo digito.
	const TecladoPinAdmin({
		required this.pinActual,
		required this.alPresionarDigito,
		required this.alBorrar,
		super.key,
	});

	/// PIN parcial visible como puntos.
	final String pinActual;

	/// Accion al pulsar digito numerico.
	final ValueChanged<String> alPresionarDigito;

	/// Accion al borrar ultimo digito.
	final VoidCallback alBorrar;

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: _construirIndicadoresPin(),
				),
				const SizedBox(height: 24.0),
				..._construirFilasTeclado(),
			],
		);
	}

	/// Construye filas del teclado numerico 3x4.
	///
	/// Retorna lista de filas de botones.
	List<Widget> _construirFilasTeclado() {
		final digitos = [
			['1', '2', '3'],
			['4', '5', '6'],
			['7', '8', '9'],
			['', '0', 'del'],
		];
		final filas = <Widget>[];
		for (final fila in digitos) {
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

	/// Construye indicadores visuales del PIN ingresado.
	///
	/// Retorna lista de iconos circulares.
	List<Widget> _construirIndicadoresPin() {
		final indicadores = <Widget>[];
		for (var indice = 0; indice < 4; indice = indice + 1) {
			final lleno = indice < pinActual.length;
			indicadores.add(
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 8.0),
					child: Icon(
						lleno ? Icons.circle : Icons.circle_outlined,
						size: 20.0,
						color: PosiaColors.neutro,
					),
				),
			);
		}
		return indicadores;
	}

	/// Construye tecla individual del teclado.
	///
	/// [valor] Digito o accion especial.
	/// Retorna widget de tecla tactil.
	Widget _construirTecla(String valor) {
		if (valor.isEmpty) {
			return const SizedBox(width: 80.0, height: 64.0);
		}
		if (valor == 'del') {
			return _TeclaPin(
				contenido: const Icon(Icons.backspace, color: PosiaColors.neutro),
				alPresionar: alBorrar,
			);
		}
		return _TeclaPin(
			contenido: Text(
				valor,
				style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
			),
			alPresionar: () => alPresionarDigito(valor),
		);
	}
}

/// Tecla tactil individual del teclado PIN.
class _TeclaPin extends StatelessWidget {
	const _TeclaPin({
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
						width: 80.0,
						height: 64.0,
						child: Center(child: contenido),
					),
				),
			),
		);
	}
}
