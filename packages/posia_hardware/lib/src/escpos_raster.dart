/// Convierte PNG a raster ESC/POS para impresoras termicas.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ancho maximo tipico para impresora de 58 mm (~384 px).
const int anchoMaximoLogoEscPos = 384;

/// Ancho util en pixeles para rollo de 80 mm (~576 px a 203 dpi).
const int anchoMaximoTicketEscPos80mm = 576;

/// Ancho util en pixeles para rollo de 58 mm.
const int anchoMaximoTicketEscPos58mm = 384;

/// Alto maximo por comando GS v 0 en muchas impresoras termicas.
const int altoMaximoFragmentoEscPos = 512;

int anchoMaximoTicketEscPos(int anchoRolloMm) {
	return anchoRolloMm == 80
		? anchoMaximoTicketEscPos80mm
		: anchoMaximoTicketEscPos58mm;
}

/// Umbral de luminancia normalizada (0-1) para marcar un pixel como negro en termica.
const double _umbralLuminanciaImpresion = 0.85;

/// Usa buffers tipados (Uint8List/BytesBuilder) en vez de una lista dinamica
/// de enteros boxeados: para un ticket de 80mm son decenas de miles de bytes,
/// y evitar el boxing de cada entero (mas la copia via spread `...`) recorta
/// notoriamente el tiempo de CPU antes de mandar el ticket a la impresora.
Uint8List _rasterizarFragmento(img.Image fragmento) {
	final ancho = fragmento.width;
	final alto = fragmento.height;
	final anchoBytes = (ancho + 7) ~/ 8;
	final raster = Uint8List(anchoBytes * alto);
	var indice = 0;

	for (var y = 0; y < alto; y++) {
		for (var xByte = 0; xByte < anchoBytes; xByte++) {
			var byte = 0;
			for (var bit = 0; bit < 8; bit++) {
				final x = (xByte * 8) + bit;
				if (x >= ancho) {
					continue;
				}
				final pixel = fragmento.getPixel(x, y);
				final alpha = pixel.a.toInt();
				final oscuro = alpha > 8 &&
					img.getLuminanceNormalized(pixel) < _umbralLuminanciaImpresion;
				if (oscuro) {
					byte |= 0x80 >> bit;
				}
			}
			raster[indice] = byte;
			indice++;
		}
	}

	final resultado = Uint8List(8 + raster.length)
		..[0] = 0x1D
		..[1] = 0x76
		..[2] = 0x30
		..[3] = 0x00
		..[4] = anchoBytes & 0xFF
		..[5] = (anchoBytes >> 8) & 0xFF
		..[6] = alto & 0xFF
		..[7] = (alto >> 8) & 0xFF;
	resultado.setRange(8, resultado.length, raster);
	return resultado;
}

Uint8List _rasterizarEnFragmentos(
	img.Image imagen, {
	int altoMaximoFragmento = altoMaximoFragmentoEscPos,
}) {
	final constructor = BytesBuilder(copy: false);
	for (var y0 = 0; y0 < imagen.height; y0 += altoMaximoFragmento) {
		final altoFragmento = math.min(altoMaximoFragmento, imagen.height - y0);
		final fragmento = img.copyCrop(
			imagen,
			x: 0,
			y: y0,
			width: imagen.width,
			height: altoFragmento,
		);
		constructor.add(_rasterizarFragmento(fragmento));
	}
	return constructor.toBytes();
}

/// Genera bytes ESC/POS (GS v 0) a partir de un PNG en escala de grises.
Uint8List pngAEscPosRaster(
	Uint8List pngBytes, {
	int anchoMaximo = anchoMaximoLogoEscPos,
}) {
	final decoded = img.decodeImage(pngBytes);
	if (decoded == null) {
		return Uint8List(0);
	}

	final anchoObjetivo = anchoMaximo.clamp(1, decoded.width);
	final imagen = decoded.width == anchoObjetivo
		? decoded
		: img.copyResize(
			decoded,
			width: anchoObjetivo,
			interpolation: img.Interpolation.linear,
		);

	return _rasterizarEnFragmentos(imagen);
}

/// Arma el buffer ESC/POS raster a partir de un ticket PNG completo.
Uint8List construirBytesEscPosTicket({
	required Uint8List imagenTicketPng,
	int anchoRolloMm = 80,
}) {
	if (imagenTicketPng.isEmpty) {
		throw ArgumentError('imagenTicketPng no puede estar vacio');
	}
	final anchoPx = anchoMaximoTicketEscPos(anchoRolloMm);
	final constructor = BytesBuilder(copy: false)
		..add(const [0x1B, 0x40, 0x1B, 0x61, 0x00])
		..add(pngAEscPosRaster(imagenTicketPng, anchoMaximo: anchoPx))
		..add(const [
			0x1B,
			0x61,
			0x00,
			0x0A,
			0x0A,
			0x0A,
			0x0A,
			0x0A,
			0x1D,
			0x56,
			0x00,
		]);
	return constructor.toBytes();
}
