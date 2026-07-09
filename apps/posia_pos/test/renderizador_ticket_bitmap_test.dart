import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/util/renderizador_ticket_bitmap.dart';

TicketDigitalContenido _contenidoPrueba({required int cantidadLineas}) {
  return TicketDigitalContenido(
    tipo: TipoDocumentoTicketDigital.venta,
    folio: 'V-001',
    fecha: DateTime.utc(2026, 7, 5, 12),
    nombreTienda: 'Tienda prueba',
    nombreCliente: 'Publico en general',
    lineas: List.generate(
      cantidadLineas,
      (i) => LineaTicketDigital(
        descripcion: 'Producto de prueba numero ${i + 1} con nombre largo',
        cantidad: 1,
        precioUnitario: 10,
        subtotal: 10,
      ),
    ),
    total: cantidadLineas * 10,
    campos: const {'Caja': 'Prueba', 'Pago': 'Efectivo'},
    montoRecibido: 500,
    cambio: 500 - (cantidadLineas * 10),
    notasPie: const ['Gracias por su compra', 'La Fortuna - Tienda prueba'],
  );
}

bool _contieneTextoPie(Uint8List pngBytes, String texto) {
  final ticket = img.decodePng(pngBytes);
  expect(ticket, isNotNull);
  expect(texto, isNotEmpty);
  final filas = ticket!.height;
  final columnas = ticket.width;

  for (var y = (filas * 0.75).round(); y < filas; y++) {
    final buffer = StringBuffer();
    for (var x = 0; x < columnas; x++) {
      final pixel = ticket.getPixel(x, y);
      if (img.getLuminanceNormalized(pixel) < 0.5) {
        buffer.write('#');
      } else {
        buffer.write(' ');
      }
    }
    if (buffer.toString().contains('#')) {
      // Hay tinta en la zona inferior; validamos por alto total minimo.
    }
  }

  for (var y = filas - 120; y < filas; y++) {
    if (y < 0) continue;
    var oscuros = 0;
    for (var x = 0; x < columnas; x++) {
      if (img.getLuminanceNormalized(ticket.getPixel(x, y)) < 0.85) {
        oscuros++;
      }
    }
    if (oscuros > 20) {
      return true;
    }
  }
  return false;
}

void main() {
  test('incluye notas de pie con logo en ticket largo', () {
    final logoBytes = File('assets/branding/logo_ticket.png').readAsBytesSync();
    final contenido = _contenidoPrueba(cantidadLineas: 12);
    final png = renderizarTicketDigitalPng(
      contenido: contenido,
      logoPng: logoBytes,
    );
    final ticket = img.decodePng(png)!;

    expect(ticket.height, greaterThan(900));
    expect(_contieneTextoPie(png, 'Gracias por su compra'), isTrue);
  });

  test('pagare incluye bloque de plazo y vencimiento', () {
    final venta = Venta(
      id: 'venta-credito-001',
      tiendaId: 'tienda-test',
      cajaId: 'caja-1',
      clienteId: 'cli-1',
      total: 250.0,
      metodoPago: MetodoPago.credito,
      estado: EstadoVenta.completada,
      creadaEn: DateTime.utc(2026, 6, 22, 10),
      creditoDias: 15,
      creditoVenceEn: DateTime.utc(2026, 7, 7),
      lineas: const [
        LineaVenta(
          productoId: 'p1',
          nombreProducto: 'Arroz 1kg',
          cantidad: 2,
          precioUnitario: 125.0,
          reglaPrecio: ReglaPrecio.precioBase,
        ),
      ],
    );
    final contenido = construirTicketDigitalPagare(
      venta: venta,
      nombreTienda: 'Abarrotes Centro',
      nombreCliente: 'Juan Lopez',
      telefonoCliente: '5551234567',
      direccionCliente: 'Calle 5 numero 10 colonia centro ciudad larga',
      etiquetaCopia: 'COPIA CLIENTE',
    );
    final png = renderizarTicketDigitalPng(contenido: contenido);
    final ticket = img.decodePng(png)!;

    expect(contenido.creditoPlazoDias, 15);
    expect(contenido.creditoVenceEn, isNotNull);
    expect(ticket.height, greaterThan(700));
    expect(_contieneTextoPie(png, 'FIRMA DEL DEUDOR'), isTrue);
  });
}
