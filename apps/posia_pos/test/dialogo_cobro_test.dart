/// Tests del dialogo de cobro (multipago) en caja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_pos/widgets/dialogo_cobro.dart';
import 'package:posia_ui/posia_ui.dart';

class _CapturaCobro {
	CobroRequest? request;
	bool completado = false;
}

Future<_CapturaCobro> _abrirDialogo(WidgetTester tester, {double subtotal = 100.0}) async {
	final captura = _CapturaCobro();
	await tester.pumpWidget(
		MaterialApp(
			home: Scaffold(
				body: Builder(
					builder: (context) => Center(
						child: ElevatedButton(
							onPressed: () async {
								captura.request = await mostrarDialogoCobro(
									context: context,
									subtotal: subtotal,
								);
								captura.completado = true;
							},
							child: const Text('Abrir'),
						),
					),
				),
			),
		),
	);
	await tester.tap(find.text('Abrir'));
	await tester.pumpAndSettle();
	return captura;
}

void main() {
	group('DialogoCobro', () {
		testWidgets('muestra TextField editable para monto recibido con teclado numérico',
			(tester) async {
			// El campo Recibido debe ser TextField editable con teclado numérico
			// del sistema (decimal). ContenidoDialogoTeclado evita que el teclado
			// tape el contenido del diálogo al desplazar el scroll.
			final captura = await _abrirDialogo(tester);

			expect(find.text('Cobrar venta'), findsOneWidget);
			expect(find.text(r'Recibido ($)'), findsOneWidget);
			final campoRecibido = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == r'Recibido ($)',
			);
			expect(campoRecibido, findsOneWidget);
			final textField = tester.widget<TextField>(campoRecibido);
			expect(
				textField.keyboardType,
				const TextInputType.numberWithOptions(decimal: true),
			);
			expect(textField.showCursor, isTrue);

			await tester.tap(find.text('Cancelar'));
			await tester.pumpAndSettle();
			expect(captura.completado, isTrue);
			expect(captura.request, isNull);
		});

		testWidgets('mensajes de retroalimentación aparecen dentro del diálogo, no como SnackBar',
			(tester) async {
			// Los mensajes de error deben mostrarse como banner dentro del diálogo,
			// no como SnackBar oculto detrás del teclado del sistema.
			await tester.binding.setSurfaceSize(const Size(800.0, 1200.0));
			addTearDown(() => tester.binding.setSurfaceSize(null));

			final captura = await _abrirDialogo(tester, subtotal: 500.0);

			final campoRecibido = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == r'Recibido ($)',
			);
			await tester.enterText(campoRecibido, '100');
			await tester.pump();

			await tester.tap(find.text('COBRAR (Enter)'));
			await tester.pumpAndSettle();

			expect(find.byType(BannerMensajeDialogo), findsOneWidget);
			expect(find.text('Monto recibido insuficiente'), findsOneWidget);
			expect(find.byType(SnackBar), findsNothing);
			expect(captura.completado, isFalse);

			await tester.enterText(campoRecibido, '600');
			await tester.pump();
			expect(find.byType(BannerMensajeDialogo), findsNothing);

			await tester.tap(find.text('Cancelar'));
			await tester.pumpAndSettle();
		});

		testWidgets('permite escribir el monto recibido y devuelve CobroRequest',
			(tester) async {
			final captura = await _abrirDialogo(tester, subtotal: 120.0);

			final campoRecibido = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == r'Recibido ($)',
			);
			expect(campoRecibido, findsOneWidget);

			await tester.enterText(campoRecibido, '200');
			await tester.pump();

			expect(find.text('Cambio: \$80.00'), findsOneWidget);

			await tester.tap(find.text('COBRAR (Enter)'));
			await tester.pumpAndSettle();

			expect(captura.completado, isTrue);
			final request = captura.request;
			expect(request, isNotNull);
			expect(request!.metodoPago, MetodoPago.efectivo);
			expect(request.montoRecibido, 200.0);
		});

		testWidgets('cambio de método a Mixto muestra dos campos editables',
			(tester) async {
			final captura = await _abrirDialogo(tester, subtotal: 100.0);

			await tester.tap(find.widgetWithText(FilterChip, 'Mixto'));
			await tester.pumpAndSettle();

			final campoEfectivo = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == r'Efectivo ($)',
			);
			final campoTarjeta = find.byWidgetPredicate(
				(w) => w is TextField && w.decoration?.labelText == r'Tarjeta ($)',
			);
			expect(campoEfectivo, findsOneWidget);
			expect(campoTarjeta, findsOneWidget);

			await tester.enterText(campoEfectivo, '60');
			await tester.pump();
			await tester.enterText(campoTarjeta, '40');
			await tester.pump();

			await tester.tap(find.text('COBRAR (Enter)'));
			await tester.pumpAndSettle();

			expect(captura.completado, isTrue);
			final request = captura.request;
			expect(request, isNotNull);
			expect(request!.metodoPago, MetodoPago.mixto);
			expect(request.montoEfectivo, 60.0);
			expect(request.montoTarjeta, 40.0);
		});
	});
}
