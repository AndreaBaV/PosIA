/// Generador de PDF con etiquetas de producto (codigo de barras, nombre, precio).
library;

import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:posia_core/posia_core.dart';

/// Datos minimos para imprimir una etiqueta.
class DatosEtiquetaProducto {
  const DatosEtiquetaProducto({
    required this.codigoBarras,
    required this.nombre,
    required this.precio,
  });

  final String codigoBarras;
  final String nombre;
  final double precio;
}

/// Genera PDF con una pagina por etiqueta al tamano indicado (mm).
Future<Uint8List> generarPdfEtiquetasProductos({
  required List<DatosEtiquetaProducto> productos,
  required double anchoMm,
  required double altoMm,
}) async {
  final documento = pw.Document();
  final ancho = anchoMm * PdfPageFormat.mm;
  final alto = altoMm * PdfPageFormat.mm;
  final margen = 2.0 * PdfPageFormat.mm;

  for (final producto in productos) {
    final codigo = producto.codigoBarras.trim().isNotEmpty
        ? producto.codigoBarras.trim()
        : producto.nombre;
    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(ancho, alto, marginAll: margen),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: codigo,
                  width: ancho - (margen * 2),
                  height: alto * 0.35,
                  drawText: false,
                ),
              ),
              pw.SizedBox(height: 4.0),
              pw.Text(
                producto.nombre,
                maxLines: 2,
                style: pw.TextStyle(fontSize: anchoMm * 0.22, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2.0),
              pw.Text(
                formatearMoneda(producto.precio),
                style: pw.TextStyle(fontSize: anchoMm * 0.28, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (producto.codigoBarras.trim().isNotEmpty)
                pw.Text(
                  producto.codigoBarras.trim(),
                  style: pw.TextStyle(fontSize: anchoMm * 0.14),
                  textAlign: pw.TextAlign.center,
                ),
            ],
          );
        },
      ),
    );
  }
  return documento.save();
}
