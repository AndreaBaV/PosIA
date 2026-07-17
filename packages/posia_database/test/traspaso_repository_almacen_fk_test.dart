/// Regresión: un traspaso cuyo origen/destino es un almacén codificado
/// ("almacen:X") debe poder guardarse sin violar el FK duro de
/// transfers.tienda_origen_id/tienda_destino_id -> stores(id), incluso
/// cuando ese almacén nunca tuvo una fila "stores" creada antes (p. ej. un
/// evento remoto histórico aplicado por primera vez en un dispositivo).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	late Database base;
	late TraspasoRepository traspasoRepo;

	setUp(() async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
		base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		traspasoRepo = TraspasoRepository(baseDatos: base);
	});

	tearDown(() => base.close());

	test('guarda traspaso con origen almacen: codificado sin fila stores previa', () async {
		final origenAlmacen = codificarAlmacenEnTraspaso('alm-1');
		final traspaso = Traspaso(
			id: 'trf-1',
			tiendaOrigenId: origenAlmacen,
			tiendaDestinoId: 'tienda-sur',
			estado: EstadoTraspaso.completado,
			solicitadoEn: DateTime.utc(2026, 6, 30),
			completadoEn: DateTime.utc(2026, 6, 30),
			notas: '',
			lineas: const [
				LineaTraspaso(
					productoId: 'prod-x',
					nombreProducto: 'Producto X',
					cantidadSolicitada: 5,
					cantidadRecibida: 5,
				),
			],
		);

		await traspasoRepo.guardar(traspaso);

		final guardado = await traspasoRepo.obtenerPorId('trf-1');
		expect(guardado, isNotNull);
		expect(guardado!.tiendaOrigenId, origenAlmacen);

		final filaStub = await base.query(
			'stores',
			where: 'id = ?',
			whereArgs: [origenAlmacen],
		);
		expect(filaStub, hasLength(1), reason: 'debe existir el stub FK para el id codificado');
		expect(filaStub.first['activa'], 0, reason: 'el stub nunca debe aparecer como tienda activa real');

		final filaAlmacen = await base.query(
			'almacenes',
			where: 'id = ?',
			whereArgs: ['alm-1'],
		);
		expect(filaAlmacen, hasLength(1), reason: 'el almacen real tambien debe quedar garantizado');
	});
}
