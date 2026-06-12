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
}
