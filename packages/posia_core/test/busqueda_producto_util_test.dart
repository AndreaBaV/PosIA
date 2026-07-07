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
}
