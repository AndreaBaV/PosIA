/// Banner de mensaje inline para diálogos con teclado numérico embebido.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-07-01 18:00:00 (UTC-6)
/// Ultima modificacion: 2026-07-01 18:00:00 (UTC-6)
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Tipo de mensaje inline mostrado en el banner del diálogo.
enum TipoMensajeDialogo { error, aviso }

/// Banner compacto que muestra un mensaje de retroalimentación DENTRO del
/// contenido del diálogo, en lugar de emitir un [SnackBar] al [Scaffold]
/// padre.
///
/// Motivo: en móvil, los diálogos de captura de monto/cantidad/peso muestran
/// un teclado numérico embebido que ocupa la parte inferior del diálogo.
/// Además, el teclado del sistema (cuando aplica) también aparece pegado al
/// borde inferior. Un [SnackBar] convencional queda oculto bajo esos
/// elementos, por lo que la persona cajera nunca ve avisos como
/// "monto insuficiente".
///
/// Este banner se coloca en el flujo visual del diálogo (típicamente arriba
/// del teclado numérico) para garantizar que el mensaje sea visible sin
/// importar el estado del teclado.
class BannerMensajeDialogo extends StatelessWidget {
	const BannerMensajeDialogo({
		required this.mensaje,
		this.tipo = TipoMensajeDialogo.error,
		this.padding = const EdgeInsets.symmetric(vertical: 8.0),
		super.key,
	});

	/// Texto a mostrar. Debe ser corto y accionable.
	final String mensaje;

	/// Tono visual del banner.
	final TipoMensajeDialogo tipo;

	/// Padding externo del banner (para separarlo de vecinos).
	final EdgeInsetsGeometry padding;

	@override
	Widget build(BuildContext context) {
		final Color color = switch (tipo) {
			TipoMensajeDialogo.error => PosiaColors.cancelar,
			TipoMensajeDialogo.aviso => Colors.orange.shade800,
		};
		final IconData icono = switch (tipo) {
			TipoMensajeDialogo.error => Icons.error_outline,
			TipoMensajeDialogo.aviso => Icons.info_outline,
		};
		return Padding(
			padding: padding,
			child: Container(
				padding: const EdgeInsets.symmetric(
					horizontal: 12.0,
					vertical: 10.0,
				),
				decoration: BoxDecoration(
					color: color.withValues(alpha: 0.10),
					border: Border.all(color: color.withValues(alpha: 0.35)),
					borderRadius: BorderRadius.circular(10.0),
				),
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						Icon(icono, color: color, size: 20.0),
						const SizedBox(width: 8.0),
						Expanded(
							child: Text(
								mensaje,
								style: TextStyle(
									color: color,
									fontWeight: FontWeight.w600,
									fontSize: 13.5,
								),
							),
						),
					],
				),
			),
		);
	}
}
