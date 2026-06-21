/// Colores e iconos de presentacion por rol de usuario.
library;

import 'package:flutter/material.dart';
import 'package:posia_core/posia_core.dart';

/// Recursos visuales para distinguir roles en la UI.
class PresentacionRol {
	const PresentacionRol._();

	static Color color(RolUsuario rol) {
		switch (rol) {
			case RolUsuario.administrador:
				return const Color(0xFF6A1B9A);
			case RolUsuario.supervisor:
				return const Color(0xFF1565C0);
			case RolUsuario.empleado:
				return const Color(0xFF2E7D32);
		}
	}

	static IconData icono(RolUsuario rol) {
		switch (rol) {
			case RolUsuario.administrador:
				return Icons.admin_panel_settings;
			case RolUsuario.supervisor:
				return Icons.supervisor_account;
			case RolUsuario.empleado:
				return Icons.person;
		}
	}
}
