/// Renderiza tickets digitales como PDF o PNG con logo de marca.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:posia_core/posia_core.dart';
import 'package:printing/printing.dart';

const _verdeMarca = PdfColor.fromInt(0xFF2E7D32);
const _naranjaCredito = PdfColor.fromInt(0xFFE65100);
const _grisOscuro = PdfColor.fromInt(0xFF263238);
const _grisTexto = PdfColor.fromInt(0xFF546E7A);
const _grisClaro = PdfColor.fromInt(0xFFECEFF1);
const _grisFondo = PdfColor.fromInt(0xFFF5F7F8);

// --- Geometria (puntos PDF sobre rollo de 80 mm) -----------------------------

const _margenTicket = 15.0;
const _anchoLogo = 64.0;
const _separacionLogo = 8.0;
const _anchoEtiquetaMeta = 52.0;
const _separacionMeta = 6.0;
const _anchoColumnaCantidad = 34.0;
const _anchoColumnaImporte = 54.0;

final double _anchoContenido = PdfPageFormat.roll80.width - _margenTicket * 2;
final double _anchoEncabezadoTexto =
    _anchoContenido - _anchoLogo - _separacionLogo;
final double _anchoValorMeta =
    _anchoContenido - _anchoEtiquetaMeta - _separacionMeta;
final double _anchoDescripcion =
    _anchoContenido - _anchoColumnaCantidad - _anchoColumnaImporte;

const _tamTitulo = 11.5;
const _tamSubtitulo = 7.5;
const _tamTienda = 9.0;
const _tamMeta = 8.0;
const _tamLinea = 8.5;
const _tamDetalleLinea = 7.5;
const _tamEtiquetaTotal = 9.5;
const _tamImporteTotal = 14.0;
const _tamPie = 7.5;

PdfColor _colorAcento(TipoDocumentoTicketDigital tipo) {
  return switch (tipo) {
    TipoDocumentoTicketDigital.pagare ||
    TipoDocumentoTicketDigital.liquidacionCredito => _naranjaCredito,
    _ => _verdeMarca,
  };
}

/// Documentos con listados y firmas al pie: se alinean a la izquierda.
bool _pieAlineadoIzquierda(TipoDocumentoTicketDigital tipo) {
  return tipo == TipoDocumentoTicketDigital.pagare ||
      tipo == TipoDocumentoTicketDigital.comprobanteTraspaso;
}

String _cantidadLinea(double cantidad) {
  if (cantidad == cantidad.roundToDouble()) {
    return cantidad.toStringAsFixed(0);
  }
  return cantidad.toStringAsFixed(2);
}

String _fechaLegible(DateTime fechaUtc) {
  final local = fechaUtc.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year}  $hora:$minuto';
}

// --- Estimacion de alto ------------------------------------------------------

/// Lineas que ocupara [texto] al ajustarse a [ancho] con fuente de [tamano].
///
/// El ticket se emite en una pagina de alto fijo, asi que lo que no cabe se
/// recorta en silencio. `pdf` no permite medir texto antes de armar la pagina,
/// asi que se estima con el ancho medio de caracter de Helvetica (~0.5 em) y se
/// corta por palabras, igual que el motor de layout.
int _lineasEstimadas(
  String texto, {
  required double ancho,
  required double tamano,
}) {
  final limpio = texto.trim();
  if (limpio.isEmpty) {
    return 1;
  }
  final porLinea = (ancho / (tamano * 0.5)).floor();
  if (porLinea <= 1) {
    return 1;
  }
  var lineas = 1;
  var usado = 0;
  for (final palabra in limpio.split(RegExp(r'\s+'))) {
    final candidato = usado == 0 ? palabra.length : usado + 1 + palabra.length;
    if (candidato <= porLinea) {
      usado = candidato;
      continue;
    }
    if (usado > 0) {
      lineas = lineas + 1;
    }
    usado = palabra.length;
    while (usado > porLinea) {
      lineas = lineas + 1;
      usado = usado - porLinea;
    }
  }
  return lineas;
}

