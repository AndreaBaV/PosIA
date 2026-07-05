/// Renderizador nativo de tickets digitales a PNG.
///
/// Dibuja directamente sobre un bitmap con la libreria `image` (100% Dart),
/// sin depender de Pdfium/printing. Usa fuentes grandes (arial24 minimo) y
/// negro puro con doble trazo para que se imprima solido en impresoras
/// termicas de 80 mm (203 dpi).
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:posia_core/posia_core.dart';

/// Ancho en pixeles del ticket para rollo de 80 mm (~203 dpi).
const int anchoTicketBitmap80mm = 576;

/// Ancho en pixeles del ticket para rollo de 58 mm.
const int anchoTicketBitmap58mm = 384;

const int _padding = 12;

/// Interlineado por fuente. Se calcula segun el tamaño real de arial.
int _altoLinea(img.BitmapFont font) {
	if (identical(font, img.arial48)) return 56;
	if (identical(font, img.arial24)) return 30;
	return 18;
}

final img.ColorRgb8 _negro = img.ColorRgb8(0, 0, 0);
final img.ColorRgb8 _blanco = img.ColorRgb8(255, 255, 255);

/// Renderiza [contenido] como PNG usando la libreria image.
///
/// [logoPng] Logo de marca opcional para el encabezado.
/// [anchoRolloMm] 80 o 58; determina el ancho en pixeles del bitmap.
Uint8List renderizarTicketDigitalPng({
	required TicketDigitalContenido contenido,
	Uint8List? logoPng,
	int anchoRolloMm = 80,
}) {
	final ancho = anchoRolloMm == 80 ? anchoTicketBitmap80mm : anchoTicketBitmap58mm;
	final altoEstimado = _estimarAltoTicket(contenido, ancho);
	final image = img.Image(
		width: ancho,
		height: altoEstimado,
		numChannels: 3,
	);
	img.fill(image, color: _blanco);

	var y = _padding;

	// Logo centrado
	if (logoPng != null && logoPng.isNotEmpty) {
		final logoDecoded = img.decodePng(logoPng);
		if (logoDecoded != null) {
			final anchoLogoTarget = (ancho * 0.6).round().clamp(180, 340);
			final logoRes = img.copyResize(
				logoDecoded,
				width: anchoLogoTarget,
				interpolation: img.Interpolation.linear,
			);
			final logoAplanado = _aplastarSobreBlanco(logoRes);
			final xLogo = (ancho - logoAplanado.width) ~/ 2;
			img.compositeImage(image, logoAplanado, dstX: xLogo, dstY: y);
			y += logoAplanado.height + 8;
		}
	}

	y = _dibujarTextoCentrado(
		image,
		NOMBRE_COMERCIAL_APP.toUpperCase(),
		y: y,
		font: img.arial24,
	);
	y += 4;
	y = _dibujarTextoCentrado(
		image,
		_normalizar(contenido.tituloDocumento),
		y: y,
		font: img.arial48,
	);
	y = _dibujarTextoCentrado(
		image,
		_normalizar(contenido.subtituloDocumento),
		y: y,
		font: img.arial24,
	);
	if (contenido.etiquetaSecundaria != null) {
		y = _dibujarTextoCentrado(
			image,
			_normalizar(contenido.etiquetaSecundaria!),
			y: y,
			font: img.arial24,
		);
	}
	y += 6;
	// Barra acento gruesa centrada
	final xAcento = (ancho - 120) ~/ 2;
	img.fillRect(
		image,
		x1: xAcento,
		y1: y,
		x2: xAcento + 120,
		y2: y + 6,
		color: _negro,
	);
	y += 14;

	y = _dibujarTextoCentrado(
		image,
		_normalizar(contenido.nombreTienda),
		y: y,
		font: img.arial24,
	);
	if (contenido.direccionTienda != null &&
		contenido.direccionTienda!.trim().isNotEmpty) {
		y = _dibujarTextoCentrado(
			image,
			_normalizar(contenido.direccionTienda!.trim()),
			y: y,
			font: img.arial24,
		);
	}
	y += 6;
	_dibujarSeparador(image, y, ancho: ancho);
	y += 12;

	y = _dibujarFilaMeta(image, 'Folio', contenido.folio, y, ancho);
	y = _dibujarFilaMeta(image, 'Fecha', _formatearFecha(contenido.fecha), y, ancho);
	if (contenido.nombreCliente != null &&
		contenido.nombreCliente!.trim().isNotEmpty) {
		y = _dibujarFilaMeta(image, 'Cliente', contenido.nombreCliente!, y, ancho);
	}
	for (final entry in contenido.campos.entries) {
		y = _dibujarFilaMeta(image, entry.key, entry.value, y, ancho);
	}
	y += 6;
	_dibujarSeparador(image, y, ancho: ancho);
	y += 12;

	if (contenido.lineas.isNotEmpty) {
		// Encabezado tabla
		final xProd = _padding;
		final xImp = ancho - _padding;
		final etiquetaColumna = contenido.mostrarImportes ? 'IMPORTE' : 'CANT';
		_dibujarTexto(image, 'PRODUCTO',
			x: xProd, y: y, font: img.arial24);
		final wColumna = _medirTexto(etiquetaColumna, img.arial24);
		_dibujarTexto(image, etiquetaColumna,
			x: xImp - wColumna, y: y, font: img.arial24);
		y += _altoLinea(img.arial24) + 4;

		for (final linea in contenido.lineas) {
			final descripcion = _normalizar(linea.descripcion);
			final yInicioLinea = y;
			if (contenido.mostrarImportes) {
				final importeStr = formatearMoneda(linea.subtotal);
				final wImpLinea = _medirTexto(importeStr, img.arial24);
				final xTopeDescripcion = xImp - wImpLinea - 12;
				final anchoDescripcion = xTopeDescripcion - xProd;
				final lineasDescripcion = _envolverTexto(
					descripcion,
					font: img.arial24,
					anchoMax: anchoDescripcion,
				);
				for (final l in lineasDescripcion) {
					_dibujarTexto(image, l,
						x: xProd, y: y, font: img.arial24);
					y += _altoLinea(img.arial24);
				}
				_dibujarTexto(image, importeStr,
					x: xImp - _medirTexto(importeStr, img.arial24),
					y: yInicioLinea,
					font: img.arial24);
				final sub = '${_formatearCantidad(linea.cantidad)} x ${formatearMoneda(linea.precioUnitario)}';
				_dibujarTexto(image, sub,
					x: xProd, y: y, font: img.arial24);
				y += _altoLinea(img.arial24);
			} else {
				final cantidadStr = '${_formatearCantidad(linea.cantidad)} u.';
				final wCant = _medirTexto(cantidadStr, img.arial24);
				final xTopeDescripcion = xImp - wCant - 12;
				final anchoDescripcion = xTopeDescripcion - xProd;
				final lineasDescripcion = _envolverTexto(
					descripcion,
					font: img.arial24,
					anchoMax: anchoDescripcion,
				);
				for (final l in lineasDescripcion) {
					_dibujarTexto(image, l,
						x: xProd, y: y, font: img.arial24);
					y += _altoLinea(img.arial24);
				}
				_dibujarTexto(image, cantidadStr,
					x: xImp - wCant,
					y: yInicioLinea,
					font: img.arial24);
			}
			if (linea.descuentoLinea > 0) {
				_dibujarTexto(image, 'Desc. -${formatearMoneda(linea.descuentoLinea)}',
					x: xProd, y: y, font: img.arial24);
				y += _altoLinea(img.arial24);
			}
			y += 6;
		}

		y += 4;
		_dibujarSeparador(image, y, ancho: ancho, grueso: true);
		y += 12;
	} else {
		_dibujarSeparador(image, y, ancho: ancho, grueso: true);
		y += 12;
	}

	final xProd = _padding;
	final xImp = ancho - _padding;

	if (contenido.descuentoTicket > 0) {
		_dibujarTexto(image, 'Descuento',
			x: xProd, y: y, font: img.arial24);
		final txt = '-${formatearMoneda(contenido.descuentoTicket)}';
		_dibujarTexto(image, txt,
			x: xImp - _medirTexto(txt, img.arial24),
			y: y,
			font: img.arial24);
		y += _altoLinea(img.arial24) + 4;
	}

	// TOTAL destacado
	final etiquetaTotal = _normalizar(contenido.etiquetaTotal);
	final totalStr = contenido.mostrarImportes
		? formatearMoneda(contenido.total)
		: _formatearCantidad(contenido.total);
	_dibujarTexto(image, etiquetaTotal,
		x: xProd, y: y + 8, font: img.arial48);
	_dibujarTexto(image, totalStr,
		x: xImp - _medirTexto(totalStr, img.arial48),
		y: y,
		font: img.arial48);
	y += _altoLinea(img.arial48) + 8;

	if (contenido.montoRecibido != null) {
		y = _dibujarFilaMeta(image, 'Recibido',
			formatearMoneda(contenido.montoRecibido!), y, ancho);
	}
	if (contenido.cambio != null) {
		y = _dibujarFilaMeta(image, 'Cambio',
			formatearMoneda(contenido.cambio!), y, ancho);
	}
	y += 6;
	_dibujarSeparador(image, y, ancho: ancho);
	y += 12;

	for (final nota in contenido.notasPie) {
		y = _dibujarTextoCentrado(
			image,
			_normalizar(nota),
			y: y,
			font: img.arial24,
		);
		y += 4;
	}
	y += _padding * 2;

	// Recortar al alto real
	final altoFinal = y.clamp(200, altoEstimado);
	final recortado = img.copyCrop(
		image,
		x: 0,
		y: 0,
		width: ancho,
		height: altoFinal,
	);
	return Uint8List.fromList(img.encodePng(recortado));
}

