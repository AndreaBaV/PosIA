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
		this.compacto = false,
		super.key,
	});

	final String nombreUsuario;
	final RolUsuario rol;
	final String nombreTienda;
	final VoidCallback alCerrarSesion;
	final VoidCallback? alAbrirMiCuenta;
	final bool compacto;

	@override
	Widget build(BuildContext context) {
		if (compacto) {
			return SafeArea(
				bottom: false,
				child: Material(
					color: Theme.of(context).colorScheme.surfaceContainerLow,
					child: SizedBox(
						height: 36.0,
						child: Padding(
							padding: const EdgeInsets.symmetric(horizontal: 8.0),
							child: Row(
								children: [
									Expanded(
										child: Text(
											nombreTienda,
											style: Theme.of(context).textTheme.bodySmall?.copyWith(
												fontWeight: FontWeight.w600,
											),
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
										),
									),
									_PopupMenuSesion(
										nombreUsuario: nombreUsuario,
										rol: rol,
										alAbrirMiCuenta: alAbrirMiCuenta,
										alCerrarSesion: alCerrarSesion,
									),
								],
							),
						),
					),
				),
			);
		}
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
										maxLines: 1,
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

class _PopupMenuSesion extends StatelessWidget {
	const _PopupMenuSesion({
		required this.nombreUsuario,
		required this.rol,
		required this.alCerrarSesion,
		this.alAbrirMiCuenta,
	});

	final String nombreUsuario;
	final RolUsuario rol;
	final VoidCallback alCerrarSesion;
	final VoidCallback? alAbrirMiCuenta;

	@override
	Widget build(BuildContext context) {
		return PopupMenuButton<String>(
			icon: const Icon(Icons.more_vert, size: 22.0),
			tooltip: 'Cuenta',
			onSelected: (valor) {
				switch (valor) {
					case 'cuenta':
						alAbrirMiCuenta?.call();
					case 'salir':
						alCerrarSesion();
				}
			},
			itemBuilder: (context) => [
				PopupMenuItem<String>(
					enabled: false,
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								nombreUsuario,
								style: const TextStyle(fontWeight: FontWeight.w600),
								maxLines: 1,
								overflow: TextOverflow.ellipsis,
							),
							const SizedBox(height: 2.0),
							InsigniaRol(rol: rol, compacto: true),
						],
					),
				),
				if (alAbrirMiCuenta != null)
					const PopupMenuItem(
						value: 'cuenta',
						child: ListTile(
							leading: Icon(Icons.account_circle_outlined),
							title: Text('Mi cuenta'),
							contentPadding: EdgeInsets.zero,
							dense: true,
						),
					),
				const PopupMenuItem(
					value: 'salir',
					child: ListTile(
						leading: Icon(Icons.logout, color: PosiaColors.cancelar),
						title: Text('Cerrar sesión'),
						contentPadding: EdgeInsets.zero,
						dense: true,
					),
				),
			],
		);
	}
}
