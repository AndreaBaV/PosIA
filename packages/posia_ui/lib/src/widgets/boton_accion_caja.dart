/// Boton grande de accion para barra inferior de caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:flutter/material.dart';

/// Boton tactil con icono y etiqueta opcional para cajeros.
class BotonAccionCaja extends StatelessWidget {
	/// Crea boton de accion principal o secundaria.
	///
	/// [icono] Icono Material a mostrar.
	/// [etiqueta] Texto opcional bajo el icono.
	/// [colorFondo] Color de fondo del boton.
	/// [alPresionar] Callback al tocar el boton.
	/// [habilitado] Controla si el boton acepta interaccion.
	const BotonAccionCaja({
		required this.icono,
		required this.etiqueta,
		required this.colorFondo,
		required this.alPresionar,
		this.habilitado = true,
		super.key,
	});

	/// Icono representativo de la accion.
	final IconData icono;

	/// Etiqueta visible bajo icono.
	final String etiqueta;

	/// Color de fondo del boton.
	final Color colorFondo;

	/// Accion ejecutada al presionar.
	final VoidCallback alPresionar;

	/// Indica si el boton esta habilitado.
	final bool habilitado;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 4.0),
			child: Material(
				color: habilitado ? colorFondo : Colors.grey,
				borderRadius: BorderRadius.circular(12.0),
				child: InkWell(
					onTap: habilitado ? alPresionar : null,
					borderRadius: BorderRadius.circular(12.0),
					child: SizedBox(
						height: 76.0,
						width: double.infinity,
						child: Padding(
							padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(icono, color: Colors.white, size: 30.0),
									if (etiqueta.isNotEmpty) ...[
										const SizedBox(height: 4.0),
										FittedBox(
											fit: BoxFit.scaleDown,
											child: Text(
												etiqueta,
												textAlign: TextAlign.center,
												maxLines: 2,
												style: const TextStyle(
													color: Colors.white,
													fontSize: 12.0,
													fontWeight: FontWeight.w600,
													height: 1.1,
												),
											),
										),
									],
								],
							),
						),
					),
				),
			),
		);
	}
}
