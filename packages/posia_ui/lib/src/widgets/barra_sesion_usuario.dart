/// Barra superior con usuario autenticado y accion de cerrar sesion.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../utils/presentacion_rol.dart';
import 'insignia_rol.dart';
import '../theme/posia_theme.dart';

/// Muestra nombre, rol y tienda de la sesion activa.
class BarraSesionUsuario extends StatelessWidget {
	const BarraSesionUsuario({
		required this.nombreUsuario,
		required this.rol,
		required this.nombreTienda,
		required this.alCerrarSesion,
		this.alAbrirMiCuenta,
		super.key,
	});

	final String nombreUsuario;
	final RolUsuario rol;
	final String nombreTienda;
	final VoidCallback alCerrarSesion;
	final VoidCallback? alAbrirMiCuenta;

	@override
	Widget build(BuildContext context) {
		final color = PresentacionRol.color(rol);
		return Material(
			color: color.withValues(alpha: 0.08),
			child: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
				child: Row(
					children: [
						CircleAvatar(
							radius: 18.0,
							backgroundColor: color.withValues(alpha: 0.18),
							child: Icon(
								PresentacionRol.icono(rol),
								color: color,
								size: 20.0,
							),
						),
						const SizedBox(width: 10.0),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										nombreUsuario,
										style: const TextStyle(fontWeight: FontWeight.w600),
										overflow: TextOverflow.ellipsis,
									),
									Text(
										nombreTienda,
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
											color: PosiaColors.neutro.withValues(alpha: 0.7),
										),
										overflow: TextOverflow.ellipsis,
									),
								],
							),
						),
						InsigniaRol(rol: rol, compacto: true),
						if (alAbrirMiCuenta != null) ...[
							const SizedBox(width: 4.0),
							IconButton(
								icon: const Icon(Icons.account_circle_outlined, size: 22.0),
								tooltip: 'Mi cuenta',
								onPressed: alAbrirMiCuenta,
							),
						],
						const SizedBox(width: 4.0),
						IconButton(
							icon: const Icon(Icons.logout, size: 20.0),
							tooltip: 'Cerrar sesión',
							onPressed: alCerrarSesion,
						),
					],
				),
			),
		);
	}
}
