/// Pruebas del calculo de descuento por combos de precio fijo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:test/test.dart';

Producto _producto(String id, {double precioBase = 100.0}) {
	return Producto(
		id: id,
		nombre: 'Producto $id',
		codigoBarras: id,
		precioBase: precioBase,
		unidadMedida: UnidadMedida.pieza,
		rutaImagen: '',
		activo: true,
		tiendaId: 't1',
	);
}

LineaCarrito _linea(String productoId, {double cantidad = 1.0, double precioUnitario = 100.0}) {
	return LineaCarrito(
		producto: _producto(productoId, precioBase: precioUnitario),
		cantidad: cantidad,
		precioUnitario: precioUnitario,
		reglaPrecio: ReglaPrecio.precioBase,
	);
}

Combo _combo({
	String id = 'combo-1',
	double precioCombo = 150.0,
	List<ComboMiembro> miembros = const [
		ComboMiembro(productoId: 'shampoo'),
		ComboMiembro(productoId: 'acondicionador'),
	],
}) {
	return Combo(id: id, nombre: 'Combo prueba', precioCombo: precioCombo, miembros: miembros);
}

void main() {
	test('combo completo con 1 de cada miembro aplica descuento', () {
		final lineas = [
			_linea('shampoo', precioUnitario: 100.0),
			_linea('acondicionador', precioUnitario: 80.0),
		];
		final aplicados = combosAplicadosEnCarrito([_combo(precioCombo: 150.0)], lineas);
		expect(aplicados, hasLength(1));
		expect(aplicados.first.veces, 1);
		// Normal 100+80=180, combo 150 -> ahorro 30
		expect(aplicados.first.ahorro, 30.0);
	});

	test('falta un miembro: no aplica combo', () {
		final lineas = [_linea('shampoo', precioUnitario: 100.0)];
		final aplicados = combosAplicadosEnCarrito([_combo()], lineas);
		expect(aplicados, isEmpty);
	});

	test('multiples sets completos multiplican el ahorro', () {
		final lineas = [
			_linea('shampoo', cantidad: 3.0, precioUnitario: 100.0),
			_linea('acondicionador', cantidad: 3.0, precioUnitario: 80.0),
		];
		final aplicados = combosAplicadosEnCarrito([_combo(precioCombo: 150.0)], lineas);
		expect(aplicados, hasLength(1));
		expect(aplicados.first.veces, 3);
		expect(aplicados.first.ahorro, 90.0);
	});

	test('cantidad dispareja entre miembros limita a los sets completables', () {
		final lineas = [
			_linea('shampoo', cantidad: 5.0, precioUnitario: 100.0),
			_linea('acondicionador', cantidad: 2.0, precioUnitario: 80.0),
		];
		final aplicados = combosAplicadosEnCarrito([_combo(precioCombo: 150.0)], lineas);
		expect(aplicados.first.veces, 2, reason: 'limitado por el miembro con menos unidades');
	});

	test('cantidadRequerida > 1 exige multiplos por set', () {
		final combo = _combo(
			precioCombo: 250.0,
			miembros: const [
				ComboMiembro(productoId: 'shampoo', cantidadRequerida: 2),
				ComboMiembro(productoId: 'acondicionador'),
			],
		);
		final lineas = [
			_linea('shampoo', cantidad: 4.0, precioUnitario: 100.0),
			_linea('acondicionador', cantidad: 2.0, precioUnitario: 80.0),
		];
		final aplicados = combosAplicadosEnCarrito([combo], lineas);
		// shampoo: floor(4/2)=2 sets; acondicionador: floor(2/1)=2 sets -> 2 sets
		expect(aplicados.first.veces, 2);
		// normal por set: 2*100 + 1*80 = 280, combo 250 -> ahorro 30/set * 2 = 60
		expect(aplicados.first.ahorro, 60.0);
	});

	test('combo sin ahorro real (precio combo mayor o igual) no se aplica', () {
		final lineas = [
			_linea('shampoo', precioUnitario: 100.0),
			_linea('acondicionador', precioUnitario: 80.0),
		];
		final aplicados = combosAplicadosEnCarrito([_combo(precioCombo: 200.0)], lineas);
		expect(aplicados, isEmpty);
	});

	test('linea de presentacion fija no cuenta para el combo', () {
		final lineaPresentacion = LineaCarrito(
			producto: _producto('shampoo', precioBase: 100.0),
			cantidad: 1.0,
			precioUnitario: 900.0,
			reglaPrecio: ReglaPrecio.precioBase,
			productoStockId: 'shampoo-caja',
		);
		final lineas = [lineaPresentacion, _linea('acondicionador', precioUnitario: 80.0)];
		final aplicados = combosAplicadosEnCarrito([_combo()], lineas);
		expect(aplicados, isEmpty);
	});

	test('combo inactivo excluido de la lista de activos no aplica', () {
		final lineas = [
			_linea('shampoo', precioUnitario: 100.0),
			_linea('acondicionador', precioUnitario: 80.0),
		];
		// combosActivos vacio simula que el combo esta inactivo (filtrado por el repo).
		final aplicados = combosAplicadosEnCarrito(const [], lineas);
		expect(aplicados, isEmpty);
	});

	test('calcularDescuentoCombos suma el ahorro de varios combos', () {
		final comboA = _combo(
			id: 'combo-a',
			precioCombo: 150.0,
			miembros: const [
				ComboMiembro(productoId: 'shampoo'),
				ComboMiembro(productoId: 'acondicionador'),
			],
		);
		final comboB = _combo(
			id: 'combo-b',
			precioCombo: 40.0,
			miembros: const [
				ComboMiembro(productoId: 'jabon'),
				ComboMiembro(productoId: 'esponja'),
			],
		);
		final lineas = [
			_linea('shampoo', precioUnitario: 100.0),
			_linea('acondicionador', precioUnitario: 80.0),
			_linea('jabon', precioUnitario: 25.0),
			_linea('esponja', precioUnitario: 20.0),
		];
		final total = calcularDescuentoCombos([comboA, comboB], lineas);
		// combo A: 180-150=30, combo B: 45-40=5 -> 35
		expect(total, 35.0);
	});
}
