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

const int _padding = 8;
const int _margenInferiorTicket = 56;
const int _margenSuperiorTicket = 4;

/// Ancho del logo en px (~48% del ancho util; layout horizontal con detalles).
int _anchoLogoTicket(int anchoTicketPx) {
  final util = anchoTicketPx - (_padding * 2);
  return (util * 0.48).round();
}

const int _gapLogoDetalles = 8;

/// Proporcion del PNG de logo tras recortar margenes blancos.
const int _logoRecortadoAnchoRef = 216;
const int _logoRecortadoAltoRef = 193;

int _altoLogoTicket(int anchoLogo, img.Image logoRecortado) {
  if (logoRecortado.width > 0 && logoRecortado.height > 0) {
    return (anchoLogo * logoRecortado.height / logoRecortado.width).round();
  }
  return (anchoLogo * _logoRecortadoAltoRef / _logoRecortadoAnchoRef).round();
}

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
  final ancho = anchoRolloMm == 80
      ? anchoTicketBitmap80mm
      : anchoTicketBitmap58mm;
  final conLogo = logoPng != null && logoPng.isNotEmpty;
  final altoEstimado = _estimarAltoTicket(contenido, ancho, conLogo: conLogo);
  final image = img.Image(width: ancho, height: altoEstimado, numChannels: 3);
  img.fill(image, color: _blanco);

  var y = _margenSuperiorTicket;

  // Encabezado horizontal: logo grande a la izquierda, detalles a la derecha.
  if (conLogo) {
    final logoDecoded = img.decodePng(logoPng);
    if (logoDecoded != null) {
      final logoRecortado = _recortarMargenesClaros(logoDecoded);
      final anchoLogoTarget = _anchoLogoTicket(ancho);
      final logoPlano = _aplastarSobreBlanco(logoRecortado);
      final altoLogoTarget = _altoLogoTicket(anchoLogoTarget, logoRecortado);
      final logoRes = img.copyResize(
        logoPlano,
        width: anchoLogoTarget,
        height: altoLogoTarget,
        interpolation: img.Interpolation.cubic,
      );
      y = _dibujarEncabezadoLogoDetalles(
        image,
        contenido: contenido,
        logo: logoRes,
        y: y,
        ancho: ancho,
      );
    } else {
      y = _dibujarEncabezadoSoloDetalles(
        image,
        contenido: contenido,
        y: y,
        ancho: ancho,
      );
    }
  } else {
    y = _dibujarEncabezadoSoloDetalles(
      image,
      contenido: contenido,
      y: y,
      ancho: ancho,
    );
  }
  y += 6;
  _dibujarSeparador(image, y, ancho: ancho);
  y += 12;

  if (contenido.lineas.isNotEmpty) {
    // Encabezado tabla
    final xProd = _padding;
    final xImp = ancho - _padding;
    final etiquetaColumna = contenido.mostrarImportes ? 'IMPORTE' : 'CANT';
    _dibujarTexto(image, 'PRODUCTO', x: xProd, y: y, font: img.arial24);
    final wColumna = _medirTexto(etiquetaColumna, img.arial24);
    _dibujarTexto(
      image,
      etiquetaColumna,
      x: xImp - wColumna,
      y: y,
      font: img.arial24,
    );
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
          _dibujarTexto(image, l, x: xProd, y: y, font: img.arial24);
          y += _altoLinea(img.arial24);
        }
        _dibujarTexto(
          image,
          importeStr,
          x: xImp - _medirTexto(importeStr, img.arial24),
          y: yInicioLinea,
          font: img.arial24,
        );
        final sub =
            '${_formatearCantidad(linea.cantidad)} x ${formatearMoneda(linea.precioUnitario)}';
        _dibujarTexto(image, sub, x: xProd, y: y, font: img.arial24);
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
          _dibujarTexto(image, l, x: xProd, y: y, font: img.arial24);
          y += _altoLinea(img.arial24);
        }
        _dibujarTexto(
          image,
          cantidadStr,
          x: xImp - wCant,
          y: yInicioLinea,
          font: img.arial24,
        );
      }
      if (linea.descuentoLinea > 0) {
        _dibujarTexto(
          image,
          'Desc. -${formatearMoneda(linea.descuentoLinea)}',
          x: xProd,
          y: y,
          font: img.arial24,
        );
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
    _dibujarTexto(image, 'Descuento', x: xProd, y: y, font: img.arial24);
    final txt = '-${formatearMoneda(contenido.descuentoTicket)}';
    _dibujarTexto(
      image,
      txt,
      x: xImp - _medirTexto(txt, img.arial24),
      y: y,
      font: img.arial24,
    );
    y += _altoLinea(img.arial24) + 4;
  }

  // TOTAL destacado
  final etiquetaTotal = _normalizar(contenido.etiquetaTotal);
  final totalStr = contenido.mostrarImportes
      ? formatearMoneda(contenido.total)
      : _formatearCantidad(contenido.total);
  _dibujarTexto(image, etiquetaTotal, x: xProd, y: y + 8, font: img.arial48);
  _dibujarTexto(
    image,
    totalStr,
    x: xImp - _medirTexto(totalStr, img.arial48),
    y: y,
    font: img.arial48,
  );
  y += _altoLinea(img.arial48) + 8;

  if (contenido.montoRecibido != null) {
    y = _dibujarFilaMeta(
      image,
      'Recibido',
      formatearMoneda(contenido.montoRecibido!),
      y,
      ancho,
    );
  }
  if (contenido.cambio != null) {
    y = _dibujarFilaMeta(
      image,
      'Cambio',
      formatearMoneda(contenido.cambio!),
      y,
      ancho,
    );
  }
  if (contenido.creditoPlazoDias != null && contenido.creditoVenceEn != null) {
    y += 6;
    _dibujarSeparador(image, y, ancho: ancho);
    y += 12;
    y = _dibujarTextoCentrado(
      image,
      'PLAZO DE PAGO',
      y: y,
      font: img.arial24,
    );
    y += 4;
    y = _dibujarFilaMeta(
      image,
      'Plazo',
      '${contenido.creditoPlazoDias} día(s)',
      y,
      ancho,
    );
    y = _dibujarFilaMeta(
      image,
      'Vence',
      formatearFechaCredito(contenido.creditoVenceEn!.toLocal()),
      y,
      ancho,
    );
  }
  y += 6;
  _dibujarSeparador(image, y, ancho: ancho);
  y += 12;

  for (final nota in contenido.notasPie) {
    if (nota.trim().isEmpty) {
      y += 10;
      continue;
    }
    if (contenido.tipo == TipoDocumentoTicketDigital.pagare ||
        contenido.tipo == TipoDocumentoTicketDigital.comprobanteTraspaso) {
      final anchoTexto = ancho - (_padding * 2);
      y = _dibujarTextoEnColumna(
        image,
        _normalizar(nota),
        x: _padding,
        y: y,
        anchoMax: anchoTexto,
        font: img.arial24,
      );
      y += 4;
    } else {
      y = _dibujarTextoCentrado(
        image,
        _normalizar(nota),
        y: y,
        font: img.arial24,
      );
      y += 4;
    }
  }
  y += _margenInferiorTicket;

  // Recortar al alto real del contenido (nunca limitar por la estimacion).
  final altoFinal = y.clamp(200, image.height);
  final recortado = img.copyCrop(
    image,
    x: 0,
    y: 0,
    width: ancho,
    height: altoFinal,
  );
  return Uint8List.fromList(img.encodePng(recortado));
}

