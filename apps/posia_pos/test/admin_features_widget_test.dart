/// Widget tests de pantallas admin (créditos, cotizaciones, existencias).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_pos/providers/admin_providers.dart';
import 'package:posia_pos/providers/inventario_admin_providers.dart';
import 'package:posia_pos/screens/pantalla_cotizaciones_admin.dart';
import 'package:posia_pos/screens/pantalla_creditos_pendientes.dart';
import 'package:posia_pos/screens/pantalla_inventario_admin.dart';

import '../../../packages/posia_database/test/fixture_servicio_admin.dart';

void main() {
	group('Créditos admin', () {
		testWidgets('estado vacío muestra un solo botón Nuevo crédito (FAB)', (tester) async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			addTearDown(fixture.cerrar);

			await tester.pumpWidget(
				ProviderScope(
					overrides: [
						servicioAdminProvider.overrideWith((ref) async => servicio),
					],
					child: const MaterialApp(home: PantallaCreditosPendientes()),
				),
			);
			await tester.pumpAndSettle();

			expect(find.text('Nuevo crédito'), findsOneWidget);
			expect(find.byType(FloatingActionButton), findsOneWidget);
			expect(find.text('No hay créditos pendientes'), findsOneWidget);
		});
	});

	group('Cotizaciones admin', () {
		testWidgets('muestra FAB Nueva cotización', (tester) async {
			final fixture = await FixtureAdmin.abrir();
			final servicio = fixture.crearServicio(tiendaId: fixture.tiendaOrigenId);
			addTearDown(fixture.cerrar);

			await tester.pumpWidget(
				ProviderScope(
					overrides: [
						servicioAdminProvider.overrideWith((ref) async => servicio),
					],
					child: const MaterialApp(home: PantallaCotizacionesAdmin()),
				),
			);
			await tester.pumpAndSettle();

			expect(find.text('Nueva cotización'), findsOneWidget);
			expect(find.byType(FloatingActionButton), findsOneWidget);
		});
	});

	group('Existencias admin', () {
		testWidgets('muestra resumen tiendas almacenes y total empresa', (tester) async {
			final datos = DatosInventarioAgrupado(
				registros: const [
					InventarioAgrupado(
						productoId: 'p1',
						nombreProducto: 'Grava',
						existenciasPorTienda: {'Origen': 4.0},
						existenciasPorTiendaId: {'t1': 4.0},
						stockMinimoPorTiendaId: {'t1': 0.0},
						existenciasPorAlmacen: {'Norte': 5.0, 'Sur': 3.0},
						existenciasPorAlmacenId: {'a1': 5.0, 'a2': 3.0},
						stockMinimoPorAlmacenId: {},
						stockMinimoLocal: 0.0,
						cantidadLocal: 4.0,
					),
				],
				tiendaReferenciaId: 't1',
				nombresTienda: {'t1': 'Origen'},
				nombresAlmacen: {'a1': 'Norte', 'a2': 'Sur'},
			);

			await tester.pumpWidget(
				ProviderScope(
					overrides: [
						tiendasInventarioProvider.overrideWith(
							(ref) async => [
								Tienda(
									id: 't1',
									nombre: 'Origen',
									direccion: 'Calle 1',
									activa: true,
								),
							],
						),
						inventarioAgrupadoProvider('t1').overrideWith((ref) async => datos),
					],
					child: const MaterialApp(home: PantallaInventarioAdmin()),
				),
			);
			await tester.pumpAndSettle();

			expect(find.text('Resumen general'), findsOneWidget);
			expect(find.text('En tiendas'), findsOneWidget);
			expect(find.text('En almacenes'), findsOneWidget);
			expect(find.text('Total empresa'), findsOneWidget);
			expect(find.text('Grava'), findsOneWidget);
		});
	});
}
