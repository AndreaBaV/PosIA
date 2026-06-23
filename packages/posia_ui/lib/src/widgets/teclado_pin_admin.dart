/// Teclado numerico visual para acceso admin con PIN.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Captura PIN numerico mediante botones grandes.
class TecladoPinAdmin extends StatefulWidget {
	const TecladoPinAdmin({
		required this.pinActual,
		required this.alPresionarDigito,
		required this.alBorrar,
		super.key,
	});

	final String pinActual;
	final ValueChanged<String> alPresionarDigito;
	final VoidCallback alBorrar;

	@override
	State<TecladoPinAdmin> createState() => _TecladoPinAdminState();
}

class _TecladoPinAdminState extends State<TecladoPinAdmin> {
	var _mostrarPin = false;

	@override
	void didUpdateWidget(covariant TecladoPinAdmin oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.pinActual.isEmpty && oldWidget.pinActual.isNotEmpty) {
			_mostrarPin = false;
		}
	}

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
						_construirIndicadoresPin(tamIndicador),
						SizedBox(height: tamTecla * 0.28),
						..._construirFilasTeclado(tamTecla, altoTecla, tamFuente),
					],
				);
			},
		);
	}

	Widget _construirIndicadoresPin(double tamano) {
		return Row(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
				if (_mostrarPin)
					Padding(
						padding: EdgeInsets.symmetric(horizontal: tamano * 0.35),
						child: Text(
							widget.pinActual.isEmpty ? '—' : widget.pinActual,
							style: TextStyle(
								fontSize: tamano * 1.35,
								fontWeight: FontWeight.bold,
								letterSpacing: 6.0,
							),
						),
					)
				else
					..._construirPuntosPin(tamano),
				IconButton(
					tooltip: _mostrarPin ? 'Ocultar' : 'Mostrar',
					icon: Icon(
						_mostrarPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
						size: tamano * 1.1,
						color: PosiaColors.neutro,
					),
					onPressed: widget.pinActual.isEmpty
						? null
						: () => setState(() => _mostrarPin = !_mostrarPin),
				),
			],
		);
	}

	List<Widget> _construirPuntosPin(double tamano) {
		final indicadores = <Widget>[];
		for (var indice = 0; indice < 4; indice++) {
			final lleno = indice < widget.pinActual.length;
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
				alPresionar: widget.alBorrar,
			);
		}
		return _TeclaPin(
			ancho: anchoTecla,
			alto: altoTecla,
			contenido: Text(
				valor,
				style: TextStyle(fontSize: tamFuente, fontWeight: FontWeight.bold),
			),
			alPresionar: () => widget.alPresionarDigito(valor),
		);
	}
}

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
