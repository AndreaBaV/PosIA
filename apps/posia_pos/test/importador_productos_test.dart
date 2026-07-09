/// Tests del importador masivo de productos.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/util/importador_productos.dart';

void main() {
  final categorias = [
    const Categoria(
      id: 'cat-bebidas',
      nombre: 'Bebidas',
      icono: 'local_drink',
      colorHex: '#FF5722',
      orden: 1,
      activa: true,
    ),
    const Categoria(
      id: 'cat-abarrotes',
      nombre: 'Abarrotes',
      icono: 'shopping_basket',
      colorHex: '#4CAF50',
      orden: 2,
      activa: true,
    ),
  ];

  group('ImportadorProductos', () {
    test('genera plantilla CSV con encabezados esperados', () {
      final csv = ImportadorProductos.generarPlantillaCsv();
      expect(
        csv.startsWith(ImportadorProductos.encabezadosPlantilla.join(',')),
        isTrue,
      );
      expect(csv.contains('Coca-Cola 600ml'), isTrue);
    });

    test('analiza CSV valido', () {
      final csv = '''
nombre,codigo_barras,precio_base,costo_unitario,categoria,unidad_medida,stock_inicial
Agua 1L,7500000000001,15,10,Bebidas,pieza,12
''';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.archivoValido, isTrue);
      expect(analisis.filasValidas, 1);
      expect(analisis.filas.first.solicitud?.nombre, 'Agua 1L');
      expect(analisis.filas.first.solicitud?.stockInicial, 12.0);
    });

    test('acepta solo nombre y precio asignando abarrotes por defecto', () {
      final csv = '''
nombre,precio_base
Arroz 1kg,28.50
''';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.archivoValido, isTrue);
      expect(analisis.filasValidas, 1);
      expect(analisis.filas.first.solicitud?.categoriaId, 'cat-abarrotes');
      expect(analisis.filas.first.solicitud?.unidadMedida, UnidadMedida.pieza);
      expect(analisis.filas.first.solicitud?.stockInicial, 0.0);
    });

    test('celda de categoria vacia usa abarrotes', () {
      final csv = '''
nombre,precio_base,categoria
Frijol 1kg,22,
''';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.filasValidas, 1);
      expect(analisis.filas.first.solicitud?.categoriaId, 'cat-abarrotes');
    });

    test('detecta categoria inexistente cuando se indica explicitamente', () {
      final csv = '''
nombre,precio_base,categoria
Refresco,20,Desconocida
''';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.filasConError, 1);
      expect(
        analisis.filas.first.errores.any(
          (e) => e.contains('Categoria no encontrada'),
        ),
        isTrue,
      );
    });

    test('detecta codigo de barras duplicado en archivo', () {
      final csv = '''
nombre,codigo_barras,precio_base,categoria
A,111,10,Bebidas
B,111,12,Bebidas
''';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.filasValidas, 1);
      expect(analisis.filasConError, 1);
    });

    test('rechaza archivo sin columna nombre', () {
      final csv = 'precio_base,categoria\n10,Bebidas\n';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.errorArchivo, contains('nombre'));
    });

    test('preserva acentos en CSV UTF-8', () {
      final csv = '''
nombre,precio_base,categoria
Café orgánico 500g,45.00,Abarrotes
Jalapeño enlatado,22.50,
''';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.filasValidas, 2);
      expect(analisis.filas[0].solicitud?.nombre, 'Café orgánico 500g');
      expect(analisis.filas[1].solicitud?.nombre, 'Jalapeño enlatado');
    });

    test('preserva acentos en CSV Latin-1 (exportacion Excel Windows)', () {
      final csv = 'nombre,precio_base,categoria\nNiño 1L,18,Abarrotes\n';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: Uint8List.fromList(latin1.encode(csv)),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.filasValidas, 1);
      expect(analisis.filas.first.solicitud?.nombre, 'Niño 1L');
    });

    test('rechaza archivo sin columna precio', () {
      final csv = 'nombre,categoria\nProducto,Bebidas\n';
      final analisis = ImportadorProductos.analizarBytes(
        bytes: utf8.encode(csv),
        extension: 'csv',
        categorias: categorias,
        proveedores: const [],
        codigosBarrasExistentes: const {},
      );
      expect(analisis.errorArchivo, contains('precio'));
    });
  });
}
