/// Reproduccion: guardar un empaque de bulto sobre un producto existente.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'fixture_servicio_admin.dart';

void main() {
	test('guardarPresentacionProducto persiste un bulto de 25 kg', () async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);

		final producto = await servicio.registrarProductoCompleto(
			AltaProductoRequest(
				nombre: 'Arroz Morelos',
				codigoBarras: '7500000000123',
				precioBase: 25.0,
				costoUnitario: 15.0,
				categoriaId: fixture.categoriaId,
				unidadMedida: UnidadMedida.kilogramo,
			),
		);

		final antes = await servicio.listarPresentacionesProducto(producto.id);
		// ignore: avoid_print
		print('presentaciones tras el alta: '
			'${antes.map((p) => "${p.nombre}/${p.factorABase}").toList()}');

		final tipos = await servicio.listarTiposPresentacion();
		// ignore: avoid_print
		print('tipos de presentacion disponibles: ${tipos.length}');

		await servicio.guardarPresentacionProducto(
			productoId: producto.id,
			nombre: 'Bulto 25 kg',
			factorABase: 25.0,
			tipoPresentacionId: tipos
				.where((t) => t.id == 'tp-kg')
				.map((t) => t.id)
				.firstOrNull,
			precio: 600.0,
		);

		final despues = await servicio.listarPresentacionesProducto(producto.id);
		// ignore: avoid_print
		print('presentaciones tras guardar el bulto: '
			'${despues.map((p) => "${p.nombre}/${p.factorABase}").toList()}');

		expect(
			despues.where((p) => !p.esPresentacionBase && p.factorABase == 25.0),
			isNotEmpty,
			reason: 'el bulto de 25 kg debe quedar persistido',
		);

		await fixture.cerrar();
	});
}
