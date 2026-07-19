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

		// Sin ninguna categoría activa disponible no se autoselecciona ninguna,
		// así que el alta se detiene pidiendo que se elija una.
		expect(find.text('Seleccione una categoría'), findsOneWidget);
	});

	testWidgets(
		'editar producto con categoría desactivada permite guardar',
		(tester) async {
			const categoriaInactiva = Categoria(
				id: categoriaPruebaId,
				nombre: 'Semillas',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 0,
				activa: false,
			);
			const existente = Producto(
				id: 'prod-1',
				nombre: 'Arroz Quebrado',
				codigoBarras: '',
				precioBase: 18.0,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-centro',
				categoriaId: categoriaPruebaId,
				costoUnitario: 12.0,
			);

			await tester.pumpWidget(
				ProviderScope(
					overrides: [
						categoriasFormularioAdminProvider.overrideWithValue(
							const AsyncValue.data([categoriaInactiva]),
						),
						proveedoresFormularioAdminProvider.overrideWithValue(
							const AsyncValue.data([]),
						),
					],
					child: const MaterialApp(
						home: PantallaFormularioProducto(productoExistente: existente),
					),
				),
			);
			await tester.pump();

			await tester.tap(find.text('Guardar producto'));
			await tester.pump();
			// Sin pumpAndSettle: superada la validación, el guardado espera a
			// servicioAdminProvider, que este test no provee. Basta con dar tiempo
			// a que el SnackBar de error habría aparecido.
			await tester.pump(const Duration(milliseconds: 300));

			// El desplegable ofrece la categoría huérfana del producto; el guardado
			// no debe rechazar justo lo que la pantalla deja elegir.
			expect(
				find.textContaining('está desactivada'),
				findsNothing,
				reason: 'un producto no debe quedar bloqueado por una categoría '
					'que se desactivó después de crearlo',
			);
		},
	);
}
