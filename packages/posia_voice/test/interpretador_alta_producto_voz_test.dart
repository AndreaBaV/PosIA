import 'package:posia_core/posia_core.dart';
import 'package:posia_voice/posia_voice.dart';
import 'package:test/test.dart';

void main() {
	final interpretador = InterpretadorAltaProductoVoz();

	test('parsea nombre precio costo categoria y stock', () {
		final b = interpretador.interpretar(
			'Producto Coca Cola precio 25 costo 18 categoria refrescos stock 40',
		);
		expect(b.nombre, 'Coca Cola');
		expect(b.precioBase, 25);
		expect(b.costoUnitario, 18);
		expect(b.nombreCategoria, 'Refrescos');
		expect(b.stockInicial, 40);
		expect(
			b.camposDetectados,
			containsAll(['nombre', 'precio', 'costo', 'categoria', 'stock']),
		);
		expect(b.lineasResumen, isNotEmpty);
	});

	test('detecta venta por kilo y precios de fraccion', () {
		final b = interpretador.interpretar(
			'Jitomate por kilo a 35 pesos medio kilo 20 cuarto 12',
		);
		expect(b.nombre, 'Jitomate');
		expect(b.unidadMedida, UnidadMedida.kilogramo);
		expect(b.precioBase, 35);
		expect(b.precioMedioKilo, 20);
		expect(b.precioCuartoKilo, 12);
	});

	test('parsea codigo y mayoreo', () {
		final b = interpretador.interpretar(
			'Nombre arroz codigo 7501234567890 precio 28.50 mayoreo desde 10 a 25',
		);
		expect(b.nombre, 'Arroz');
		expect(b.codigoBarras, '7501234567890');
		expect(b.precioBase, 28.50);
		expect(b.escalasMayoreo, hasLength(1));
		expect(b.escalasMayoreo.first.cantidadMinima, 10);
		expect(b.escalasMayoreo.first.precioUnitario, 25);
	});

	test('parsea proveedor minimo y notas', () {
		final b = interpretador.interpretar(
			'Leche Lala precio 28 proveedor Nestle minimo 5 nota caduca pronto',
		);
		expect(b.nombre, 'Leche Lala');
		expect(b.nombreProveedor, 'Nestle');
		expect(b.stockMinimo, 5);
		expect(b.notas, 'caduca pronto');
	});

	test('acepta montos hablados', () {
		final b = interpretador.interpretar(
			'Atun precio veinticinco costo dieciocho stock treinta',
		);
		expect(b.nombre, 'Atun');
		expect(b.precioBase, 25);
		expect(b.costoUnitario, 18);
		expect(b.stockInicial, 30);
	});

	test('acepta treinta y cinco como precio', () {
		final b = interpretador.interpretar(
			'Pan dulce precio treinta y cinco categoria panaderia',
		);
		expect(b.nombre, 'Pan Dulce');
		expect(b.precioBase, 35);
		expect(b.nombreCategoria, 'Panaderia');
	});

	test('prefijos registrar y alta de producto', () {
		final a = interpretador.interpretar(
			'Registrar producto jabon zote precio 15',
		);
		expect(a.nombre, 'Jabon Zote');
		expect(a.precioBase, 15);

		final b = interpretador.interpretar(
			'Alta de producto cloro precio 22',
		);
		expect(b.nombre, 'Cloro');
		expect(b.precioBase, 22);
	});

	test('no confunde litros con nombre si se vende por litro', () {
		final b = interpretador.interpretar(
			'Aceite se vende por litro precio 45',
		);
		expect(b.nombre, 'Aceite');
		expect(b.unidadMedida, UnidadMedida.litro);
		expect(b.precioBase, 45);
	});

	test('texto vacio no detecta campos', () {
		final b = interpretador.interpretar('   ');
		expect(b.tieneDatos, isFalse);
	});

	test('solo prefijo sin datos utiles', () {
		final b = interpretador.interpretar('producto');
		expect(b.tieneDatos, isFalse);
	});
}
