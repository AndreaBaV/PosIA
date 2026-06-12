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

		expect(find.text('Nombre y categoria son obligatorios'), findsOneWidget);
	});
}
