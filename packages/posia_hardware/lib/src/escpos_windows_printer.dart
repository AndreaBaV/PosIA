/// Impresora termica ESC/POS conectada por USB a Windows.
///
/// Envia los bytes crudos al spooler de Windows usando la API winspool.drv
/// (OpenPrinter, StartDocPrinter, WritePrinter, EndDocPrinter) via FFI.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-07-02 09:20:00 (UTC-6)
/// Ultima modificacion: 2026-07-02 16:10:00 (UTC-6)
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'escpos_raster.dart';
import 'receipt_printer.dart';

/// Envia ticket ESC/POS a impresora USB instalada en Windows.
class EscPosWindowsPrinter implements ReceiptPrinter {
	EscPosWindowsPrinter({
		required this.nombreImpresora,
		this.anchoRolloMm = 80,
	});

	/// Nombre exacto de la impresora tal como aparece en el panel de Windows.
	final String nombreImpresora;

	/// Ancho del rollo termico (58 o 80 mm).
	final int anchoRolloMm;

	@override
	Future<void> imprimirTicket(
		String contenido, {
		Uint8List? logoPng,
		Uint8List? imagenTicketPng,
	}) async {
		if (!Platform.isWindows) {
			throw UnsupportedError(
				'EscPosWindowsPrinter solo funciona en Windows',
			);
		}
		if (nombreImpresora.trim().isEmpty) {
			throw StateError('Nombre de impresora USB no configurado');
		}

		final bytes = construirBytesEscPosTicket(
			contenido: contenido,
			logoPng: logoPng,
			imagenTicketPng: imagenTicketPng,
			anchoRolloMm: anchoRolloMm,
			codificarTexto: _codificarTexto,
		);

		enviarBytesCrudos(
			nombreImpresora: nombreImpresora,
			nombreDocumento: 'POSIA ticket',
			datos: Uint8List.fromList(bytes),
		);
	}

	List<int> _codificarTexto(String texto) {
		try {
			return latin1.encode(texto);
		} catch (_) {
			return utf8.encode(texto);
		}
	}
}

/// Envia un bloque de bytes crudos al spooler de la impresora indicada.
///
/// Se expone como funcion top-level para que el driver de cajon USB pueda
/// reutilizarla sin tener que instanciar la impresora completa.
void enviarBytesCrudos({
	required String nombreImpresora,
	required String nombreDocumento,
	required Uint8List datos,
}) {
	if (!Platform.isWindows) {
		throw UnsupportedError(
			'enviarBytesCrudos solo funciona en Windows',
		);
	}
	final punteroNombre = nombreImpresora.toNativeUtf16();
	final punteroDatatype = 'RAW'.toNativeUtf16();
	final punteroDocNombre = nombreDocumento.toNativeUtf16();
	final punteroHandle = calloc<HANDLE>();
	final punteroDocInfo = calloc<DOC_INFO_1>();
	final punteroEscritos = calloc<DWORD>();
	Pointer<Uint8>? bufferDatos;
	try {
		final abierto = OpenPrinter(punteroNombre, punteroHandle, nullptr);
		if (abierto == 0) {
			throw StateError(
				'No se pudo abrir la impresora "$nombreImpresora" '
				'(codigo Win32 ${GetLastError()})',
			);
		}
		final handle = punteroHandle.value;
		try {
			punteroDocInfo.ref
				..pDocName = punteroDocNombre
				..pOutputFile = nullptr
				..pDatatype = punteroDatatype;
			final trabajoId = StartDocPrinter(handle, 1, punteroDocInfo);
			if (trabajoId == 0) {
				throw StateError(
					'StartDocPrinter fallo (codigo Win32 ${GetLastError()})',
				);
			}
			try {
				if (StartPagePrinter(handle) == 0) {
					throw StateError(
						'StartPagePrinter fallo (codigo Win32 ${GetLastError()})',
					);
				}
				bufferDatos = calloc<Uint8>(datos.length);
				for (var i = 0; i < datos.length; i++) {
					bufferDatos[i] = datos[i];
				}
				final ok = WritePrinter(
					handle,
					bufferDatos.cast(),
					datos.length,
					punteroEscritos,
				);
				if (ok == 0) {
					throw StateError(
						'WritePrinter fallo (codigo Win32 ${GetLastError()})',
					);
				}
				EndPagePrinter(handle);
			} finally {
				EndDocPrinter(handle);
			}
		} finally {
			ClosePrinter(handle);
		}
	} finally {
		if (bufferDatos != null) {
			calloc.free(bufferDatos);
		}
		calloc.free(punteroEscritos);
		calloc.free(punteroDocInfo);
		calloc.free(punteroHandle);
		calloc.free(punteroDocNombre);
		calloc.free(punteroDatatype);
		calloc.free(punteroNombre);
	}
}
