/// Cajon de dinero conectado a impresora USB Windows.
///
/// Envia el pulso ESC/POS "ESC p m t1 t2" a traves del spooler de Windows
/// hacia la impresora termica que tiene el cable RJ11/RJ12 del cajon.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-07-02 09:20:00 (UTC-6)
/// Ultima modificacion: 2026-07-02 09:20:00 (UTC-6)
library;

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'cash_drawer.dart';
import 'escpos_windows_printer.dart';

/// Pin del conector RJ que activa el solenoide del cajon.
enum PinCajonEscPos {
	/// Pin 2 (por defecto en la mayoria de cajones de POS).
	pin2,

	/// Pin 5 (algunos cajones usan este si el pin 2 no responde).
	pin5,
}

/// Abre el cajon usando la impresora USB Windows como puente ESC/POS.
class EscPosWindowsCashDrawer implements CashDrawer {
	EscPosWindowsCashDrawer({
		required this.nombreImpresora,
		this.pin = PinCajonEscPos.pin2,
		this.duracionOn = 25,
		this.duracionOff = 250,
	});

	final String nombreImpresora;
	final PinCajonEscPos pin;

	/// Tiempo ON del pulso (unidad = 2 ms). 25 -> ~50 ms.
	final int duracionOn;

	/// Tiempo OFF minimo antes del siguiente pulso (unidad = 2 ms).
	final int duracionOff;

	@override
	Future<void> abrir() async {
		if (!Platform.isWindows) {
			throw UnsupportedError(
				'EscPosWindowsCashDrawer solo funciona en Windows',
			);
		}
		if (nombreImpresora.trim().isEmpty) {
			return;
		}
		final m = pin == PinCajonEscPos.pin2 ? 0x00 : 0x01;
		final bytes = <int>[
			0x1B, 0x40, // ESC @: reset (por si la impresora quedo en modo grafico)
			0x1B, 0x70, m, duracionOn & 0xFF, duracionOff & 0xFF, // ESC p m t1 t2
		];
		enviarBytesCrudos(
			nombreImpresora: nombreImpresora,
			nombreDocumento: 'POSIA cajon',
			datos: Uint8List.fromList(bytes),
		);
	}
}
