/// Normaliza la foto de un producto antes de subirla a la tienda en linea.
///
/// El iPhone guarda por defecto en HEIC/HEIF, que el endpoint
/// `/v1/admin/imagenes` no acepta. En vez de rechazarla, se decodifica con
/// el codec nativo (ImageIO en iOS) y se reencodea a JPEG.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

/// Lado mas largo que se conserva al convertir. Suficiente para el catalogo
/// y mantiene el JPEG resultante muy por debajo del limite de 5 MB.
const int ladoMaximoImagenProductoPx = 1600;

const int _calidadJpegInicial = 85;
const int _calidadJpegMinima = 45;

/// Formato de origen, antes de convertirlo a algo que acepte el servidor.
enum FormatoOrigenImagenProducto { jpeg, png, webp, heic, desconocido }

/// Foto lista para POST /v1/admin/imagenes.
class ImagenProductoNormalizada {
	const ImagenProductoNormalizada({required this.bytes, required this.tipo});

	final Uint8List bytes;
	final TipoImagenProducto tipo;
}

/// Detecta el formato por firma de bytes (prioridad) y, si no alcanza, por
/// la extension del nombre. El iPhone a veces entrega `IMG_1234.HEIC` y otras
/// un nombre sin extension; la firma cubre ambos casos.
FormatoOrigenImagenProducto detectarFormatoImagenProducto({
	required List<int> bytes,
	required String nombreArchivo,
}) {
	final porFirma = _formatoPorFirma(bytes);
	if (porFirma != FormatoOrigenImagenProducto.desconocido) {
		return porFirma;
	}
	return _formatoPorNombre(nombreArchivo);
}

/// Prepara [bytes] para subirlos: JPG/PNG/WEBP se dejan igual si caben;
/// HEIC/HEIF y cualquier otro formato decodificable se convierten a JPEG.
Future<ImagenProductoNormalizada?> prepararImagenProducto({
	required Uint8List bytes,
	required String nombreArchivo,
}) async {
	if (bytes.isEmpty) {
		return null;
	}
	final formato = detectarFormatoImagenProducto(
		bytes: bytes,
		nombreArchivo: nombreArchivo,
	);
	final tipoDirecto = _tipoAceptado(formato);
	if (tipoDirecto != null &&
			bytes.length <= TAMANO_MAXIMO_IMAGEN_PRODUCTO_BYTES) {
		return ImagenProductoNormalizada(bytes: bytes, tipo: tipoDirecto);
	}

	final jpeg = await convertirImagenProductoAJpeg(bytes);
	if (jpeg == null || jpeg.isEmpty) {
		return null;
	}
	return ImagenProductoNormalizada(
		bytes: jpeg,
		tipo: TipoImagenProducto.jpeg,
	);
}

/// Decodifica [bytes] (HEIC incluido en iOS) y los reencodea a JPEG.
Future<Uint8List?> convertirImagenProductoAJpeg(Uint8List bytes) async {
	final imagen = await _decodificar(bytes);
	if (imagen == null) {
		return null;
	}
	final ajustada = _caberEnLado(imagen, ladoMaximoImagenProductoPx);
	var calidad = _calidadJpegInicial;
	var jpeg = Uint8List.fromList(img.encodeJpg(ajustada, quality: calidad));
	while (jpeg.length > TAMANO_MAXIMO_IMAGEN_PRODUCTO_BYTES &&
			calidad > _calidadJpegMinima) {
		calidad -= 10;
		jpeg = Uint8List.fromList(img.encodeJpg(ajustada, quality: calidad));
	}
	if (jpeg.length > TAMANO_MAXIMO_IMAGEN_PRODUCTO_BYTES) {
		final masChica = _caberEnLado(ajustada, ladoMaximoImagenProductoPx ~/ 2);
		jpeg = Uint8List.fromList(
			img.encodeJpg(masChica, quality: _calidadJpegMinima),
		);
	}
	return jpeg;
}

TipoImagenProducto? _tipoAceptado(FormatoOrigenImagenProducto formato) {
	switch (formato) {
		case FormatoOrigenImagenProducto.jpeg:
			return TipoImagenProducto.jpeg;
		case FormatoOrigenImagenProducto.png:
			return TipoImagenProducto.png;
		case FormatoOrigenImagenProducto.webp:
			return TipoImagenProducto.webp;
		case FormatoOrigenImagenProducto.heic:
		case FormatoOrigenImagenProducto.desconocido:
			return null;
	}
}

