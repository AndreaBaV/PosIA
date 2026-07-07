import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/util/renderizador_ticket_bitmap.dart';

void main() {
  test('logo en encabezado horizontal ocupa ~48% del ancho en ticket 80mm', () {
    final logoBytes =
        File('assets/branding/logo_ticket.png').readAsBytesSync();
    final contenido = TicketDigitalContenido(
      tipo: TipoDocumentoTicketDigital.venta,
      folio: 'T-1',
      fecha: DateTime.utc(2026, 7, 5),
      nombreTienda: 'Tienda',
      lineas: const [],
      total: 0,
    );
    final png = renderizarTicketDigitalPng(
      contenido: contenido,
      logoPng: logoBytes,
      anchoRolloMm: 80,
    );
    final ticket = img.decodePng(png)!;

    var minXLogo = ticket.width;
    var maxXLogo = 0;
    var maxYEncabezado = 0;
    final anchoLogoEsperado = ((576 - 16) * 0.48).round();
    for (var y = 4; y < 220; y++) {
      for (var x = 8; x < 8 + anchoLogoEsperado + 20; x++) {
        if (img.getLuminanceNormalized(ticket.getPixel(x, y)) < 0.85) {
          minXLogo = minXLogo > x ? x : minXLogo;
          maxXLogo = maxXLogo < x ? x : maxXLogo;
          maxYEncabezado = maxYEncabezado < y ? y : maxYEncabezado;
        }
      }
    }

    final anchoLogo = maxXLogo - minXLogo + 1;
    // ignore: avoid_print
    print('logo ancho=$anchoLogo alto=${maxYEncabezado + 1}');
    expect(anchoLogo, greaterThan(240));
    expect(anchoLogo, lessThan(anchoLogoEsperado + 30));
  });
}
