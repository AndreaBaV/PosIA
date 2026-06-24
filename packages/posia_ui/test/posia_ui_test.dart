import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

void main() {
	testWidgets('BarraCategorias muestra chip Todos', (tester) async {
		await tester.pumpWidget(
			MaterialApp(
				home: Scaffold(
					body: BarraCategorias(
						categorias: const [],
						categoriaSeleccionadaId: CATEGORIA_TODOS_ID,
						alSeleccionar: (_) {},
					),
				),
			),
		);
		expect(find.text('Todos'), findsOneWidget);
	});

	test('AtajosCajaConfig fusiona JSON parcial con predeterminados', () {
		final config = AtajosCajaConfig.desdeJson(
			'{"cobrar":"F10","creditos":"CTRL+T"}',
		);
		expect(config.atajo(atajoAccionCobrar), 'F10');
		expect(config.atajo(atajoAccionCreditos), 'CTRL+T');
		expect(config.atajo(atajoAccionAdmin), 'CTRL+SHIFT+A');
	});

	test('etiquetaAtajoConfigurado normaliza vacio', () {
		expect(etiquetaAtajoConfigurado(''), teclaCobrarPredeterminada);
		expect(etiquetaAtajoConfigurado('ctrl+t'), 'CTRL+T');
	});
}