FormatoOrigenImagenProducto _formatoPorFirma(List<int> bytes) {
	if (bytes.length >= 3 &&
			bytes[0] == 0xFF &&
			bytes[1] == 0xD8 &&
			bytes[2] == 0xFF) {
		return FormatoOrigenImagenProducto.jpeg;
	}
	if (bytes.length >= 8 &&
			bytes[0] == 0x89 &&
			bytes[1] == 0x50 &&
			bytes[2] == 0x4E &&
			bytes[3] == 0x47 &&
			bytes[4] == 0x0D &&
			bytes[5] == 0x0A &&
			bytes[6] == 0x1A &&
			bytes[7] == 0x0A) {
		return FormatoOrigenImagenProducto.png;
	}
	if (bytes.length >= 12 &&
			bytes[0] == 0x52 &&
			bytes[1] == 0x49 &&
			bytes[2] == 0x46 &&
			bytes[3] == 0x46 &&
			bytes[8] == 0x57 &&
			bytes[9] == 0x45 &&
			bytes[10] == 0x42 &&
			bytes[11] == 0x50) {
		return FormatoOrigenImagenProducto.webp;
	}
	if (_esContenedorHeif(bytes)) {
		return FormatoOrigenImagenProducto.heic;
	}
	return FormatoOrigenImagenProducto.desconocido;
}

/// ISO-BMFF con brand HEIC/HEIF (`ftyp` en el offset 4).
bool _esContenedorHeif(List<int> bytes) {
	if (bytes.length < 12) {
		return false;
	}
	if (bytes[4] != 0x66 ||
			bytes[5] != 0x74 ||
			bytes[6] != 0x79 ||
			bytes[7] != 0x70) {
		return false;
	}
	final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
	const marcasHeif = {
		'heic',
		'heix',
		'heif',
		'heis',
		'heim',
		'hevc',
		'hevx',
		'mif1',
		'msf1',
	};
	return marcasHeif.contains(brand);
}

FormatoOrigenImagenProducto _formatoPorNombre(String nombreArchivo) {
	final punto = nombreArchivo.lastIndexOf('.');
	if (punto < 0 || punto == nombreArchivo.length - 1) {
		return FormatoOrigenImagenProducto.desconocido;
	}
	switch (nombreArchivo.substring(punto + 1).toLowerCase()) {
		case 'jpg':
		case 'jpeg':
			return FormatoOrigenImagenProducto.jpeg;
		case 'png':
			return FormatoOrigenImagenProducto.png;
		case 'webp':
			return FormatoOrigenImagenProducto.webp;
		case 'heic':
		case 'heif':
		case 'hif':
			return FormatoOrigenImagenProducto.heic;
		default:
			return FormatoOrigenImagenProducto.desconocido;
	}
}

Future<img.Image?> _decodificar(Uint8List bytes) async {
	final porPaquete = img.decodeImage(bytes);
	if (porPaquete != null) {
		return porPaquete;
	}
	return _decodificarConCodecNativo(bytes);
}

/// En iOS, ImageIO abre HEIC. `package:image` no lo hace.
Future<img.Image?> _decodificarConCodecNativo(Uint8List bytes) async {
	ui.Image? nativa;
	try {
		final codec = await ui.instantiateImageCodec(bytes);
		final frame = await codec.getNextFrame();
		nativa = frame.image;
		final data = await nativa.toByteData(format: ui.ImageByteFormat.rawRgba);
		if (data == null) {
			return null;
		}
		return img.Image.fromBytes(
			width: nativa.width,
			height: nativa.height,
			bytes: data.buffer,
			bytesOffset: data.offsetInBytes,
			numChannels: 4,
			order: img.ChannelOrder.rgba,
		);
	} on Object {
		return null;
	} finally {
		nativa?.dispose();
	}
}

img.Image _caberEnLado(img.Image imagen, int ladoMaximo) {
	final lado = imagen.width > imagen.height ? imagen.width : imagen.height;
	if (lado <= ladoMaximo) {
		return imagen;
	}
	final escala = ladoMaximo / lado;
	return img.copyResize(
		imagen,
		width: (imagen.width * escala).round().clamp(1, ladoMaximo),
		height: (imagen.height * escala).round().clamp(1, ladoMaximo),
		interpolation: img.Interpolation.linear,
	);
}