int _estimarAltoTicket(TicketDigitalContenido contenido, int ancho) {
	var alto = 260; // logo + marca + titulo + subtitulo + acento
	alto += _altoLinea(img.arial24) * 2; // nombre tienda + direccion
	alto += 30; // separador + espacio
	alto += _altoLinea(img.arial24) * (2 + contenido.campos.length);
	if (contenido.nombreCliente != null) alto += _altoLinea(img.arial24);
	alto += 40; // encabezado tabla
	for (final linea in contenido.lineas) {
		final anchoUtil = ancho - (_padding * 2) - 100;
		final anchoDescripcion = anchoUtil > 0 ? anchoUtil : 200;
		final lineasEstimadas =
			(linea.descripcion.length * 12 / anchoDescripcion).ceil().clamp(1, 4);
		alto += _altoLinea(img.arial24) * (lineasEstimadas + 1);
		if (linea.descuentoLinea > 0) alto += _altoLinea(img.arial24);
		alto += 6;
	}
	alto += 40; // divisor total
	alto += _altoLinea(img.arial48) + 20;
	if (contenido.descuentoTicket > 0) alto += _altoLinea(img.arial24) + 4;
	if (contenido.montoRecibido != null) alto += _altoLinea(img.arial24);
	if (contenido.cambio != null) alto += _altoLinea(img.arial24);
	alto += contenido.notasPie.length * (_altoLinea(img.arial24) + 4);
	alto += 60; // margenes finales
	return alto;
}

