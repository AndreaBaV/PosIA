import 'package:flutter_test/flutter_test.dart';
import 'package:posia_hardware/posia_hardware.dart';

void main() {
  test('modos de impresora reconocidos', () {
    expect(ModoImpresora.archivo.name, 'archivo');
    expect(ModoImpresora.red.name, 'red');
    expect(ModoImpresora.ambos.name, 'ambos');
    expect(ModoImpresora.usbWindows.name, 'usbWindows');
  });
}
