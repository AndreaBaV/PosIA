/// Barra de accesorio sobre el teclado virtual en dispositivos moviles.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Envuelve la app y muestra un boton "Listo" justo encima del teclado.
class AccesorioTecladoMovil extends StatelessWidget {
	const AccesorioTecladoMovil({
		required this.child,
		this.habilitado = true,
		super.key,
	});

	final Widget child;
	final bool habilitado;

	/// Quita el foco del campo activo y oculta el teclado virtual.
	static void ocultarTeclado() {
		FocusManager.instance.primaryFocus?.unfocus();
	}

	@override
	Widget build(BuildContext context) {
		if (!habilitado) {
			return child;
		}
		final insetTeclado = MediaQuery.viewInsetsOf(context).bottom;
		final tecladoVisible = insetTeclado > 0;

		return Stack(
			children: [
				child,
				if (tecladoVisible)
					Positioned(
						left: 0,
						right: 0,
						bottom: insetTeclado,
						child: Material(
							elevation: 6,
							shadowColor: Colors.black26,
							color: Theme.of(context).colorScheme.surfaceContainerHighest,
							child: SizedBox(
								height: 44,
								child: Row(
									children: [
										const Spacer(),
										TextButton.icon(
											onPressed: ocultarTeclado,
											icon: const Icon(Icons.keyboard_hide, size: 20),
											label: const Text('Listo'),
											style: TextButton.styleFrom(
												foregroundColor: PosiaColors.cobrar,
												padding: const EdgeInsets.symmetric(horizontal: 16),
											),
										),
									],
								),
							),
						),
					),
			],
		);
	}
}