double _altoTexto(
  String texto, {
  required double ancho,
  required double tamano,
}) {
  return _lineasEstimadas(texto, ancho: ancho, tamano: tamano) * tamano * 1.2;
}

double _mayor(double a, double b) => a > b ? a : b;

// --- Bloques de contenido ----------------------------------------------------

/// Pares etiqueta/valor del encabezado, en el orden en que se imprimen.
List<List<String>> _filasMeta(TicketDigitalContenido contenido) {
  final filas = <List<String>>[
    ['Folio', contenido.folio],
    ['Fecha', _fechaLegible(contenido.fecha)],
  ];
  final copia = contenido.etiquetaSecundaria?.trim() ?? '';
  if (copia.isNotEmpty) {
    filas.add(['Copia', copia]);
  }
  final cliente = contenido.nombreCliente?.trim() ?? '';
  if (cliente.isNotEmpty) {
    filas.add(['Cliente', cliente]);
  }
  for (final entrada in contenido.campos.entries) {
    final valor = entrada.value.trim();
    if (valor.isNotEmpty) {
      filas.add([entrada.key, valor]);
    }
  }
  return filas;
}

pw.Widget _lineaDivisora({PdfColor color = _grisClaro}) {
  return pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 7),
    height: 0.6,
    color: color,
  );
}

double get _altoLineaDivisora => 14.6;

pw.Widget _filaMeta(String etiqueta, String valor) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: _anchoEtiquetaMeta,
          child: pw.Text(
            etiqueta,
            style: const pw.TextStyle(fontSize: _tamMeta, color: _grisTexto),
          ),
        ),
        pw.SizedBox(width: _separacionMeta),
        pw.Expanded(
          child: pw.Text(
            valor,
            style: const pw.TextStyle(fontSize: _tamMeta, color: _grisOscuro),
          ),
        ),
      ],
    ),
  );
}

double _altoFilaMeta(String etiqueta, String valor) {
  return _mayor(
        _altoTexto(etiqueta, ancho: _anchoEtiquetaMeta, tamano: _tamMeta),
        _altoTexto(valor, ancho: _anchoValorMeta, tamano: _tamMeta),
      ) +
      3;
}

