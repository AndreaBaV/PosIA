/// Notificaciones tipo SnackBar posicionadas arriba de la pantalla.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Muestra mensajes breves en la parte superior con estilo POSIA.
class PosiaNotificaciones {
	PosiaNotificaciones._();

	/// Presenta un [SnackBar] en la zona superior, respetando el área segura.
	static void mostrarSnackBar(BuildContext context, SnackBar snackBar) {
		final media = MediaQuery.of(context);
		final margenSuperior = media.padding.top + 12.0;
		const alturaSnackBar = 56.0;
		// El host del SnackBar queda sobre bottomNavigationBar / FAB; estimamos
		// barras fijas para no empujar el mensaje fuera de pantalla (tests y forms).
		const alturaBarraAppEstimada = kToolbarHeight + 48.0;
		const alturaBarraInferiorEstimada = 88.0;
		final altoHost = media.size.height -
			alturaBarraAppEstimada -
			alturaBarraInferiorEstimada -
			media.padding.vertical;
		final margenInferior = (altoHost - margenSuperior - alturaSnackBar).clamp(
			8.0,
			altoHost - alturaSnackBar,
		);

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: snackBar.content,
				backgroundColor: snackBar.backgroundColor ?? PosiaColors.neutro,
				duration: snackBar.duration,
				action: snackBar.action,
				behavior: SnackBarBehavior.floating,
				margin: EdgeInsets.only(
					left: 16.0,
					right: 16.0,
					bottom: margenInferior,
				),
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(12.0),
				),
				elevation: 4.0,
				showCloseIcon: snackBar.showCloseIcon,
				closeIconColor: snackBar.closeIconColor,
			),
		);
	}

	/// Atajo para mensaje de texto simple.
	static void mostrar(
		BuildContext context,
		String mensaje, {
		Color? colorFondo,
		Duration duracion = const Duration(seconds: 3),
		SnackBarAction? accion,
	}) {
		mostrarSnackBar(
			context,
			SnackBar(
				content: Text(mensaje),
				backgroundColor: colorFondo,
				duration: duracion,
				action: accion,
			),
		);
	}
}
