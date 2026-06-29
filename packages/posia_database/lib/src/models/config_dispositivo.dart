/// Configuracion local de tienda y caja del dispositivo.
library;

/// Identidad operativa persistida en app_config.
class ConfigDispositivo {
	const ConfigDispositivo({
		required this.tiendaId,
		required this.cajaId,
		this.nombreCaja,
	});

	final String tiendaId;
	final String cajaId;
	final String? nombreCaja;
}
