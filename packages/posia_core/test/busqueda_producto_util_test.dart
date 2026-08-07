import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

Producto _producto(String id, String nombre, {String codigo = ''}) {
  return Producto(
    id: id,
    nombre: nombre,
    codigoBarras: codigo,
    precioBase: 10.0,
    unidadMedida: UnidadMedida.pieza,
    rutaImagen: '',
    activo: true,
    tiendaId: 't1',
  );
}

void main() {
  test('filtrarProductosPorBusqueda enlaza abreviatura con nombre', () {
    final productos = [
      _producto('1', 'Arroz Saman 1kg'),
      _producto('2', 'Frijol Negro'),
      _producto('3', 'Sal de mesa'),
    ];
    final resultado = filtrarProductosPorBusqueda(productos, 'sam');
    expect(resultado, isNotEmpty);
    expect(resultado.first.nombre, contains('Saman'));
  });

  test('filtrarProductosPorBusqueda encuentra multi-token sam 1k', () {
    final productos = [
      _producto('1', 'saman arroz 1kg'),
      _producto('2', 'Arroz Verde 5kg'),
      _producto('3', 'Sal de mesa'),
    ];
    final resultado = filtrarProductosPorBusqueda(productos, 'sam 1k');
    expect(resultado, isNotEmpty);
    expect(resultado.first.id, '1');
  });

  test('filtrarProductosPorBusqueda ignora acentos í vs i', () {
    final productos = [
      _producto('1', 'Aceite de maíz 1L'),
      _producto('2', 'Frijol Negro'),
    ];
    final resultado = filtrarProductosPorBusqueda(productos, 'maiz');
    expect(resultado, isNotEmpty);
    expect(resultado.first.id, '1');

    final resultadoAcento = filtrarProductosPorBusqueda(productos, 'ací');
    expect(resultadoAcento, isNotEmpty);
    expect(resultadoAcento.first.id, '1');
  });

  test('filtrarProductosPorBusqueda prioriza codigo exacto', () {
    final productos = [
      _producto('1', 'Producto A', codigo: '750123'),
      _producto('2', 'Otro', codigo: '999'),
    ];
    final resultado = filtrarProductosPorBusqueda(productos, '750123');
    expect(resultado.length, 1);
    expect(resultado.first.id, '1');
  });

  test('filtrarProductosPorBusqueda vacio devuelve todos', () {
    final productos = [_producto('1', 'A')];
    expect(filtrarProductosPorBusqueda(productos, ''), productos);
  });

  test('pareceCodigoBarrasEscaneado detecta EAN y rechaza nombres', () {
    expect(pareceCodigoBarrasEscaneado('7501234567890'), isTrue);
    expect(pareceCodigoBarrasEscaneado('ABC-1234'), isTrue);
    expect(pareceCodigoBarrasEscaneado('arroz'), isFalse);
    expect(pareceCodigoBarrasEscaneado('123'), isFalse);
  });

  test('normalizarTextoBusqueda quita acentos', () {
    expect(normalizarTextoBusqueda('Café Maíz'), 'cafe maiz');
    expect(normalizarTextoBusqueda('SAMAN'), 'saman');
  });

  test('textoContieneBusqueda ignora acentos en ambos lados', () {
    expect(textoContieneBusqueda('Aceite de maíz', 'maiz'), isTrue);
    expect(textoContieneBusqueda('Aceite de maiz', 'maíz'), isTrue);
    expect(textoContieneBusqueda('Frijol', 'maiz'), isFalse);
    expect(textoContieneBusqueda('Cualquier', ''), isTrue);
  });

  test('productoCoincideBusqueda usa el mismo criterio que la caja', () {
    final producto = _producto('1', 'Aceite de maíz 1L', codigo: '750');
    expect(productoCoincideBusqueda(producto, 'maiz'), isTrue);
    expect(productoCoincideBusqueda(producto, 'ací'), isTrue);
    expect(productoCoincideBusqueda(producto, '750'), isTrue);
    expect(productoCoincideBusqueda(producto, 'frijol'), isFalse);
    expect(productoCoincideBusqueda(producto, ''), isTrue);
  });

  group('generarCodigoInternoDesdeNombre', () {
    test('es idempotente para el mismo nombre normalizado', () {
      expect(
        generarCodigoInternoDesdeNombre('Almendra Fileteada'),
        generarCodigoInternoDesdeNombre('almendra   fileteada'),
      );
      expect(
        generarCodigoInternoDesdeNombre('Café Maíz'),
        generarCodigoInternoDesdeNombre('cafe maiz'),
      );
    });

    test('produce codigos distintos para nombres distintos', () {
      expect(
        generarCodigoInternoDesdeNombre('Almendra'),
        isNot(equals(generarCodigoInternoDesdeNombre('Almendra Fileteada'))),
      );
    });

    test('nombre vacio o solo simbolos devuelve cadena vacia', () {
      expect(generarCodigoInternoDesdeNombre(''), '');
      expect(generarCodigoInternoDesdeNombre('   '), '');
      expect(generarCodigoInternoDesdeNombre('###'), '');
    });

    test('siempre inicia con el prefijo interno', () {
      expect(
        generarCodigoInternoDesdeNombre(
          'Arroz',
        ).startsWith(PREFIJO_CODIGO_INTERNO),
        isTrue,
      );
    });
  });

  group('esCodigoBarrasInterno', () {
    test('marca los codigos autogenerados', () {
      expect(
        esCodigoBarrasInterno(generarCodigoInternoDesdeNombre('Almendra')),
        isTrue,
      );
      expect(esCodigoBarrasInterno('#alm'), isTrue);
    });

    test('no confunde codigos reales como internos', () {
      expect(esCodigoBarrasInterno('7501234567890'), isFalse);
      expect(esCodigoBarrasInterno('ABC-1234'), isFalse);
      expect(esCodigoBarrasInterno(''), isFalse);
    });
  });

  test('Producto.codigoBarrasVisible oculta codigo interno', () {
    final interno = _producto(
      '1',
      'Almendra',
      codigo: generarCodigoInternoDesdeNombre('Almendra'),
    );
    expect(interno.tieneCodigoInterno, isTrue);
    expect(interno.codigoBarrasVisible, '');

    final real = _producto('2', 'Aceite', codigo: '7501234567890');
    expect(real.tieneCodigoInterno, isFalse);
    expect(real.codigoBarrasVisible, '7501234567890');
  });
}
