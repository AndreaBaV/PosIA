/// Contenido de dialogo desplazable con espacio para el teclado virtual.
library;

import 'package:flutter/material.dart';

import 'accesorio_teclado_movil.dart';

/// Envuelve el contenido de un [AlertDialog] para que los campos inferiores
/// sigan visibles cuando se abre el teclado en movil.
class ContenidoDialogoTeclado extends StatelessWidget {
	const ContenidoDialogoTeclado({
		required this.child,
		this.ancho,
		super.key,
	});

	final Widget child;
	final double? ancho;

	@override
	Widget build(BuildContext context) {
		final insetTeclado = MediaQuery.viewInsetsOf(context).bottom;
		final margenInferior = insetTeclado > 0
			? AccesorioTecladoMovil.alturaBarraListo +
				AccesorioTecladoMovil.margenInferiorDesplazamiento
			: 0.0;

		return SingleChildScrollView(
			child: Padding(
				padding: EdgeInsets.only(bottom: margenInferior),
				child: SizedBox(
					width: ancho,
					child: child,
				),
			),
		);
	}
}
