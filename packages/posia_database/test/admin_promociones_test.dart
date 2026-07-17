/// Pruebas de AdminPromociones: sugerencia por familia y CRUD de lotes/combos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'fixture_servicio_admin.dart';

void main() {
	group('AdminPromociones', () {
		test('sugerirMiembrosDeFamilia incluye el padre y sus variantes activas', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final padre = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Sopas La Moderna Pollo',
					codigoBarras: 'fam-001',
					precioBase: 12.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 30.0,
				),
			);
			final variante = await admin.registrarVariante(
				productoPadreId: padre.id,
				nombre: 'Res',
				sku: 'fam-002-sku',
				codigoBarras: 'fam-002',
				precioBase: 12.0,
			);

			final miembros = await admin.sugerirMiembrosDeFamilia(padre.id);

			expect(miembros.map((m) => m.productoId), containsAll([padre.id, variante.id]));
			expect(
				miembros.firstWhere((m) => m.productoId == variante.id).nombre,
				contains('Res'),
			);
		});

		test('lote con miembro de variante no crea un producto placeholder', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final padre = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Sopas La Moderna Pollo',
					codigoBarras: 'fam-011',
					precioBase: 12.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 30.0,
				),
			);
			final variante = await admin.registrarVariante(
				productoPadreId: padre.id,
				nombre: 'Verduras',
				sku: 'fam-012-sku',
				codigoBarras: 'fam-012',
				precioBase: 12.0,
			);

			final lote = await admin.guardarLotePromocion(
				nombre: 'Sopas La Moderna',
				cantidadMinima: 20.0,
				precioUnitario: 9.5,
				productoIds: [padre.id, variante.id],
			);

			final relectura = await admin.obtenerLotePromocion(lote.id);
			expect(relectura, isNotNull);
			expect(relectura!.productoIds, containsAll([padre.id, variante.id]));

			final stub = await ProductoRepository(baseDatos: fixture.base).obtenerPorId(variante.id);
			expect(stub, isNotNull, reason: 'el FK exige una fila stub para el id de la variante');
			expect(
				stub!.nombre,
				isNot('Producto'),
				reason: 'el stub FK debe reflejar los datos reales de la variante, no un placeholder generico',
			);
			expect(stub.nombre, contains('Verduras'));
		});

		test('guardarCombo y eliminarCombo (baja logica)', () async {
			final fixture = await FixtureAdmin.abrir();
			final admin = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			final shampoo = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Shampoo',
					codigoBarras: 'fam-021',
					precioBase: 100.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 10.0,
				),
			);
			final acondicionador = await admin.registrarProductoCompleto(
				AltaProductoRequest(
					nombre: 'Acondicionador',
					codigoBarras: 'fam-022',
					precioBase: 80.0,
					categoriaId: fixture.categoriaId,
					stockInicial: 10.0,
				),
			);

			final combo = await admin.guardarCombo(
				nombre: 'Kit cabello',
				precioCombo: 150.0,
				miembros: [
					ComboMiembro(productoId: shampoo.id),
					ComboMiembro(productoId: acondicionador.id),
				],
			);

			var relectura = await admin.obtenerCombo(combo.id);
			expect(relectura!.activo, isTrue);
			expect(relectura.miembros, hasLength(2));

			await admin.eliminarCombo(combo.id);
			relectura = await admin.obtenerCombo(combo.id);
			expect(relectura!.activo, isFalse);
			expect(
				relectura.miembros,
				hasLength(2),
				reason: 'la baja logica no debe perder el historial de miembros',
			);
		});
	});
}