/// Logo a la izquierda; tipo de documento, tienda y direccion a la derecha.
///
/// Antes el encabezado tambien encajaba aqui folio, fecha, cliente y todos los
/// campos del documento, en la franja de ~80 pt que dejaba el logo: una
/// direccion de entrega salia partida en tres o cuatro renglones. Ahora esos
/// datos van completos abajo, a todo el ancho del ticket.
pw.Widget _encabezado(TicketDigitalContenido contenido, pw.MemoryImage logo) {
  final acento = _colorAcento(contenido.tipo);
  final direccion = contenido.direccionTienda?.trim() ?? '';
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Image(logo, width: _anchoLogo),
      pw.SizedBox(width: _separacionLogo),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              contenido.tituloDocumento,
              style: pw.TextStyle(
                fontSize: _tamTitulo,
                fontWeight: pw.FontWeight.bold,
                color: acento,
                letterSpacing: 0.6,
              ),
            ),
            pw.Text(
              contenido.subtituloDocumento,
              style: const pw.TextStyle(
                fontSize: _tamSubtitulo,
                color: _grisTexto,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              contenido.nombreTienda,
              style: pw.TextStyle(
                fontSize: _tamTienda,
                fontWeight: pw.FontWeight.bold,
                color: _grisOscuro,
              ),
            ),
            if (direccion.isNotEmpty)
              pw.Text(
                direccion,
                style: const pw.TextStyle(
                  fontSize: _tamSubtitulo,
                  color: _grisTexto,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Alto que ocupara el logo al dibujarlo con ancho [_anchoLogo].
double _altoLogoEscalado(pw.MemoryImage logo) {
  final ancho = logo.width ?? 0;
  final alto = logo.height ?? 0;
  if (ancho <= 0 || alto <= 0) {
    return _anchoLogo;
  }
  return _anchoLogo * alto / ancho;
}

double _altoEncabezado(TicketDigitalContenido contenido, pw.MemoryImage logo) {
  final altoLogo = _altoLogoEscalado(logo);
  final direccion = contenido.direccionTienda?.trim() ?? '';
  var altoTexto =
      _altoTexto(
        contenido.tituloDocumento,
        ancho: _anchoEncabezadoTexto,
        tamano: _tamTitulo,
      ) +
      _altoTexto(
        contenido.subtituloDocumento,
        ancho: _anchoEncabezadoTexto,
        tamano: _tamSubtitulo,
      ) +
      5 +
      _altoTexto(
        contenido.nombreTienda,
        ancho: _anchoEncabezadoTexto,
        tamano: _tamTienda,
      );
  if (direccion.isNotEmpty) {
    altoTexto = altoTexto +
        _altoTexto(
          direccion,
          ancho: _anchoEncabezadoTexto,
          tamano: _tamSubtitulo,
        );
  }
  return _mayor(altoLogo, altoTexto);
}

pw.Widget _celdaEncabezadoTabla(
  String texto, {
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Text(
    texto,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: _tamDetalleLinea,
      color: _grisTexto,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.3,
    ),
  );
}

pw.Widget _encabezadoTabla(TicketDigitalContenido contenido) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    decoration: const pw.BoxDecoration(color: _grisFondo),
    child: pw.Row(
      children: [
        pw.Expanded(child: _celdaEncabezadoTabla('PRODUCTO')),
        pw.SizedBox(
          width: _anchoColumnaCantidad,
          child: _celdaEncabezadoTabla('CANT', align: pw.TextAlign.center),
        ),
        pw.SizedBox(
          width: _anchoColumnaImporte,
          child: _celdaEncabezadoTabla(
            contenido.mostrarImportes ? 'IMPORTE' : 'ENVIADO',
            align: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

double get _altoEncabezadoTabla => _tamDetalleLinea * 1.2 + 8;

pw.Widget _filaProducto(
  LineaTicketDigital linea, {
  required bool mostrarImportes,
}) {
  final detalle = mostrarImportes
      ? '${_cantidadLinea(linea.cantidad)} x '
            '${formatearMoneda(linea.precioUnitario)}'
      : null;
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                linea.descripcion,
                style: const pw.TextStyle(
                  fontSize: _tamLinea,
                  color: _grisOscuro,
                ),
              ),
            ),
            pw.SizedBox(
              width: _anchoColumnaCantidad,
              child: pw.Text(
                _cantidadLinea(linea.cantidad),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: _tamLinea,
                  color: _grisTexto,
                ),
              ),
            ),
            pw.SizedBox(
              width: _anchoColumnaImporte,
              child: pw.Text(
                mostrarImportes ? formatearMoneda(linea.subtotal) : '________',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: _tamLinea,
                  fontWeight: pw.FontWeight.bold,
                  color: _grisOscuro,
                ),
              ),
            ),
          ],
        ),
        if (detalle != null)
          pw.Text(
            detalle,
            style: const pw.TextStyle(
              fontSize: _tamDetalleLinea,
              color: _grisTexto,
            ),
          ),
        if (linea.descuentoLinea > 0)
          pw.Text(
            'Desc. -${formatearMoneda(linea.descuentoLinea)}',
            style: const pw.TextStyle(
              fontSize: _tamDetalleLinea,
              color: _grisTexto,
            ),
          ),
      ],
    ),
  );
}

double _altoFilaProducto(
  LineaTicketDigital linea, {
  required bool mostrarImportes,
}) {
  var alto =
      _altoTexto(
        linea.descripcion,
        ancho: _anchoDescripcion,
        tamano: _tamLinea,
      ) +
      6;
  if (mostrarImportes) {
    alto = alto + _tamDetalleLinea * 1.2;
  }
  if (linea.descuentoLinea > 0) {
    alto = alto + _tamDetalleLinea * 1.2;
  }
  return alto;
}

