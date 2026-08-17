import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/util/normalizador_imagen_producto.dart';
import 'package:posia_sync/posia_sync.dart';

Uint8List _pngRojo({int ancho = 8, int alto = 8}) {
	final imagen = img.Image(width: ancho, height: alto);
	img.fill(imagen, color: img.ColorRgb8(200, 30, 30));
	return Uint8List.fromList(img.encodePng(imagen));
}

Uint8List _jpegAzul({int ancho = 8, int alto = 8}) {
	final imagen = img.Image(width: ancho, height: alto);
	img.fill(imagen, color: img.ColorRgb8(30, 30, 200));
	return Uint8List.fromList(img.encodeJpg(imagen, quality: 90));
}

Uint8List _bmpVerde() {
	final imagen = img.Image(width: 8, height: 8);
	img.fill(imagen, color: img.ColorRgb8(30, 200, 30));
	return Uint8List.fromList(img.encodeBmp(imagen));
}

Uint8List _cabeceraHeic({String brand = 'heic'}) {
	final bytes = Uint8List(16);
	bytes[0] = 0;
	bytes[1] = 0;
	bytes[2] = 0;
	bytes[3] = 16;
	bytes[4] = 0x66; // f
	bytes[5] = 0x74; // t
	bytes[6] = 0x79; // y
	bytes[7] = 0x70; // p
	final marca = brand.codeUnits;
	for (var i = 0; i < 4; i++) {
		bytes[8 + i] = marca[i];
	}
	return bytes;
}

void main() {
	group('detectarFormatoImagenProducto', () {
		test('prioriza la firma JPEG aunque el nombre diga HEIC', () {
			final jpeg = _jpegAzul();
			expect(
				detectarFormatoImagenProducto(
					bytes: jpeg,
					nombreArchivo: 'IMG_0001.HEIC',
				),
				FormatoOrigenImagenProducto.jpeg,
			);
		});

		test('reconoce HEIC por firma ftyp aunque no tenga extension', () {
			expect(
				detectarFormatoImagenProducto(
					bytes: _cabeceraHeic(),
					nombreArchivo: 'image',
				),
				FormatoOrigenImagenProducto.heic,
			);
			expect(
				detectarFormatoImagenProducto(
					bytes: _cabeceraHeic(brand: 'mif1'),
					nombreArchivo: 'foto',
				),
				FormatoOrigenImagenProducto.heic,
			);
		});

		test('reconoce HEIC/HEIF por extension si no hay firma', () {
			const vacios = <int>[1, 2, 3, 4];
			expect(
				detectarFormatoImagenProducto(
					bytes: vacios,
					nombreArchivo: 'IMG_1234.HEIC',
				),
				FormatoOrigenImagenProducto.heic,
			);
			expect(
				detectarFormatoImagenProducto(
					bytes: vacios,
					nombreArchivo: 'foto.heif',
				),
				FormatoOrigenImagenProducto.heic,
			);
			expect(
				detectarFormatoImagenProducto(
					bytes: vacios,
					nombreArchivo: 'captura.hif',
				),
				FormatoOrigenImagenProducto.heic,
			);
		});

		test('reconoce PNG y WEBP por firma', () {
			expect(
				detectarFormatoImagenProducto(
					bytes: _pngRojo(),
					nombreArchivo: 'x.bin',
				),
				FormatoOrigenImagenProducto.png,
			);
			final webp = Uint8List.fromList([
				0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0,
				0x57, 0x45, 0x42, 0x50,
			]);
			expect(
				detectarFormatoImagenProducto(
					bytes: webp,
					nombreArchivo: 'x.bin',
				),
				FormatoOrigenImagenProducto.webp,
			);
		});
	});

	group('prepararImagenProducto', () {
		test('deja pasar JPEG y PNG que ya acepta el servidor', () async {
			final jpeg = _jpegAzul();
			final png = _pngRojo();

			final listaJpeg = await prepararImagenProducto(
				bytes: jpeg,
				nombreArchivo: 'foto.jpg',
			);
			expect(listaJpeg, isNotNull);
			expect(listaJpeg!.tipo, TipoImagenProducto.jpeg);
			expect(listaJpeg.bytes, jpeg);

			final listaPng = await prepararImagenProducto(
				bytes: png,
				nombreArchivo: 'foto.png',
			);
			expect(listaPng, isNotNull);
			expect(listaPng!.tipo, TipoImagenProducto.png);
			expect(listaPng.bytes, png);
		});

		test('convierte un formato no aceptado (BMP) a JPEG', () async {
			final bmp = _bmpVerde();
			final lista = await prepararImagenProducto(
				bytes: bmp,
				nombreArchivo: 'foto.bmp',
			);
			expect(lista, isNotNull);
			expect(lista!.tipo, TipoImagenProducto.jpeg);
			expect(
				detectarFormatoImagenProducto(
					bytes: lista.bytes,
					nombreArchivo: 'salida.jpg',
				),
				FormatoOrigenImagenProducto.jpeg,
			);
			final decodificada = img.decodeJpg(lista.bytes);
			expect(decodificada, isNotNull);
			expect(decodificada!.width, 8);
			expect(decodificada.height, 8);
		});

		test('convierte una foto con nombre HEIC en vez de rechazarla', () async {
			// El iPhone manda .HEIC; si el codec nativo no esta (CI), el BMP
			// con ese nombre sigue el mismo camino: no se rechaza, se convierte.
			final bmp = _bmpVerde();
			final lista = await prepararImagenProducto(
				bytes: bmp,
				nombreArchivo: 'IMG_0001.HEIC',
			);
			expect(lista, isNotNull);
			expect(lista!.tipo, TipoImagenProducto.jpeg);
			expect(img.decodeJpg(lista.bytes), isNotNull);
		});

		test('no sube un HEIC corrupto: si no se puede convertir, aborta', () async {
			final lista = await prepararImagenProducto(
				bytes: _cabeceraHeic(),
				nombreArchivo: 'IMG_0001.HEIC',
			);
			expect(lista, isNull);
		});
	});

	test('convertirImagenProductoAJpeg reencodea PNG y acota el lado largo', () async {
		final png = _pngRojo(ancho: 2400, alto: 1200);
		final jpeg = await convertirImagenProductoAJpeg(png);
		expect(jpeg, isNotNull);
		expect(
			detectarFormatoImagenProducto(bytes: jpeg!, nombreArchivo: 'x.jpg'),
			FormatoOrigenImagenProducto.jpeg,
		);
		final decodificada = img.decodeJpg(jpeg);
		expect(decodificada, isNotNull);
		expect(decodificada!.width, ladoMaximoImagenProductoPx);
		expect(decodificada.height, 800);
		expect(jpeg.length, lessThan(TAMANO_MAXIMO_IMAGEN_PRODUCTO_BYTES));
	});
}