/// Dibuja texto centrado horizontalmente y avanza y en una linea.
int _dibujarTextoCentrado(
	img.Image image,
	String texto, {
	required int y,
	required img.BitmapFont font,
}) {
	final ancho = image.width;
	final w = _medirTexto(texto, font);
	final x = ((ancho - w) ~/ 2).clamp(0, ancho - 1);
	_dibujarTexto(image, texto, x: x, y: y, font: font);
	return y + _altoLinea(font);
}

/// Dibuja texto con doble trazo horizontal para que quede solido en termica.
void _dibujarTexto(
	img.Image image,
	String texto, {
	required int x,
	required int y,
	required img.BitmapFont font,
}) {
	img.drawString(image, texto, font: font, x: x, y: y, color: _negro);
	img.drawString(image, texto, font: font, x: x + 1, y: y, color: _negro);
}

int _dibujarFilaMeta(
	img.Image image,
	String etiqueta,
	String valor,
	int y,
	int anchoImagen,
) {
	final etiquetaTexto = '${_normalizar(etiqueta)}:';
	_dibujarTexto(image, etiquetaTexto,
		x: _padding, y: y, font: img.arial24);
	final valorNormalizado = _normalizar(valor);
	final xValor = _padding + _medirTexto(etiquetaTexto, img.arial24) + 12;
	_dibujarTexto(image, valorNormalizado,
		x: xValor, y: y, font: img.arial24);
	return y + _altoLinea(img.arial24);
}

