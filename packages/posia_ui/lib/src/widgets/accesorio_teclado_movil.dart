/// Barra de accesorio sobre el teclado virtual en dispositivos moviles.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Envuelve la app y muestra un boton "Listo" justo encima del teclado.
///
/// Tambien desplaza automaticamente el campo enfocado para que no quede oculto
/// detras del teclado ni de la barra "Listo".
class AccesorioTecladoMovil extends StatefulWidget {
	const AccesorioTecladoMovil({
		required this.child,
		this.habilitado = true,
		super.key,
	});

	final Widget child;
	final bool habilitado;

	/// Altura de la barra "Listo" sobre el teclado.
	static const double alturaBarraListo = 44.0;

	/// Margen extra bajo el campo al desplazar con teclado abierto.
	static const double margenInferiorDesplazamiento = 16.0;

	/// Quita el foco del campo activo y oculta el teclado virtual.
	static void ocultarTeclado() {
		FocusManager.instance.primaryFocus?.unfocus();
	}

	/// Desplaza el campo con foco para mantenerlo visible sobre el teclado.
	static void desplazarCampoEnfocado(BuildContext context, {int intento = 0}) {
		final foco = FocusManager.instance.primaryFocus;
		final contextoCampo = foco?.context;
		if (foco == null || contextoCampo == null || !foco.hasFocus) {
			return;
		}

		WidgetsBinding.instance.addPostFrameCallback((_) async {
			if (!context.mounted || !contextoCampo.mounted) {
				return;
			}
			final insetTeclado = MediaQuery.viewInsetsOf(context).bottom;
			if (insetTeclado <= 0 && intento < 3) {
				await Future<void>.delayed(Duration(milliseconds: 80 * (intento + 1)));
				if (context.mounted) {
					desplazarCampoEnfocado(context, intento: intento + 1);
				}
				return;
			}

			await Scrollable.ensureVisible(
				contextoCampo,
				alignment: 0.12,
				duration: const Duration(milliseconds: 280),
				curve: Curves.easeOutCubic,
				alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
			);
		});
	}

	@override
	State<AccesorioTecladoMovil> createState() => _AccesorioTecladoMovilState();
}

class _AccesorioTecladoMovilState extends State<AccesorioTecladoMovil> {
	var _ultimoInsetTeclado = 0.0;

	@override
	void initState() {
		super.initState();
		if (widget.habilitado) {
			FocusManager.instance.addListener(_alCambiarFoco);
		}
	}

	@override
	void didUpdateWidget(covariant AccesorioTecladoMovil oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.habilitado == widget.habilitado) {
			return;
		}
		if (widget.habilitado) {
			FocusManager.instance.addListener(_alCambiarFoco);
		} else {
			FocusManager.instance.removeListener(_alCambiarFoco);
		}
	}

	@override
	void dispose() {
		if (widget.habilitado) {
			FocusManager.instance.removeListener(_alCambiarFoco);
		}
		super.dispose();
	}

	void _alCambiarFoco() {
		if (!mounted || !widget.habilitado) {
			return;
		}
		AccesorioTecladoMovil.desplazarCampoEnfocado(context);
	}

	@override
	Widget build(BuildContext context) {
		if (!widget.habilitado) {
			return widget.child;
		}

		final insetTeclado = MediaQuery.viewInsetsOf(context).bottom;
		final tecladoVisible = insetTeclado > 0;
		if (insetTeclado != _ultimoInsetTeclado) {
			_ultimoInsetTeclado = insetTeclado;
			if (tecladoVisible) {
				AccesorioTecladoMovil.desplazarCampoEnfocado(context);
			}
		}

		return Stack(
			children: [
				widget.child,
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
								height: AccesorioTecladoMovil.alturaBarraListo,
								child: Row(
									children: [
										const Spacer(),
										TextButton.icon(
											onPressed: AccesorioTecladoMovil.ocultarTeclado,
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
