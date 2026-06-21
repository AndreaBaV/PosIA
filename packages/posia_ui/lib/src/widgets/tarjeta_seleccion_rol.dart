/// Tarjeta de seleccion de rol en pantalla de inicio de sesion.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../utils/presentacion_rol.dart';

/// Opcion tactil para elegir administrador, supervisor o empleado.
class TarjetaSeleccionRol extends StatelessWidget {
	const TarjetaSeleccionRol({
		required this.rol,
		required this.seleccionado,
		required this.alSeleccionar,
		super.key,
	});

	final RolUsuario rol;
	final bool seleccionado;
	final VoidCallback alSeleccionar;

	@override
	Widget build(BuildContext context) {
		final color = PresentacionRol.color(rol);
		return Material(
			color: seleccionado ? color.withValues(alpha: 0.12) : Colors.white,
			borderRadius: BorderRadius.circular(14.0),
			elevation: seleccionado ? 2.0 : 0.5,
			shadowColor: color.withValues(alpha: 0.2),
			child: InkWell(
				onTap: alSeleccionar,
				borderRadius: BorderRadius.circular(14.0),
				child: Container(
					width: double.infinity,
					padding: const EdgeInsets.all(14.0),
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(14.0),
						border: Border.all(
							color: seleccionado ? color : Colors.grey.shade300,
							width: seleccionado ? 2.0 : 1.0,
						),
					),
					child: Row(
						children: [
							CircleAvatar(
								backgroundColor: color.withValues(alpha: 0.15),
								child: Icon(PresentacionRol.icono(rol), color: color),
							),
							const SizedBox(width: 12.0),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											PermisosUsuario.etiquetaRol(rol),
											style: TextStyle(
												fontWeight: FontWeight.bold,
												color: seleccionado ? color : null,
											),
										),
										const SizedBox(height: 2.0),
										Text(
											PermisosUsuario.descripcionRol(rol),
											style: Theme.of(context).textTheme.bodySmall?.copyWith(
												color: Colors.grey.shade700,
											),
										),
									],
								),
							),
							if (seleccionado)
								Icon(Icons.check_circle, color: color),
						],
					),
				),
			),
		);
	}
}
