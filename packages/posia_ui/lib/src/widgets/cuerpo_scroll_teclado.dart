/// Cuerpo de pantalla desplazable que deja espacio al teclado virtual.
library;

import 'package:flutter/material.dart';

import 'accesorio_teclado_movil.dart';

/// [SingleChildScrollView] con altura minima y margen inferior para el teclado.
///
/// Usar como `body` de [Scaffold] cuando hay campos cerca del borde inferior
/// o formularios largos en movil.
class CuerpoScrollTeclado extends StatelessWidget {
	const CuerpoScrollTeclado({
		required this.child,
		this.padding,
		this.alinearAlCentroCuandoCabe = false,
		super.key,
	});

	final Widget child;
	final EdgeInsetsGeometry? padding;

	/// Si es true y el contenido es mas bajo que la pantalla, lo centra verticalmente
	/// cuando el teclado esta cerrado.
	final bool alinearAlCentroCuandoCabe;

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final insetTeclado = MediaQuery.viewInsetsOf(context).bottom;
				final tecladoAbierto = insetTeclado > 0;
				final paddingResuelto = (padding ?? EdgeInsets.zero).resolve(
					Directionality.of(context),
				);
				final margenTeclado = tecladoAbierto
					? AccesorioTecladoMovil.alturaBarraListo +
						AccesorioTecladoMovil.margenInferiorDesplazamiento
					: 0.0;
				final alturaUtil = constraints.maxHeight - paddingResuelto.vertical;

				return SingleChildScrollView(
					keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
					padding: paddingResuelto.copyWith(
						bottom: paddingResuelto.bottom + margenTeclado,
					),
					child: ConstrainedBox(
						constraints: BoxConstraints(minHeight: alturaUtil),
						child: alinearAlCentroCuandoCabe && !tecladoAbierto
							? Align(
								alignment: Alignment.center,
								child: child,
							)
							: child,
					),
				);
			},
		);
	}
}
