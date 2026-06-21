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
	const TarjetaMenuAdmin({
		required this.icono,
		required this.titulo,
		required this.subtitulo,
		required this.color,
		required this.alPresionar,
		super.key,
	});

	final IconData icono;
	final String titulo;
	final String subtitulo;
	final Color color;
	final VoidCallback alPresionar;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: PosiaColors.tarjeta,
			borderRadius: BorderRadius.circular(16.0),
			elevation: 1.0,
			shadowColor: Colors.black.withValues(alpha: 0.06),
			child: InkWell(
				onTap: alPresionar,
				borderRadius: BorderRadius.circular(16.0),
				child: Padding(
					padding: const EdgeInsets.all(16.0),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Container(
								padding: const EdgeInsets.all(14.0),
								decoration: BoxDecoration(
									color: color.withValues(alpha: 0.12),
									borderRadius: BorderRadius.circular(14.0),
								),
								child: Icon(icono, size: 36.0, color: color),
							),
							const SizedBox(height: 12.0),
							Text(
								titulo,
								textAlign: TextAlign.center,
								maxLines: 2,
								overflow: TextOverflow.ellipsis,
								style: Theme.of(context).textTheme.titleMedium?.copyWith(
									fontWeight: FontWeight.bold,
								),
							),
							const SizedBox(height: 4.0),
							Text(
								subtitulo,
								textAlign: TextAlign.center,
								maxLines: 2,
								overflow: TextOverflow.ellipsis,
								style: Theme.of(context).textTheme.bodySmall?.copyWith(
									color: Colors.grey.shade600,
								),
							),
						],
					),
				),
			),
		);
	}
}
