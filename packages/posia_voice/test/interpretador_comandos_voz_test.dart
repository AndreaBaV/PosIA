import 'package:posia_core/posia_core.dart';
import 'package:posia_voice/posia_voice.dart';
import 'package:test/test.dart';

void main() {
	final motor = MotorComandosVoz();
	final catalogo = [
		const Producto(
			id: 'prod-arroz-1kg',
			nombre: 'Arroz 1kg',
			codigoBarras: '',
			precioBase: 24.50,
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-test',
		),
		const Producto(
			id: 'prod-frijol-peruano',
			nombre: 'Frijol peruano',
			codigoBarras: '',
			precioBase: 42.00,
			unidadMedida: UnidadMedida.kilogramo,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-test',
		),
		const Producto(
			id: 'prod-leche-1l',
			nombre: 'Leche 1L',
			codigoBarras: '',
			precioBase: 26.00,
			unidadMedida: UnidadMedida.litro,
			piezasPorCaja: 12,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-test',
		),
		const Producto(
			id: 'prod-atun-lata',
			nombre: 'Atun lata',
			codigoBarras: '',
			precioBase: 18.00,
			unidadMedida: UnidadMedida.pieza,
			piezasPorCaja: 24,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-test',
		),
		const Producto(
			id: 'prod-huevo-carton',
			nombre: 'Huevo carton 12',
			codigoBarras: '',
			precioBase: 45.00,
			unidadMedida: UnidadMedida.caja,
			rutaImagen: '',
			activo: true,
			tiendaId: 'tienda-test',
		),
	];

	final clientes = [
		const Cliente(
			id: 'cli-juan',
			nombre: 'Juan Perez',
			listaPreciosId: null,
			creditoHabilitado: false,
			activo: true,
		),
		const Cliente(
			id: 'cli-maria',
			nombre: 'Maria Garcia',
			listaPreciosId: null,
			creditoHabilitado: false,
			activo: true,
		),
	];

	test('interpreta ticket completo del ejemplo', () {
		final resultado = motor.procesar(
			texto:
				'Genera el ticket: vendi un kilogramo de arroz, medio kilo de frijol peruano y 1 caja de leche',
			catalogo: catalogo,
		);
		expect(resultado.intencion, IntencionComandoVoz.agregarProductos);
		expect(resultado.lineas.length, 3);
		expect(resultado.lineas[0].cantidad, 1.0);
		expect(resultado.lineas[1].cantidad, 0.5);
		expect(resultado.lineas[2].cantidad, 12.0);
		expect(resultado.noEncontrados, isEmpty);
	});

	test('caja de atun expande piezas por caja', () {
		final resultado = motor.procesar(
			texto: 'una caja de latas de atun',
			catalogo: catalogo,
		);
		expect(resultado.lineas.single.cantidad, 24.0);
	});

	test('caja de huevo es una unidad de caja', () {
		final resultado = motor.procesar(
			texto: '1 caja de huevo',
			catalogo: catalogo,
		);
		expect(resultado.lineas.single.cantidad, 1.0);
	});

	test('detecta cobrar', () {
		final resultado = motor.procesar(texto: 'cobrar en efectivo', catalogo: catalogo);
		expect(resultado.intencion, IntencionComandoVoz.cobrar);
	});

	test('divide varios productos sin conectores', () {
		final resultado = motor.procesar(
			texto: '2 arroz 3 leche 1 caja de atun',
			catalogo: catalogo,
		);
		expect(resultado.intencion, IntencionComandoVoz.agregarProductos);
		expect(resultado.lineas.length, 3);
		expect(resultado.lineas[0].cantidad, 2.0);
		expect(resultado.lineas[1].cantidad, 3.0);
	});

	test('resuelve cliente y productos en un solo comando', () {
		final resultado = motor.procesar(
			texto:
				'genera el ticket para el cliente juan perez: '
				'dos arroz y una leche',
			catalogo: catalogo,
			clientes: clientes,
		);
		expect(resultado.cliente?.nombre, 'Juan Perez');
		expect(resultado.lineas.length, 2);
		expect(resultado.noEncontrados, isEmpty);
	});

	test('cliente a nombre de y mostrador', () {
		final conCliente = motor.procesar(
			texto: 'a nombre de maria garcia un arroz',
			catalogo: catalogo,
			clientes: clientes,
		);
		expect(conCliente.cliente?.nombre, 'Maria Garcia');
		expect(conCliente.lineas.single.producto.nombre, 'Arroz 1kg');

		final mostrador = motor.procesar(
			texto: 'mostrador dos arroz',
			catalogo: catalogo,
			clientes: clientes,
		);
		expect(mostrador.usarMostrador, isTrue);
		expect(mostrador.lineas.single.cantidad, 2.0);
	});
}
