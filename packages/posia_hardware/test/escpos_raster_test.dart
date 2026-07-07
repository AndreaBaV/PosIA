import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:posia_hardware/src/escpos_raster.dart';

void main() {
  test('pngAEscPosRaster incluye grises del logotipo, no solo negro puro', () {
    final imagen = img.Image(width: 3, height: 1, numChannels: 4);
    imagen.setPixelRgba(0, 0, 255, 255, 255, 255);
    imagen.setPixelRgba(1, 0, 90, 104, 110, 255);
    imagen.setPixelRgba(2, 0, 0, 0, 0, 255);
    final png = Uint8List.fromList(img.encodePng(imagen));

    final raster = pngAEscPosRaster(png, anchoMaximo: 3);
    expect(raster.length, greaterThan(8));

    final datos = raster.sublist(8);
    expect(datos, [0x60]);
  });
}
