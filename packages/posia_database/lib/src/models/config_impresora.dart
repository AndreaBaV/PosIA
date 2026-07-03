/// Configuracion de impresora de tickets del dispositivo.
library;

/// Preferencias de impresion local.
class ConfigImpresora {
	const ConfigImpresora({
		required this.modo,
		required this.hostRed,
		required this.puertoRed,
		this.abrirCajonAlCobrar = false,
		this.nombreImpresoraUsb = '',
		this.anchoRolloMm = 80,
	});

	/// Modo: archivo, red, ambos o usb_windows.
	final String modo;

	/// IP o hostname de impresora termica (modo red / ambos).
	final String hostRed;

	/// Puerto TCP (default 9100).
	final int puertoRed;

	/// Abre cajon de dinero al cobrar en efectivo o mixto.
	final bool abrirCajonAlCobrar;

	/// Nombre de impresora USB tal como aparece en Windows (modo usb_windows).
	final String nombreImpresoraUsb;

	/// Ancho del rollo termico en milimetros (58 o 80).
	final int anchoRolloMm;
}
