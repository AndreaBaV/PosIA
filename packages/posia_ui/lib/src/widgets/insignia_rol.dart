/// Insignia visual del rol de usuario autenticado.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

import '../utils/presentacion_rol.dart';

/// Chip compacto con color e icono segun rol.
class InsigniaRol extends StatelessWidget {
	const InsigniaRol({
		required this.rol,
		this.compacto = false,
		super.key,
	});

	final RolUsuario rol;
	final bool compacto;

	@override
	Widget build(BuildContext context) {
		final color = PresentacionRol.color(rol);
		final etiqueta = PermisosUsuario.etiquetaRol(rol);
		return Container(
			padding: EdgeInsets.symmetric(
				horizontal: compacto ? 8.0 : 12.0,
				vertical: compacto ? 4.0 : 6.0,
			),
			decoration: BoxDecoration(
				color: color.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(20.0),
				border: Border.all(color: color.withValues(alpha: 0.35)),
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(
						PresentacionRol.icono(rol),
						size: compacto ? 14.0 : 16.0,
						color: color,
					),
					const SizedBox(width: 6.0),
					Text(
						etiqueta,
						style: TextStyle(
							color: color,
							fontWeight: FontWeight.w600,
							fontSize: compacto ? 12.0 : 13.0,
						),
					),
				],
			),
		);
	}
}
