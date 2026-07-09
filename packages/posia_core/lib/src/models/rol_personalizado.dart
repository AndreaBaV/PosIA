/// Rol personalizado con permisos granulares de administracion.
library;

/// Define que secciones del panel admin puede usar un usuario.
class RolPersonalizado {
	const RolPersonalizado({
		required this.id,
		required this.nombre,
		this.descripcion = '',
		required this.permisosAdmin,
		this.categoriasPermitidas = const [],
		required this.activo,
		this.tiendaId,
	});

	final String id;
	final String nombre;
	final String descripcion;

	/// Claves de [PermisosAdmin] habilitadas para este rol.
	final List<String> permisosAdmin;

	/// Categorias editables cuando tiene permiso [PermisosAdmin.productos].
	/// Vacio = todas las categorias (sin restriccion por categoria).
	final List<String> categoriasPermitidas;
	final bool activo;
	final String? tiendaId;

	bool tienePermiso(String clave) => permisosAdmin.contains(clave);

	bool get restringeCategoriasProducto =>
		tienePermiso('productos') && categoriasPermitidas.isNotEmpty;

	bool puedeEditarCategoriaProducto(String? categoriaId) {
		if (!restringeCategoriasProducto) {
			return true;
		}
		if (categoriaId == null || categoriaId.isEmpty) {
			return false;
		}
		return categoriasPermitidas.contains(categoriaId);
	}

	RolPersonalizado copiarCon({
		String? id,
		String? nombre,
		String? descripcion,
		List<String>? permisosAdmin,
		List<String>? categoriasPermitidas,
		bool? activo,
		String? tiendaId,
		bool limpiarTiendaId = false,
	}) {
		return RolPersonalizado(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			descripcion: descripcion ?? this.descripcion,
			permisosAdmin: permisosAdmin ?? this.permisosAdmin,
			categoriasPermitidas:
				categoriasPermitidas ?? this.categoriasPermitidas,
			activo: activo ?? this.activo,
			tiendaId: limpiarTiendaId ? null : (tiendaId ?? this.tiendaId),
		);
	}
}
