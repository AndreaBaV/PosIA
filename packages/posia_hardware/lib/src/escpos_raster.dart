/// Convierte PNG a raster ESC/POS para impresoras termicas.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ancho maximo tipico para impresora de 58 mm (~384 px).
const int anchoMaximoLogoEscPos = 384;

/// Ancho util en pixeles para rollo de 80 mm (~576 px a 203 dpi).
const int anchoMaximoTicketEscPos80mm = 576;

/// Ancho util en pixeles para rollo de 58 mm.
const int anchoMaximoTicketEscPos58mm = 384;

int anchoMaximoTicketEscPos(int anchoRolloMm) {
	return anchoRolloMm == 80
		? anchoMaximoTicketEscPos80mm
		: anchoMaximoTicketEscPos58mm;
}

/// Genera bytes ESC/POS (GS v 0) a partir de un PNG en escala de grises.
List<int> pngAEscPosRaster(
	Uint8List pngBytes, {
	int anchoMaximo = anchoMaximoLogoEscPos,
}) {
	final decoded = img.decodeImage(pngBytes);
	if (decoded == null) {
		return const [];
	}
	final resized = img.copyResize(
		decoded,
		width: anchoMaximo.clamp(1, decoded.width),
		interpolation: img.Interpolation.linear,
	);
	final ancho = resized.width;
	final alto = resized.height;
	final anchoBytes = (ancho + 7) ~/ 8;
	final raster = <int>[];

	for (var y = 0; y < alto; y++) {
		for (var xByte = 0; xByte < anchoBytes; xByte++) {
			var byte = 0;
			for (var bit = 0; bit < 8; bit++) {
				final x = (xByte * 8) + bit;
				if (x >= ancho) {
					continue;
				}
				final pixel = resized.getPixel(x, y);
				final luminancia = img.getLuminance(pixel);
				final alpha = pixel.a.toInt();
				final oscuro = alpha > 8 && luminancia < 0.85;
				if (oscuro) {
					byte |= 0x80 >> bit;
				}
			}
			raster.add(byte);
		}
	}

	return [
		0x1D,
		0x76,
		0x30,
		0x00,
		anchoBytes & 0xFF,
		(anchoBytes >> 8) & 0xFF,
		alto & 0xFF,
		(alto >> 8) & 0xFF,
		...raster,
	];
}

/// Arma el buffer ESC/POS raster a partir de un ticket PNG completo.
List<int> construirBytesEscPosTicket({
	required Uint8List imagenTicketPng,
	int anchoRolloMm = 80,
}) {
	if (imagenTicketPng.isEmpty) {
		throw ArgumentError('imagenTicketPng no puede estar vacio');
	}
	final anchoPx = anchoMaximoTicketEscPos(anchoRolloMm);
	return [
		0x1B,
		0x40,
		0x1B,
		0x61,
		0x01,
		...pngAEscPosRaster(imagenTicketPng, anchoMaximo: anchoPx),
		0x1B,
		0x61,
		0x00,
		0x0A,
		0x0A,
		0x0A,
		0x1D,
		0x56,
		0x00,
	];
}