pw.Widget _bloqueCredito(TicketDigitalContenido contenido) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFFFF3E0),
      border: pw.Border.all(color: _naranjaCredito, width: 0.8),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'PLAZO DE PAGO',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: _tamLinea,
            fontWeight: pw.FontWeight.bold,
            color: _naranjaCredito,
            letterSpacing: 0.3,
          ),
        ),
        pw.SizedBox(height: 4),
        _filaMeta('Plazo', '${contenido.creditoPlazoDias} día(s)'),
        _filaMeta(
          'Vence',
          formatearFechaCredito(contenido.creditoVenceEn!.toLocal()),
        ),
      ],
    ),
  );
}

double _altoBloqueCredito(TicketDigitalContenido contenido) {
  return _tamLinea * 1.2 +
      4 +
      _altoFilaMeta('Plazo', '${contenido.creditoPlazoDias} día(s)') +
      _altoFilaMeta(
        'Vence',
        formatearFechaCredito(contenido.creditoVenceEn!.toLocal()),
      ) +
      14;
}

List<pw.Widget> _construirContenido({
  required TicketDigitalContenido contenido,
  required pw.MemoryImage logo,
}) {
  final acento = _colorAcento(contenido.tipo);
  final alinearIzquierda = _pieAlineadoIzquierda(contenido.tipo);
  return [
    _encabezado(contenido, logo),
    _lineaDivisora(),
    for (final fila in _filasMeta(contenido)) _filaMeta(fila[0], fila[1]),
    pw.SizedBox(height: 4),
    if (contenido.lineas.isNotEmpty) ...[
      _encabezadoTabla(contenido),
      for (final linea in contenido.lineas)
        _filaProducto(linea, mostrarImportes: contenido.mostrarImportes),
    ],
    _lineaDivisora(color: acento),
    if (contenido.descuentoTicket > 0)
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Descuento',
            style: const pw.TextStyle(fontSize: _tamLinea, color: _grisTexto),
          ),
          pw.Text(
            '-${formatearMoneda(contenido.descuentoTicket)}',
            style: const pw.TextStyle(fontSize: _tamLinea, color: _grisTexto),
          ),
        ],
      ),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Text(
            contenido.etiquetaTotal,
            style: pw.TextStyle(
              fontSize: _tamEtiquetaTotal,
              fontWeight: pw.FontWeight.bold,
              color: acento,
              letterSpacing: 0.4,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          contenido.mostrarImportes
              ? formatearMoneda(contenido.total)
              : _cantidadLinea(contenido.total),
          style: pw.TextStyle(
            fontSize: _tamImporteTotal,
            fontWeight: pw.FontWeight.bold,
            color: _grisOscuro,
          ),
        ),
      ],
    ),
    if (contenido.montoRecibido != null) ...[
      pw.SizedBox(height: 6),
      _filaMeta('Recibido', formatearMoneda(contenido.montoRecibido!)),
    ],
    if (contenido.cambio != null)
      _filaMeta('Cambio', formatearMoneda(contenido.cambio!)),
    if (contenido.creditoPlazoDias != null &&
        contenido.creditoVenceEn != null) ...[
      pw.SizedBox(height: 6),
      _bloqueCredito(contenido),
    ],
    _lineaDivisora(),
    for (final nota in contenido.notasPie)
      if (nota.trim().isEmpty)
        pw.SizedBox(height: 6)
      else
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            nota,
            textAlign: alinearIzquierda
                ? pw.TextAlign.left
                : pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: _tamPie,
              color: _grisTexto,
              fontWeight: nota == 'FIRMA DEL DEUDOR'
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        ),
  ];
}