int _estimarAltoTicket(
  TicketDigitalContenido contenido,
  int ancho, {
  bool conLogo = false,
}) {
  var y = _margenSuperiorTicket;
  y += _estimarAltoEncabezado(contenido, ancho, conLogo: conLogo);
  y += 6;

  if (contenido.lineas.isNotEmpty) {
    y += _altoLinea(img.arial24) + 4;
    final xProd = _padding;
    final xImp = ancho - _padding;
    for (final linea in contenido.lineas) {
      final descripcion = _normalizar(linea.descripcion);
      if (contenido.mostrarImportes) {
        final importeStr = formatearMoneda(linea.subtotal);
        final wImpLinea = _medirTexto(importeStr, img.arial24);
        final anchoDescripcion = xImp - wImpLinea - 12 - xProd;
        final lineasDescripcion = _envolverTexto(
          descripcion,
          font: img.arial24,
          anchoMax: anchoDescripcion > 0 ? anchoDescripcion : 200,
        );
        y += _altoLinea(img.arial24) * (lineasDescripcion.length + 1);
      } else {
        final cantidadStr = '${_formatearCantidad(linea.cantidad)} u.';
        final wCant = _medirTexto(cantidadStr, img.arial24);
        final anchoDescripcion = xImp - wCant - 12 - xProd;
        final lineasDescripcion = _envolverTexto(
          descripcion,
          font: img.arial24,
          anchoMax: anchoDescripcion > 0 ? anchoDescripcion : 200,
        );
        y += _altoLinea(img.arial24) * lineasDescripcion.length;
      }
      if (linea.descuentoLinea > 0) {
        y += _altoLinea(img.arial24);
      }
      y += 6;
    }
    y += 16;
  } else {
    y += 12;
  }

  if (contenido.descuentoTicket > 0) {
    y += _altoLinea(img.arial24) + 4;
  }
  y += _altoLinea(img.arial48) + 8;
  if (contenido.montoRecibido != null) {
    y += _altoLinea(img.arial24);
  }
  if (contenido.cambio != null) {
    y += _altoLinea(img.arial24);
  }
  if (contenido.creditoPlazoDias != null && contenido.creditoVenceEn != null) {
    y += 18 + (_altoLinea(img.arial24) * 2);
  }
  y += 18;
  for (final nota in contenido.notasPie) {
    if (nota.trim().isEmpty) {
      y += 10;
      continue;
    }
    if (contenido.tipo == TipoDocumentoTicketDigital.pagare ||
        contenido.tipo == TipoDocumentoTicketDigital.comprobanteTraspaso) {
      final anchoTexto = ancho - (_padding * 2);
      final lineas = _envolverTexto(
        _normalizar(nota),
        font: img.arial24,
        anchoMax: anchoTexto,
      );
      y += _altoLinea(img.arial24) * lineas.length + 4;
    } else {
      y += _altoLinea(img.arial24) + 4;
    }
  }
  y += _margenInferiorTicket;

  return y + 48;
}

