/// Evaluacion de acceso al panel admin con roles personalizados.
library;

import '../constants/permisos_admin.dart';
import '../enums/rol_usuario.dart';
import '../models/rol_personalizado.dart';
import '../models/usuario.dart';

/// Reglas de visibilidad del panel admin segun rol base y personalizado.
class PoliticaAccesoAdmin {
	const PoliticaAccesoAdmin._();

	static bool esAdministradorGlobal(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador;

	static bool puedeAccederPanelAdmin(
		Usuario usuario,
		RolPersonalizado? rolPersonalizado,
	) {
		if (esAdministradorGlobal(usuario)) {
			return true;
		}
		if (rolPersonalizado != null && rolPersonalizado.activo) {
			return rolPersonalizado.permisosAdmin.isNotEmpty;
		}
		return usuario.rol != RolUsuario.empleado;
	}

	static bool puedeVerSeccionAdmin(
		Usuario usuario,
		RolPersonalizado? rolPersonalizado,
		String clave,
	) {
		if (clave == PermisosAdmin.miCuenta) {
			return true;
		}
		if (esAdministradorGlobal(usuario)) {
			return true;
		}
		if (rolPersonalizado != null && rolPersonalizado.activo) {
			return rolPersonalizado.tienePermiso(clave);
		}
		if (usuario.rol == RolUsuario.empleado) {
			return false;
		}
		if (usuario.rol == RolUsuario.supervisor) {
			return !{'tiendas', 'sync', 'config', PermisosAdmin.rolesPersonalizados}
				.contains(clave);
		}
		return true;
	}

	/// null = sin restriccion por categoria; set vacio no deberia ocurrir.
	static Set<String>? categoriasProductoPermitidas(
		Usuario usuario,
		RolPersonalizado? rolPersonalizado,
	) {
		if (esAdministradorGlobal(usuario)) {
			return null;
		}
		if (rolPersonalizado == null || !rolPersonalizado.activo) {
			return null;
		}
		if (!rolPersonalizado.restringeCategoriasProducto) {
			return null;
		}
		return rolPersonalizado.categoriasPermitidas.toSet();
	}

	static bool puedeEditarProductoEnCategoria(
		Usuario usuario,
		RolPersonalizado? rolPersonalizado,
		String? categoriaId,
	) {
		if (esAdministradorGlobal(usuario)) {
			return true;
		}
		if (rolPersonalizado == null || !rolPersonalizado.activo) {
			return true;
		}
		return rolPersonalizado.puedeEditarCategoriaProducto(categoriaId);
	}

	static bool puedeGestionarRolesPersonalizados(Usuario usuario) =>
		esAdministradorGlobal(usuario);
}
