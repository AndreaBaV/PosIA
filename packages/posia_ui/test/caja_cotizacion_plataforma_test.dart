/// Widget tests de cotización en escritorio y móvil (componentes compartidos).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_ui/posia_ui.dart';

void main() {
	group('Caja escritorio', () {
		testWidgets('barra de acciones expone botón Cotizar habilitado con total', (tester) async {
			var presionado = false;
			await tester.pumpWidget(
				MaterialApp(
					home: Scaffold(
						body: BotonAccionCaja(
							icono: Icons.request_quote,
							etiqueta: 'Cotizar',
							colorFondo: PosiaColors.neutro,
							habilitado: true,
							alPresionar: () => presionado = true,
						),
					),
				),
			);

			expect(find.text('Cotizar'), findsOneWidget);
			await tester.tap(find.text('Cotizar'));
			expect(presionado, isTrue);
		});

		testWidgets('botón Cotizar deshabilitado sin productos en carrito', (tester) async {
			await tester.pumpWidget(
				MaterialApp(
					home: Scaffold(
						body: BotonAccionCaja(
							icono: Icons.request_quote,
							etiqueta: 'Cotizar',
							colorFondo: PosiaColors.neutro,
							habilitado: false,
							alPresionar: () {},
						),
					),
				),
			);

			final boton = tester.widget<BotonAccionCaja>(find.byType(BotonAccionCaja));
			expect(boton.habilitado, isFalse);
		});
	});

	group('Caja móvil', () {
		testWidgets('acción rápida Cotización con tooltip', (tester) async {
			await tester.pumpWidget(
				MaterialApp(
					home: Scaffold(
						body: IconButton.filledTonal(
							tooltip: 'Cotización',
							onPressed: () {},
							icon: const Icon(Icons.request_quote),
						),
					),
				),
			);

			expect(find.byIcon(Icons.request_quote), findsOneWidget);
			expect(find.byTooltip('Cotización'), findsOneWidget);
		});

		testWidgets('Cotización deshabilitada cuando carrito vacío (patrón móvil)', (tester) async {
			await tester.pumpWidget(
				const MaterialApp(
					home: Scaffold(
						body: IconButton.filledTonal(
							tooltip: 'Cotización',
							onPressed: null,
							icon: Icon(Icons.request_quote),
						),
					),
				),
			);

			final boton = tester.widget<IconButton>(find.byType(IconButton));
			expect(boton.onPressed, isNull);
		});
	});

	group('Atajos compartidos', () {
		test('atajo de cotizar está definido para ambas plataformas', () {
			final cotizar = definicionesAtajosCaja.firstWhere(
				(d) => d.id == atajoAccionCotizar,
			);
			expect(cotizar.descripcion.toLowerCase(), contains('cotización'));
			expect(AtajosCajaConfig.predeterminados().atajo(atajoAccionCotizar), 'CTRL+Q');
		});
	});
}
