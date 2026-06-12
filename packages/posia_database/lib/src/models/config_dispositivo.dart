/// Configuracion local de tenant, tienda y caja del dispositivo.
library;

/// Identidad operativa persistida en app_config.
class ConfigDispositivo {
	/// Crea configuracion del dispositivo POS.
	const ConfigDispositivo({
		required this.tenantId,
		required this.tiendaId,
		required this.cajaId,
		this.nombreCaja,
	});

	/// Tenant licenciado.
	final String tenantId;

	/// Sucursal donde opera esta caja.
	final String tiendaId;

	/// Identificador unico del dispositivo caja.
	final String cajaId;

	/// Etiqueta legible de la caja (opcional).
	final String? nombreCaja;
}
