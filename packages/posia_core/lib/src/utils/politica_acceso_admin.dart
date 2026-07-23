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
		// Todos pueden abrir el panel: aunque un vendedor no administre nada, debe
		// alcanzar Sincronización con el hub y Configuración (impresora, sync). El
		// menú se filtra por sección, así que solo verá lo que su rol permite.
		return true;
	}

	static bool puedeVerSeccionAdmin(
		Usuario usuario,
		RolPersonalizado? rolPersonalizado,
		String clave,
	) {
		// Mi cuenta, Sincronización con el hub y Configuración son visibles para
		// TODOS los usuarios: cualquiera debe poder ver el estado de la nube,
		// forzar un sync o ajustar la impresora/dispositivo sin depender del admin.
		if (clave == PermisosAdmin.miCuenta ||
			clave == PermisosAdmin.sync ||
			clave == PermisosAdmin.config) {
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

	/// Indica si el usuario puede aplicar descuentos manuales en caja.
	static bool puedeAplicarDescuentoEnCaja(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador ||
		usuario.rol == RolUsuario.supervisor;

	/// Indica si el usuario puede editar precios manualmente en caja.
	static bool puedeEditarPrecioEnCaja(Usuario usuario) =>
		usuario.rol == RolUsuario.administrador;
}
