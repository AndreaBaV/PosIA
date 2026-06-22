/// Modelos del registro maestro de tenants (solo uso interno POSIA).
library;

/// Negocio cliente en el registro de plataforma.
class TenantRegistro {
	const TenantRegistro({
		required this.id,
		required this.nombre,
		this.contacto = '',
		this.email = '',
		this.telefono = '',
		this.activo = true,
		this.maxUsuarios = 15,
		this.maxTiendas = 5,
		this.notas = '',
		required this.creadoEn,
		this.provisionadoEnHub = false,
		this.provisionadoEn,
	});

	final String id;
	final String nombre;
	final String contacto;
	final String email;
	final String telefono;
	final bool activo;
	final int maxUsuarios;
	final int maxTiendas;
	final String notas;
	final String creadoEn;
	final bool provisionadoEnHub;
	final String? provisionadoEn;
}

/// Sucursal asociada a un tenant en el registro.
class TiendaRegistro {
	const TiendaRegistro({
		required this.id,
		required this.tenantId,
		required this.nombre,
		this.direccion = '',
		this.activa = true,
	});

	final String id;
	final String tenantId;
	final String nombre;
	final String direccion;
	final bool activa;
}

/// Usuario inicial para aprovisionar en el hub (PIN solo en registro local).
class UsuarioBootstrap {
	const UsuarioBootstrap({
		required this.id,
		required this.tenantId,
		required this.nombre,
		required this.codigo,
		required this.pinPlano,
		required this.rol,
		this.tiendaId,
		this.activo = true,
		this.provisionadoEnHub = false,
	});

	final String id;
	final String tenantId;
	final String nombre;
	final String codigo;

	/// PIN en claro: solo en SQLite del implementador; se hashea al publicar.
	final String pinPlano;
	final String rol;
	final String? tiendaId;
	final bool activo;
	final bool provisionadoEnHub;
}
