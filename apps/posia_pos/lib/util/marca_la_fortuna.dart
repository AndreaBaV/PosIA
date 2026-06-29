/// Logo de marca La Fortuna desde assets de la aplicacion.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Rutas de assets de marca.
abstract final class MarcaLaFortunaAssets {
	static const logoTicket = 'assets/branding/logo_ticket.png';
	static const logoCompleto = 'assets/branding/logo_la_fortuna.png';
	static const marca = 'assets/branding/logo_marca.png';
	static const appIcon = 'assets/branding/app_icon.png';
}

/// Carga el PNG optimizado para tickets termicos y PDF.
Future<Uint8List> cargarLogoTicketMarca() {
	return rootBundle.load(MarcaLaFortunaAssets.logoTicket).then((data) => data.buffer.asUint8List());
}

/// Carga el logo completo con tipografia.
Future<Uint8List> cargarLogoCompletoMarca() {
	return rootBundle.load(MarcaLaFortunaAssets.logoCompleto).then((data) => data.buffer.asUint8List());
}
