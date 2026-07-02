import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/providers/admin_providers.dart';
import 'package:posia_pos/screens/pantalla_formulario_producto.dart';

import '../../../packages/posia_database/test/fixture_servicio_admin.dart';

void main() {
	testWidgets('formulario producto valida categoria requerida', (tester) async {
		await tester.pumpWidget(
			ProviderScope(
				overrides: [
					categoriasFormularioAdminProvider.overrideWithValue(
						AsyncValue.data([
							Categoria(
								id: categoriaPruebaId,
								nombre: 'General',
								icono: 'shopping_basket',
								colorHex: '#4CAF50',
								orden: 0,
								activa: false,
							),
						]),
					),
					proveedoresFormularioAdminProvider.overrideWithValue(
						const AsyncValue.data([]),
					),
				],
				child: const MaterialApp(
					home: PantallaFormularioProducto(),
				),
			),
		);
		await tester.pump();

		await tester.enterText(
			find.widgetWithText(TextField, 'Nombre *'),
			'Producto prueba',
		);
		await tester.tap(find.text('Guardar producto'));
		await tester.pump();
		await tester.pumpAndSettle();

		expect(find.text('Nombre y categoría son obligatorios'), findsOneWidget);
	});
}
