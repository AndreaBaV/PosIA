/// Reglas de permisos por rol de usuario.
library;

import '../enums/rol_usuario.dart';
import '../models/usuario.dart';

/// Evalua alcance operativo de un usuario autenticado.
class PermisosUsuario {
	const PermisosUsuario._();

	static bool esAdministrador(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador;

	static bool esSupervisor(Usuario usuario) =>
		usuario.rol == RolUsuario.supervisor;

	static bool esEmpleado(Usuario usuario) =>
		usuario.rol == RolUsuario.empleado;

	static bool puedeAccederPanelAdmin(Usuario usuario) => true;

	static bool puedeGestionarTodasLasTiendas(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador;

	static bool puedeGestionarTienda(Usuario usuario, String tiendaId) {
		if (usuario.rol == RolUsuario.administrador) {
			return true;
		}
		return usuario.rol == RolUsuario.supervisor && usuario.tiendaId == tiendaId;
	}

	static bool puedeGestionarUsuarios(Usuario usuario) =>
		usuario.rol != RolUsuario.empleado;

	static bool puedeGestionarUsuario(Usuario operador, Usuario objetivo) {
		if (operador.rol == RolUsuario.empleado) {
			return operador.id == objetivo.id;
		}
		if (operador.rol == RolUsuario.administrador) {
			return true;
		}
		if (operador.rol == RolUsuario.supervisor) {
			if (objetivo.rol == RolUsuario.administrador) {
				return false;
			}
			return objetivo.tiendaId == operador.tiendaId;
		}
		return false;
	}

	static bool puedeVerConfiguracionSistema(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador;

	static bool puedeGestionarTiendas(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador;

	static String etiquetaRol(RolUsuario rol) {
		switch (rol) {
			case RolUsuario.administrador:
				return 'Administrador';
			case RolUsuario.supervisor:
				return 'Supervisor';
			case RolUsuario.empleado:
				return 'Empleado';
		}
	}

	static String descripcionRol(RolUsuario rol) {
		switch (rol) {
			case RolUsuario.administrador:
				return 'Acceso completo a tiendas, usuarios y configuración';
			case RolUsuario.supervisor:
				return 'Gestiona inventario, ventas y personal de su tienda';
			case RolUsuario.empleado:
				return 'Opera la caja; acceso limitado en administración';
		}
	}
}