void _dibujarSeparador(
	img.Image image,
	int y, {
	required int ancho,
	bool grueso = false,
}) {
	img.fillRect(
		image,
		x1: _padding,
		y1: y,
		x2: ancho - _padding,
		y2: y + (grueso ? 4 : 2),
		color: _negro,
	);
}

int _medirTexto(String texto, img.BitmapFont font) {
	var w = 0;
	for (final c in texto.codeUnits) {
		final ch = font.characters[c];
		if (ch != null) {
			w += ch.xAdvance;
		} else {
			w += font.base ~/ 2;
		}
	}
	// +1 para compensar el doble trazo del bold simulado
	return w + 1;
}

List<String> _envolverTexto(
	String texto, {
	required img.BitmapFont font,
	required int anchoMax,
}) {
	if (_medirTexto(texto, font) <= anchoMax) {
		return [texto];
	}
	final palabras = texto.split(' ');
	final lineas = <String>[];
	var actual = '';
	for (final palabra in palabras) {
		final propuesta = actual.isEmpty ? palabra : '$actual $palabra';
		if (_medirTexto(propuesta, font) <= anchoMax) {
			actual = propuesta;
		} else {
			if (actual.isNotEmpty) lineas.add(actual);
			actual = palabra;
		}
	}
	if (actual.isNotEmpty) lineas.add(actual);
	return lineas;
}

/// Aplasta imagen con alfa sobre fondo blanco (elimina transparencias).
img.Image _aplastarSobreBlanco(img.Image src) {
	final destino = img.Image(
		width: src.width,
		height: src.height,
		numChannels: 3,
	);
	img.fill(destino, color: _blanco);
	img.compositeImage(destino, src);
	return destino;
}

String _formatearFecha(DateTime fechaUtc) {
	final local = fechaUtc.toLocal();
	final dia = local.day.toString().padLeft(2, '0');
	final mes = local.month.toString().padLeft(2, '0');
	final hora = local.hour.toString().padLeft(2, '0');
	final minuto = local.minute.toString().padLeft(2, '0');
	return '$dia/$mes/${local.year}  $hora:$minuto';
}

String _formatearCantidad(double cantidad) {
	if (cantidad == cantidad.roundToDouble()) {
		return cantidad.toStringAsFixed(0);
	}
	return cantidad.toStringAsFixed(2);
}

/// Normaliza a ASCII para bitmap fonts (arial14/24/48 solo cubren Latin básico).
String _normalizar(String texto) {
	const mapa = {
		'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
		'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
		'ñ': 'n', 'Ñ': 'N',
		'ü': 'u', 'Ü': 'U',
		'¿': '?', '¡': '!',
		'°': ' ',
		'·': '-',
		'—': '-', '–': '-',
	};
	final buffer = StringBuffer();
	for (final rune in texto.runes) {
		final ch = String.fromCharCode(rune);
		buffer.write(mapa[ch] ?? ch);
	}
	return buffer.toString();
}
