/// Utilidad para enumerar impresoras instaladas en Windows.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-07-02 09:20:00 (UTC-6)
/// Ultima modificacion: 2026-07-02 09:20:00 (UTC-6)
library;

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Metadatos basicos de una impresora detectada por Windows.
class ImpresoraWindows {
	const ImpresoraWindows({
		required this.nombre,
		required this.puerto,
		required this.driver,
	});

	/// Nombre visible en Panel de Control (usado por OpenPrinter).
	final String nombre;

	/// Puerto donde Windows expone la impresora (USB001, LPT1, etc.).
	final String puerto;

	/// Driver instalado (informativo).
	final String driver;

	/// Indica si el puerto reportado corresponde a una conexion USB.
	bool get esUsb {
		final upper = puerto.toUpperCase();
		return upper.startsWith('USB') || upper.startsWith('WSD');
	}
}

/// Lista todas las impresoras locales y compartidas visibles para el usuario.
///
/// Retorna lista vacia en plataformas distintas de Windows.
List<ImpresoraWindows> enumerarImpresorasWindows() {
	if (!Platform.isWindows) {
		return const [];
	}
	final punteroNecesarios = calloc<DWORD>();
	final punteroDevueltos = calloc<DWORD>();
	final flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
	Pointer<Uint8>? buffer;
	try {
		// Primera llamada con buffer nulo para calcular el tamano requerido.
		EnumPrinters(
			flags,
			nullptr,
			2,
			nullptr,
			0,
			punteroNecesarios,
			punteroDevueltos,
		);
		final necesarios = punteroNecesarios.value;
		if (necesarios == 0) {
			return const [];
		}
		buffer = calloc<Uint8>(necesarios);
		final ok = EnumPrinters(
			flags,
			nullptr,
			2,
			buffer.cast(),
			necesarios,
			punteroNecesarios,
			punteroDevueltos,
		);
		if (ok == 0) {
			return const [];
		}
		final total = punteroDevueltos.value;
		if (total == 0) {
			return const [];
		}
		final resultados = <ImpresoraWindows>[];
		final base = buffer.cast<PRINTER_INFO_2>();
		for (var i = 0; i < total; i++) {
			final info = (base + i).ref;
			final nombre = info.pPrinterName.toDartString();
			final puerto = info.pPortName == nullptr ? '' : info.pPortName.toDartString();
			final driver = info.pDriverName == nullptr ? '' : info.pDriverName.toDartString();
			resultados.add(
				ImpresoraWindows(
					nombre: nombre,
					puerto: puerto,
					driver: driver,
				),
			);
		}
		resultados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
		return resultados;
	} finally {
		if (buffer != null) {
			calloc.free(buffer);
		}
		calloc.free(punteroDevueltos);
		calloc.free(punteroNecesarios);
	}
}
