import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	sqfliteFfiInit();
	databaseFactory = databaseFactoryFfi;

	group('ProductoRepository vendible en tienda', () {
		late Database base;
		late ProductoRepository repo;
		late InventarioRepository inventario;

		const tiendaCentral = 'tienda-central';
		const tiendaSur = 'tienda-sur';

		setUp(() async {
			base = await openDatabase(
				inMemoryDatabasePath,
				version: SCHEMA_VERSION,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			repo = ProductoRepository(baseDatos: base);
			inventario = InventarioRepository(baseDatos: base);
			await base.insert('stores', {
				'id': tiendaCentral,
				'nombre': 'Central',
				'direccion': '',
				'activa': 1,
			});
			await base.insert('stores', {
				'id': tiendaSur,
				'nombre': 'Sur',
				'direccion': '',
				'activa': 1,
			});
		});

		tearDown(() => base.close());

		Future<void> _guardarLeche({required String tiendaId}) async {
			await repo.guardar(
				Producto(
					id: 'prod-leche',
					nombre: 'Leche entera',
					codigoBarras: '7501234567890',
					precioBase: 25.0,
					unidadMedida: UnidadMedida.pieza,
					rutaImagen: '',
					activo: true,
					tiendaId: tiendaId,
					moduloVertical: ModuloVertical.general,
				),
			);
		}

		test('listarActivosPorTienda incluye producto con stock traspasado', () async {
			await _guardarLeche(tiendaId: tiendaCentral);
			await inventario.guardarStock(
				StockNivel(
					productoId: 'prod-leche',
					tiendaId: tiendaSur,
					cantidad: 15,
					actualizadoEn: DateTime.utc(2026, 6, 30),
				),
			);

			final central = await repo.listarActivosPorTienda(tiendaCentral);
			final sur = await repo.listarActivosPorTienda(tiendaSur);

			expect(central.map((p) => p.id), contains('prod-leche'));
			expect(sur.map((p) => p.id), contains('prod-leche'));
		});

		test('buscarPorCodigoBarras encuentra producto traspasado en tienda destino', () async {
			await _guardarLeche(tiendaId: tiendaCentral);
			await inventario.guardarStock(
				StockNivel(
					productoId: 'prod-leche',
					tiendaId: tiendaSur,
					cantidad: 15,
					actualizadoEn: DateTime.utc(2026, 6, 30),
				),
			);

			final encontrado = await repo.buscarPorCodigoBarras(
				'7501234567890',
				tiendaId: tiendaSur,
			);

			expect(encontrado?.id, 'prod-leche');
		});
	});
}
