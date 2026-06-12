/// Tarjeta de menu grande para panel de administracion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Boton de menu admin con icono grande y etiqueta corta.
class TarjetaMenuAdmin extends StatelessWidget {
	/// Crea tarjeta de acceso a seccion administrativa.
	///
	/// [icono] Icono representativo de la seccion.
	/// [titulo] Titulo visible bajo el icono.
	/// [subtitulo] Texto auxiliar opcional.
	/// [color] Color de acento de la tarjeta.
	/// [alPresionar] Accion al seleccionar la tarjeta.
	const TarjetaMenuAdmin({
		required this.icono,
		required this.titulo,
		required this.subtitulo,
		required this.color,
		required this.alPresionar,
		super.key,
	});

	/// Icono de la seccion.
	final IconData icono;

	/// Titulo principal.
	final String titulo;

	/// Subtitulo descriptivo.
	final String subtitulo;

	/// Color de acento.
	final Color color;

	/// Callback de seleccion.
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: PosiaColors.tarjeta,
			borderRadius: BorderRadius.circular(16.0),
			elevation: 2.0,
			child: InkWell(
				onTap: alPresionar,
				borderRadius: BorderRadius.circular(16.0),
				child: Padding(
					padding: const EdgeInsets.all(20.0),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(icono, size: 48.0, color: color),
							const SizedBox(height: 12.0),
							Text(
								titulo,
								textAlign: TextAlign.center,
								style: Theme.of(context).textTheme.titleLarge,
							),
							const SizedBox(height: 4.0),
							Text(
								subtitulo,
								textAlign: TextAlign.center,
								style: Theme.of(context).textTheme.bodyLarge?.copyWith(
									color: Colors.grey,
								),
							),
						],
					),
				),
			),
		);
	}
}
