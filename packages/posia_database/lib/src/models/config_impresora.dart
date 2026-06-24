/// Configuracion de impresora de tickets del dispositivo.
library;

/// Preferencias de impresion local.
class ConfigImpresora {
	const ConfigImpresora({
		required this.modo,
		required this.hostRed,
		required this.puertoRed,
		this.abrirCajonAlCobrar = false,
	});

	/// Modo: archivo, red o ambos.
	final String modo;

	/// IP o hostname de impresora termica.
	final String hostRed;

	/// Puerto TCP (default 9100).
	final int puertoRed;

	/// Abre cajon de dinero al cobrar en efectivo o mixto.
	final bool abrirCajonAlCobrar;
}
