/// La huella de catalogo debe dar el MISMO hash sin importar el orden en
/// que llegan las filas (Postgres y SQLite no garantizan el mismo orden de
/// lectura) y debe cambiar ante cualquier diferencia de una sola fila,
/// aunque el conteo total coincida.
library;

import 'package:posia_core/posia_core.dart';
import 'package:test/test.dart';

void main() {
	group('calcularHuellaCatalogo', () {
		test('es insensible al orden de las filas', () {
			const a = FilaHuellaProducto(id: '1', nombre: 'Pistache', codigoBarras: '111');
			const b = FilaHuellaProducto(id: '2', nombre: 'Nuez', codigoBarras: '222');

			final huellaOrdenA = calcularHuellaCatalogo([a, b]);
			final huellaOrdenB = calcularHuellaCatalogo([b, a]);

			expect(huellaOrdenA, huellaOrdenB);
		});

		test('cambia si un producto falta, aunque el conteo total coincida', () {
			const catalogoCompleto = [
				FilaHuellaProducto(id: '1', nombre: 'Pistache', codigoBarras: '111'),
				FilaHuellaProducto(id: '2', nombre: 'Nuez', codigoBarras: '222'),
			];
			// Mismo total (2 filas), pero la segunda es un producto distinto:
			// esto es exactamente lo que un conteo + muestra al azar puede no
			// detectar y que la huella si atrapa.
			const catalogoDivergente = [
				FilaHuellaProducto(id: '1', nombre: 'Pistache', codigoBarras: '111'),
				FilaHuellaProducto(id: '3', nombre: 'Avellana', codigoBarras: '333'),
			];

			expect(
				calcularHuellaCatalogo(catalogoCompleto),
				isNot(calcularHuellaCatalogo(catalogoDivergente)),
			);
		});

		test('cambia si el nombre de un producto cambio (misma id, mismo codigo)', () {
			const antes = [
				FilaHuellaProducto(id: '1', nombre: 'Pistache', codigoBarras: '111'),
			];
			const despues = [
				FilaHuellaProducto(id: '1', nombre: 'Pistache 500g', codigoBarras: '111'),
			];

			expect(calcularHuellaCatalogo(antes), isNot(calcularHuellaCatalogo(despues)));
		});

		test('catalogo vacio produce una huella estable', () {
			expect(calcularHuellaCatalogo(const []), calcularHuellaCatalogo(const []));
		});
	});

	group('HuellaCatalogo.coincideCon', () {
		test('coincide solo si productos, categorias y huella son iguales', () {
			const filas = [
				FilaHuellaProducto(id: '1', nombre: 'Pistache', codigoBarras: '111'),
			];
			final huellaA = HuellaCatalogo(
				productosActivos: 1,
				categoriasActivas: 3,
				huellaProductos: calcularHuellaCatalogo(filas),
			);
			final huellaB = HuellaCatalogo(
				productosActivos: 1,
				categoriasActivas: 3,
				huellaProductos: calcularHuellaCatalogo(filas),
			);
			final huellaCategoriaDistinta = HuellaCatalogo(
				productosActivos: 1,
				categoriasActivas: 4,
				huellaProductos: calcularHuellaCatalogo(filas),
			);

			expect(huellaA.coincideCon(huellaB), isTrue);
			expect(huellaA.coincideCon(huellaCategoriaDistinta), isFalse);
		});

		test('serializa y reconstruye desde JSON sin perder informacion', () {
			const original = HuellaCatalogo(
				productosActivos: 5,
				categoriasActivas: 2,
				huellaProductos: 'abc123',
			);

			final reconstruida = HuellaCatalogo.desdeJson(original.aJson());

			expect(reconstruida.coincideCon(original), isTrue);
		});
	});
}
