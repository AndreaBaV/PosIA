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
		return LayoutBuilder(
			builder: (context, constraints) {
				final ancho = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
				final tamTecla = (ancho / 3.6).clamp(56.0, 100.0);
				final altoTecla = tamTecla * 0.78;
				final tamFuente = tamTecla * 0.36;
				final tamIndicador = tamTecla * 0.24;
				return Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: _construirIndicadoresPin(tamIndicador),
						),
						SizedBox(height: tamTecla * 0.28),
						..._construirFilasTeclado(tamTecla, altoTecla, tamFuente),
					],
				);
			},
		);
	}

	List<Widget> _construirFilasTeclado(double anchoTecla, double altoTecla, double tamFuente) {
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
					children: fila
						.map(
							(valor) => _construirTecla(
								valor,
								anchoTecla: anchoTecla,
								altoTecla: altoTecla,
								tamFuente: tamFuente,
							),
						)
						.toList(),
				),
			);
			filas.add(SizedBox(height: anchoTecla * 0.08));
		}
		return filas;
	}

	List<Widget> _construirIndicadoresPin(double tamano) {
		final indicadores = <Widget>[];
		for (var indice = 0; indice < 4; indice = indice + 1) {
			final lleno = indice < pinActual.length;
			indicadores.add(
				Padding(
					padding: EdgeInsets.symmetric(horizontal: tamano * 0.35),
					child: Icon(
						lleno ? Icons.circle : Icons.circle_outlined,
						size: tamano,
						color: PosiaColors.neutro,
					),
				),
			);
		}
		return indicadores;
	}

	Widget _construirTecla(
		String valor, {
		required double anchoTecla,
		required double altoTecla,
		required double tamFuente,
	}) {
		if (valor.isEmpty) {
			return SizedBox(width: anchoTecla, height: altoTecla);
		}
		if (valor == 'del') {
			return _TeclaPin(
				ancho: anchoTecla,
				alto: altoTecla,
				contenido: Icon(Icons.backspace, color: PosiaColors.neutro, size: tamFuente),
				alPresionar: alBorrar,
			);
		}
		return _TeclaPin(
			ancho: anchoTecla,
			alto: altoTecla,
			contenido: Text(
				valor,
				style: TextStyle(fontSize: tamFuente, fontWeight: FontWeight.bold),
			),
			alPresionar: () => alPresionarDigito(valor),
		);
	}
}

/// Tecla tactil individual del teclado PIN.
class _TeclaPin extends StatelessWidget {
	const _TeclaPin({
		required this.ancho,
		required this.alto,
		required this.contenido,
		required this.alPresionar,
	});

	final double ancho;
	final double alto;
	final Widget contenido;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: EdgeInsets.all(ancho * 0.05),
			child: Material(
				color: PosiaColors.tarjeta,
				borderRadius: BorderRadius.circular(12.0),
				elevation: 1.0,
				child: InkWell(
					onTap: alPresionar,
					borderRadius: BorderRadius.circular(12.0),
					child: SizedBox(
						width: ancho,
						height: alto,
						child: Center(child: contenido),
					),
				),
			),
		);
	}
}