/// Altura de pagina en puntos PDF, ajustada al contenido real del ticket.
///
/// Debe seguir a [_construirContenido] bloque por bloque: la pagina es de alto
/// fijo y todo lo que sobre se recorta sin aviso.
double _calcularAltoPagina(
  TicketDigitalContenido contenido,
  pw.MemoryImage logo,
) {
  var alto = _altoEncabezado(contenido, logo) + _altoLineaDivisora;
  for (final fila in _filasMeta(contenido)) {
    alto = alto + _altoFilaMeta(fila[0], fila[1]);
  }
  alto = alto + 4;
  if (contenido.lineas.isNotEmpty) {
    alto = alto + _altoEncabezadoTabla;
    for (final linea in contenido.lineas) {
      alto = alto +
          _altoFilaProducto(linea, mostrarImportes: contenido.mostrarImportes);
    }
  }
  alto = alto + _altoLineaDivisora;
  if (contenido.descuentoTicket > 0) {
    alto = alto + _tamLinea * 1.2;
  }
  alto = alto +
      _mayor(
        _altoTexto(
          contenido.etiquetaTotal,
          ancho: _anchoContenido * 0.55,
          tamano: _tamEtiquetaTotal,
        ),
        _tamImporteTotal * 1.2,
      );
  if (contenido.montoRecibido != null) {
    alto = alto +
        6 +
        _altoFilaMeta('Recibido', formatearMoneda(contenido.montoRecibido!));
  }
  if (contenido.cambio != null) {
    alto = alto + _altoFilaMeta('Cambio', formatearMoneda(contenido.cambio!));
  }
  if (contenido.creditoPlazoDias != null && contenido.creditoVenceEn != null) {
    alto = alto + 6 + _altoBloqueCredito(contenido);
  }
  alto = alto + _altoLineaDivisora;
  for (final nota in contenido.notasPie) {
    if (nota.trim().isEmpty) {
      alto = alto + 6;
      continue;
    }
    alto = alto +
        _altoTexto(nota, ancho: _anchoContenido, tamano: _tamPie) +
        3;
  }
  // Holgura: la medicion es una estimacion; sobra papel antes que recortar.
  return alto + 16 + _margenTicket * 2;
}

Uint8List _pngFondoBlancoRecortado(PdfRaster raster) {
  final original = raster.asImage();
  final conFondo = img.Image(
    width: original.width,
    height: original.height,
    numChannels: 4,
  );
  img.fill(conFondo, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(conFondo, original);
  final recortado = img.trim(conFondo, mode: img.TrimMode.topLeftColor);
  return Uint8List.fromList(img.encodePng(recortado));
}

/// Genera bytes PDF del ticket digital con logo.
Future<Uint8List> generarTicketDigitalPdfBytes({
  required TicketDigitalContenido contenido,
  required Uint8List logoPng,
}) async {
  final logo = pw.MemoryImage(logoPng);
  final documento = pw.Document();
  final pageFormat = PdfPageFormat(
    PdfPageFormat.roll80.width,
    _calcularAltoPagina(contenido, logo),
    marginLeft: _margenTicket,
    marginRight: _margenTicket,
    marginTop: _margenTicket,
    marginBottom: _margenTicket,
  );
  documento.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Container(
        color: PdfColors.white,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: _construirContenido(contenido: contenido, logo: logo),
        ),
      ),
    ),
  );
  return documento.save();
}

/// Rasteriza el ticket como PNG para WhatsApp (pagina unica con todo el detalle).
Future<Uint8List> generarTicketDigitalPngBytes({
  required TicketDigitalContenido contenido,
  required Uint8List logoPng,
}) async {
  final pdfBytes = await generarTicketDigitalPdfBytes(
    contenido: contenido,
    logoPng: logoPng,
  );
  final paginas = await Printing.raster(pdfBytes, dpi: 200).toList();
  if (paginas.isEmpty) {
    throw StateError('No se pudo generar imagen del ticket');
  }
  return _pngFondoBlancoRecortado(paginas.first);
}
