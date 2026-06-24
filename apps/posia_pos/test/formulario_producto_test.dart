import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_pos/providers/admin_providers.dart';
import 'package:posia_pos/screens/pantalla_formulario_producto.dart';

import '../../../packages/posia_database/test/fixture_servicio_admin.dart';

void main() {
	testWidgets('formulario producto valida categoria requerida', (tester) async {
		final fixture = await FixtureAdmin.abrir();
		final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
		// Sin categorías activas el formulario no preselecciona ninguna.
		await fixture.base.update(
			'categories',
			{'activa': 0},
			where: 'id = ?',
			whereArgs: [categoriaPruebaId],
		);
		addTearDown(fixture.cerrar);

		await tester.pumpWidget(
			ProviderScope(
				overrides: [
					servicioAdminProvider.overrideWith((ref) async => servicio),
				],
				child: const MaterialApp(
					home: PantallaFormularioProducto(),
				),
			),
		);
		await tester.pumpAndSettle();

		await tester.enterText(
			find.widgetWithText(TextField, 'Nombre *'),
			'Producto prueba',
		);
		await tester.tap(find.byIcon(Icons.save));
		await tester.pump();
		await tester.pump(const Duration(milliseconds: 400));

		expect(find.text('Nombre y categoría son obligatorios'), findsOneWidget);
	});
}
