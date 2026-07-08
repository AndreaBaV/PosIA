import 'package:posia_core/posia_core.dart';
import 'package:posia_voice/posia_voice.dart';
import 'package:test/test.dart';

Producto _producto(
	String id,
	String nombre, {
	String? categoriaId,
	UnidadMedida unidad = UnidadMedida.litro,
}) {
	return Producto(
		id: id,
		nombre: nombre,
		codigoBarras: '',
		precioBase: 26.00,
		unidadMedida: unidad,
		rutaImagen: '',
		activo: true,
		tiendaId: 'tienda-test',
		categoriaId: categoriaId,
	);
}

void main() {
	final resolver = const ResolvedorProductoVoz();
	final leches = [
		_producto('l1', 'Leche Alpura Entera 1L', categoriaId: 'cat-lacteos'),
		_producto('l2', 'Leche Alpura Deslactosada 1L', categoriaId: 'cat-lacteos'),
		_producto('l3', 'Leche Lala Entera 1L', categoriaId: 'cat-lacteos'),
		_producto('l4', 'Leche Lala Light 1L', categoriaId: 'cat-lacteos'),
		_producto('l5', 'Leche Santa Clara Entera 1L', categoriaId: 'cat-lacteos'),
		_producto('l6', 'Leche Santa Clara Deslactosada 1L', categoriaId: 'cat-lacteos'),
		_producto('l7', 'Leche Nutri Entera 1L', categoriaId: 'cat-lacteos'),
		_producto('l8', 'Leche Nutri Deslactosada 1L', categoriaId: 'cat-lacteos'),
		_producto('l9', 'Leche Choco Lala 1L', categoriaId: 'cat-lacteos'),
		_producto('l10', 'Leche Alpura Protein 1L', categoriaId: 'cat-lacteos'),
	];
	const nombresCategoria = {
		'cat-lacteos': 'Lacteos',
		'cat-bebidas': 'Bebidas',
		'cat-abarrotes': 'Abarrotes',
	};

	test('leche generica es ambigua con muchas opciones', () {
		final resultado = resolver.resolver(consulta: 'leche', catalogo: leches);
		expect(resultado.estado, EstadoResolucionProductoVoz.ambiguo);
		expect(resultado.candidatos.length, greaterThan(1));
	});

	test('leche con marca y tipo resuelve un producto', () {
		final resultado = resolver.resolver(
			consulta: 'leche alpura deslactosada',
			catalogo: leches,
		);
		expect(resultado.estado, EstadoResolucionProductoVoz.unico);
		expect(resultado.producto?.nombre, 'Leche Alpura Deslactosada 1L');
	});

	test('categoria + marca desambigua entre categorias', () {
		final catalogo = [
			_producto('b1', 'Jugo Alpura Naranja', categoriaId: 'cat-bebidas'),
			_producto('l1', 'Leche Alpura Entera 1L', categoriaId: 'cat-lacteos'),
			_producto('a1', 'Arroz Saman 1kg', categoriaId: 'cat-abarrotes', unidad: UnidadMedida.pieza),
		];
		final resultado = resolver.resolver(
			consulta: 'bebidas alpura',
			catalogo: catalogo,
			nombresCategoria: nombresCategoria,
		);
		expect(resultado.estado, EstadoResolucionProductoVoz.unico);
		expect(resultado.producto?.id, 'b1');
	});

	test('solo categoria queda ambigua si hay varios productos', () {
		final catalogo = [
			_producto('b1', 'Jugo Alpura Naranja', categoriaId: 'cat-bebidas'),
			_producto('b2', 'Refresco Cola', categoriaId: 'cat-bebidas'),
			_producto('a1', 'Arroz Saman 1kg', categoriaId: 'cat-abarrotes', unidad: UnidadMedida.pieza),
		];
		final resultado = resolver.resolver(
			consulta: 'bebidas',
			catalogo: catalogo,
			nombresCategoria: nombresCategoria,
		);
		expect(resultado.estado, EstadoResolucionProductoVoz.ambiguo);
		expect(resultado.candidatos.every((c) => c.producto.categoriaId == 'cat-bebidas'), isTrue);
	});

	test('nombre + categoria resuelve leche de lacteos', () {
		final catalogo = [
			_producto('l2', 'Leche Alpura Deslactosada 1L', categoriaId: 'cat-lacteos'),
			_producto('b1', 'Bebida de avena', categoriaId: 'cat-bebidas'),
		];
		final resultado = resolver.resolver(
			consulta: 'leche de lacteos',
			catalogo: catalogo,
			nombresCategoria: nombresCategoria,
		);
		expect(resultado.estado, EstadoResolucionProductoVoz.unico);
		expect(resultado.producto?.id, 'l2');
	});

	test('motor usa nombres de categoria al procesar', () {
		final motor = MotorComandosVoz();
		final resultado = motor.procesar(
			texto: 'una bebidas alpura',
			catalogo: [
				_producto('b1', 'Jugo Alpura Naranja', categoriaId: 'cat-bebidas'),
				_producto('l1', 'Leche Alpura Entera 1L', categoriaId: 'cat-lacteos'),
			],
			nombresCategoria: nombresCategoria,
		);
		expect(resultado.lineas.single.producto.id, 'b1');
		expect(resultado.lineasAmbiguas, isEmpty);
	});

	test('motor marca leche generica como ambigua', () {
		final motor = MotorComandosVoz();
		final resultado = motor.procesar(
			texto: 'dos leche y un arroz',
			catalogo: [
				...leches,
				_producto(
					'arroz',
					'Arroz 1kg',
					unidad: UnidadMedida.pieza,
				),
			],
		);
		expect(resultado.lineas.single.producto.nombre, 'Arroz 1kg');
		expect(resultado.lineasAmbiguas.single.consultaOriginal, 'leche');
		expect(resultado.lineasAmbiguas.single.cantidadHablada, 2.0);
	});
}
