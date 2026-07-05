import 'package:posia_core/posia_core.dart';
import 'package:posia_voice/posia_voice.dart';
import 'package:test/test.dart';

Producto _leche(String id, String nombre) {
	return Producto(
		id: id,
		nombre: nombre,
		codigoBarras: '',
		precioBase: 26.00,
		unidadMedida: UnidadMedida.litro,
		rutaImagen: '',
		activo: true,
		tiendaId: 'tienda-test',
	);
}

void main() {
	final resolver = const ResolvedorProductoVoz();
	final leches = [
		_leche('l1', 'Leche Alpura Entera 1L'),
		_leche('l2', 'Leche Alpura Deslactosada 1L'),
		_leche('l3', 'Leche Lala Entera 1L'),
		_leche('l4', 'Leche Lala Light 1L'),
		_leche('l5', 'Leche Santa Clara Entera 1L'),
		_leche('l6', 'Leche Santa Clara Deslactosada 1L'),
		_leche('l7', 'Leche Nutri Entera 1L'),
		_leche('l8', 'Leche Nutri Deslactosada 1L'),
		_leche('l9', 'Leche Choco Lala 1L'),
		_leche('l10', 'Leche Alpura Protein 1L'),
	];

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

	test('motor marca leche generica como ambigua', () {
		final motor = MotorComandosVoz();
		final resultado = motor.procesar(
			texto: 'dos leche y un arroz',
			catalogo: [
				...leches,
				const Producto(
					id: 'arroz',
					nombre: 'Arroz 1kg',
					codigoBarras: '',
					precioBase: 24.5,
					unidadMedida: UnidadMedida.pieza,
					rutaImagen: '',
					activo: true,
					tiendaId: 'tienda-test',
				),
			],
		);
		expect(resultado.lineas.single.producto.nombre, 'Arroz 1kg');
		expect(resultado.lineasAmbiguas.single.consultaOriginal, 'leche');
		expect(resultado.lineasAmbiguas.single.cantidadHablada, 2.0);
	});
}
