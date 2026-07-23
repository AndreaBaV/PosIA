/// Tests para la captura numérica por teclado físico y banner inline en
/// diálogos de cantidad y peso (se quitó el teclado numérico en pantalla).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

Producto _productoPrueba({UnidadMedida unidad = UnidadMedida.pieza}) {
	return Producto(
		id: 'p1',
		nombre: 'Producto de prueba',
		codigoBarras: '000001',
		precioBase: 10.0,
		unidadMedida: unidad,
		rutaImagen: '',
		activo: true,
		tiendaId: 't1',
		categoriaId: CATEGORIA_TODOS_ID,
	);
}

Future<void> _configurarSuperficie(WidgetTester tester) async {
	await tester.binding.setSurfaceSize(const Size(900.0, 1400.0));
	addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _abrirDialogoCantidad(WidgetTester tester) async {
	await _configurarSuperficie(tester);
	await tester.pumpWidget(
		MaterialApp(
			home: Scaffold(
				body: Builder(
					builder: (context) => ElevatedButton(
						onPressed: () => DialogoCantidadProducto.mostrar(
							context,
							_productoPrueba(),
						),
						child: const Text('Abrir'),
					),
				),
			),
		),
	);
	await tester.tap(find.text('Abrir'));
	await tester.pumpAndSettle();
}

Future<void> _abrirDialogoPeso(WidgetTester tester) async {
	await _configurarSuperficie(tester);
	await tester.pumpWidget(
		MaterialApp(
			home: Scaffold(
				body: Builder(
					builder: (context) => ElevatedButton(
						onPressed: () => DialogoPesoCarniceria.mostrar(
							context,
							_productoPrueba(unidad: UnidadMedida.kilogramo),
						),
						child: const Text('Abrir'),
					),
				),
			),
		),
	);
	await tester.tap(find.text('Abrir'));
	await tester.pumpAndSettle();
}

void main() {
	group('BannerMensajeDialogo', () {
		testWidgets('renderiza el mensaje con estilo de error por defecto',
			(tester) async {
			await tester.pumpWidget(
				const MaterialApp(
					home: Scaffold(
						body: BannerMensajeDialogo(mensaje: 'Monto insuficiente'),
					),
				),
			);
			expect(find.text('Monto insuficiente'), findsOneWidget);
			expect(find.byIcon(Icons.error_outline), findsOneWidget);
		});

		testWidgets('el tipo aviso usa icono info_outline', (tester) async {
			await tester.pumpWidget(
				const MaterialApp(
					home: Scaffold(
						body: BannerMensajeDialogo(
							mensaje: 'Confirme el cliente',
							tipo: TipoMensajeDialogo.aviso,
						),
					),
				),
			);
			expect(find.byIcon(Icons.info_outline), findsOneWidget);
			expect(find.byIcon(Icons.error_outline), findsNothing);
		});
	});

	group('DialogoCantidadProducto', () {
		testWidgets('usa teclado físico numérico y mantiene cursor visible',
			(tester) async {
			await _abrirDialogoCantidad(tester);

			final campoCantidad = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == 'Cantidad',
			);
			expect(campoCantidad, findsOneWidget);
			final textField = tester.widget<TextField>(campoCantidad);
			expect(
				textField.keyboardType,
				const TextInputType.numberWithOptions(decimal: true),
			);
			expect(textField.showCursor, isTrue);

			await tester.tap(find.text('Cancelar'));
			await tester.pumpAndSettle();
		});

		testWidgets('muestra banner inline (no SnackBar) al confirmar cantidad inválida',
			(tester) async {
			await _abrirDialogoCantidad(tester);

			final campoCantidad = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == 'Cantidad',
			);
			await tester.enterText(campoCantidad, '0');
			await tester.pump();

			await tester.tap(find.text('Agregar'));
			await tester.pumpAndSettle();

			expect(find.byType(BannerMensajeDialogo), findsOneWidget);
			expect(find.text('Indique una cantidad mayor a cero'), findsOneWidget);
			expect(find.byType(SnackBar), findsNothing);

			await tester.enterText(campoCantidad, '2');
			await tester.pump();
			expect(find.byType(BannerMensajeDialogo), findsNothing);

			await tester.tap(find.text('Cancelar'));
			await tester.pumpAndSettle();
		});
	});

	group('DialogoPesoCarniceria', () {
		testWidgets('usa teclado físico numérico y mantiene cursor visible',
			(tester) async {
			await _abrirDialogoPeso(tester);

			final campoPeso = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == 'Peso',
			);
			expect(campoPeso, findsOneWidget);
			final textField = tester.widget<TextField>(campoPeso);
			expect(
				textField.keyboardType,
				const TextInputType.numberWithOptions(decimal: true),
			);
			expect(textField.showCursor, isTrue);

			await tester.tap(find.text('Cancelar'));
			await tester.pumpAndSettle();
		});

		testWidgets('muestra banner inline (no SnackBar) al confirmar sin peso',
			(tester) async {
			await _abrirDialogoPeso(tester);

			await tester.tap(find.text('Agregar'));
			await tester.pumpAndSettle();

			expect(find.byType(BannerMensajeDialogo), findsOneWidget);
			expect(find.text('Indique un peso mayor a cero'), findsOneWidget);
			expect(find.byType(SnackBar), findsNothing);

			final campoPeso = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == 'Peso',
			);
			await tester.enterText(campoPeso, '1');
			await tester.pump();
			expect(find.byType(BannerMensajeDialogo), findsNothing);

			await tester.tap(find.text('Cancelar'));
			await tester.pumpAndSettle();
		});
	});
}