int _estimarAltoEncabezado(
  TicketDigitalContenido contenido,
  int ancho, {
  bool conLogo = false,
}) {
  if (!conLogo) {
    return _estimarAltoDetallesEncabezado(contenido, ancho);
  }
  final anchoLogoTarget = _anchoLogoTicket(ancho);
  final altoLogo =
      (anchoLogoTarget * _logoRecortadoAltoRef / _logoRecortadoAnchoRef).round();
  final xTexto = _padding + anchoLogoTarget + _gapLogoDetalles;
  final altoTexto = _estimarAltoDetallesEncabezado(
    contenido,
    ancho,
    xTexto: xTexto,
  );
  return altoLogo > altoTexto ? altoLogo : altoTexto;
}

int _estimarAltoDetallesEncabezado(
  TicketDigitalContenido contenido,
  int ancho, {
  int? xTexto,
}) {
  final anchoTexto = xTexto != null
      ? ancho - _padding - xTexto
      : ancho - (_padding * 2);
  var lineas = _contarLineasTexto(
    _normalizar(contenido.nombreTienda),
    font: img.arial24,
    anchoMax: anchoTexto,
  );
  if (contenido.direccionTienda != null &&
      contenido.direccionTienda!.trim().isNotEmpty) {
    lineas += _contarLineasTexto(
      _normalizar(contenido.direccionTienda!.trim()),
      font: img.arial24,
      anchoMax: anchoTexto,
    );
  }
  var alto = lineas * _altoLinea(img.arial24) + 4;
  alto += _estimarAltoMetaEncabezado(contenido, anchoTexto);
  return alto;
}

int _estimarAltoMetaEncabezado(
  TicketDigitalContenido contenido,
  int anchoTexto,
) {
  var alto = 0;
  void agregarCampo(String texto) {
    alto += _contarLineasTexto(
          texto,
          font: img.arial24,
          anchoMax: anchoTexto,
        ) *
        _altoLinea(img.arial24);
    alto += _espacioEntreMetaEncabezado;
  }

  agregarCampo('Folio: ${_normalizar(contenido.folio)}');
  agregarCampo('Fecha: ${_formatearFecha(contenido.fecha)}');
  if (contenido.etiquetaSecundaria != null &&
      contenido.etiquetaSecundaria!.trim().isNotEmpty) {
    agregarCampo('Copia: ${_normalizar(contenido.etiquetaSecundaria!.trim())}');
  }
  if (contenido.nombreCliente != null &&
      contenido.nombreCliente!.trim().isNotEmpty) {
    agregarCampo(
      'Cliente: ${_normalizar(contenido.nombreCliente!.trim())}',
    );
  }
  for (final entry in contenido.campos.entries) {
    agregarCampo(
      '${_normalizar(entry.key)}: ${_normalizar(entry.value)}',
    );
  }
  return alto;
}

int _contarLineasTexto(
  String texto, {
  required img.BitmapFont font,
  required int anchoMax,
}) {
  return _envolverTexto(texto, font: font, anchoMax: anchoMax).length;
}

const int _espacioEntreMetaEncabezado = 4;

/// Logo a la izquierda y detalles del ticket a la derecha, misma altura.
int _dibujarEncabezadoLogoDetalles(
  img.Image image, {
  required TicketDigitalContenido contenido,
  required img.Image logo,
  required int y,
  required int ancho,
}) {
  final xLogo = _padding;
  img.compositeImage(image, logo, dstX: xLogo, dstY: y);

  final xTexto = xLogo + logo.width + _gapLogoDetalles;
  final yFinTexto = _dibujarDetallesEncabezado(
    image,
    contenido: contenido,
    y: y,
    xTexto: xTexto,
    ancho: ancho,
  );

  final yFinLogo = y + logo.height;
  return (yFinLogo > yFinTexto ? yFinLogo : yFinTexto) + 4;
}

/// Detalles del ticket a ancho completo (sin logo).
int _dibujarEncabezadoSoloDetalles(
  img.Image image, {
  required TicketDigitalContenido contenido,
  required int y,
  required int ancho,
}) {
  return _dibujarDetallesEncabezado(
    image,
    contenido: contenido,
    y: y,
    xTexto: _padding,
    ancho: ancho,
  ) + 4;
}

int _dibujarDetallesEncabezado(
  img.Image image, {
  required TicketDigitalContenido contenido,
  required int y,
  required int xTexto,
  required int ancho,
}) {
  final anchoTexto = ancho - _padding - xTexto;
  var yActual = y;

  yActual = _dibujarTextoEnColumna(
    image,
    _normalizar(contenido.nombreTienda),
    x: xTexto,
    y: yActual,
    anchoMax: anchoTexto,
    font: img.arial24,
  );
  if (contenido.direccionTienda != null &&
      contenido.direccionTienda!.trim().isNotEmpty) {
    yActual = _dibujarTextoEnColumna(
      image,
      _normalizar(contenido.direccionTienda!.trim()),
      x: xTexto,
      y: yActual,
      anchoMax: anchoTexto,
      font: img.arial24,
    );
  }
  yActual += 4;
  yActual = _dibujarMetaEncabezado(
    image,
    'Folio',
    contenido.folio,
    yActual,
    xTexto,
    anchoTexto,
  );
  yActual = _dibujarMetaEncabezado(
    image,
    'Fecha',
    _formatearFecha(contenido.fecha),
    yActual,
    xTexto,
    anchoTexto,
  );
  if (contenido.etiquetaSecundaria != null &&
      contenido.etiquetaSecundaria!.trim().isNotEmpty) {
    yActual = _dibujarMetaEncabezado(
      image,
      'Copia',
      contenido.etiquetaSecundaria!.trim(),
      yActual,
      xTexto,
      anchoTexto,
    );
  }
  if (contenido.nombreCliente != null &&
      contenido.nombreCliente!.trim().isNotEmpty) {
    yActual = _dibujarMetaEncabezado(
      image,
      'Cliente',
      contenido.nombreCliente!.trim(),
      yActual,
      xTexto,
      anchoTexto,
    );
  }
  for (final entry in contenido.campos.entries) {
    yActual = _dibujarMetaEncabezado(
      image,
      entry.key,
      entry.value,
      yActual,
      xTexto,
      anchoTexto,
    );
  }
  return yActual;
}

int _dibujarTextoEnColumna(
  img.Image image,
  String texto, {
  required int x,
  required int y,
  required int anchoMax,
  required img.BitmapFont font,
}) {
  final lineas = _envolverTexto(texto, font: font, anchoMax: anchoMax);
  var yActual = y;
  for (final linea in lineas) {
    _dibujarTexto(image, linea, x: x, y: yActual, font: font);
    yActual += _altoLinea(font);
  }
  return yActual;
}

int _dibujarMetaEncabezado(
  img.Image image,
  String etiqueta,
  String valor,
  int y,
  int xColumna,
  int anchoColumna,
) {
  final texto = '${_normalizar(etiqueta)}: ${_normalizar(valor)}';
  final yFin = _dibujarTextoEnColumna(
    image,
    texto,
    x: xColumna,
    y: y,
    anchoMax: anchoColumna,
    font: img.arial24,
  );
  return yFin + _espacioEntreMetaEncabezado;
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
  _dibujarTexto(image, etiquetaTexto, x: _padding, y: y, font: img.arial24);
  final valorNormalizado = _normalizar(valor);
  final xValor = _padding + _medirTexto(etiquetaTexto, img.arial24) + 12;
  _dibujarTexto(image, valorNormalizado, x: xValor, y: y, font: img.arial24);
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

/// Recorta margenes transparentes o casi blancos alrededor del logo.
img.Image _recortarMargenesClaros(img.Image src) {
  var minX = src.width;
  var minY = src.height;
  var maxX = 0;
  var maxY = 0;
  var encontrado = false;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final pixel = src.getPixel(x, y);
      if (pixel.a.toInt() <= 16) {
        continue;
      }
      if (img.getLuminanceNormalized(pixel) >= 0.95) {
        continue;
      }
      encontrado = true;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (!encontrado) {
    return src;
  }

  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
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
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'ñ': 'n',
    'Ñ': 'N',
    'ü': 'u',
    'Ü': 'U',
    '¿': '?',
    '¡': '!',
    '°': ' ',
    '·': '-',
    '—': '-',
    '–': '-',
  };
  final buffer = StringBuffer();
  for (final rune in texto.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(mapa[ch] ?? ch);
  }
  return buffer.toString();
}
