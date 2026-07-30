/// Regresion: un producto entrante que choca con el indice unico
/// (tienda_id, codigo_barras) ya NO debe desaparecer en silencio.
///
/// Antes `guardar()` insertaba con `ConflictAlgorithm.ignore`: el producto
/// entrante se descartaba sin error, sin fila y sin evento en cuarentena. El
/// cursor de sync avanzaba igual, asi que ese hueco nunca se volvia a
/// descargar y el dispositivo quedaba con un catalogo incompleto aunque
/// estuviera "al dia".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	const tiendaId = 'tienda-uno';
	const codigoCompartido = '#pistache';

	Producto crearProducto(String id, {String? nombre}) {
		return Producto(
			id: id,
			nombre: nombre ?? 'Pistache',
			codigoBarras: codigoCompartido,
			precioBase: 50.0,
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: tiendaId,
		);
	}

	test(
		'producto entrante que choca por codigo se preserva inactivo, nunca desaparece',
		() async {
			final base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			await base.execute('PRAGMA foreign_keys=ON');
			final repo = ProductoRepository(baseDatos: base);

			// El existente tiene id mayor (pierde el desempate por id si los
			// dos tienen cero referencias transaccionales).
			await repo.guardar(crearProducto('id-zzz-existente'));
			// El entrante tiene id menor: por regla de desempate, deberia ganar.
			await repo.guardar(crearProducto('id-aaa-entrante'));

			final filas = await base.query(
				'products',
				where: 'tienda_id = ?',
				whereArgs: [tiendaId],
			);
			// Ninguna de las dos filas se perdio.
			expect(filas, hasLength(2));

			final activos = filas.where((f) => f['activo'] == 1).toList();
			expect(activos, hasLength(1));
			expect(activos.single['id'], 'id-aaa-entrante');

			final inactivo = filas.firstWhere((f) => f['activo'] == 0);
			expect(inactivo['id'], 'id-zzz-existente');
			// El perdedor libera su codigo para no volver a chocar.
			expect(inactivo['codigo_barras'], '');

			await base.close();
		},
	);

	test(
		'el producto con mas ventas registradas gana el canonico, sin importar el id',
		() async {
			final base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			await base.execute('PRAGMA foreign_keys=ON');
			final repo = ProductoRepository(baseDatos: base);

			const idConVentas = 'id-zzz-con-ventas';
			await repo.guardar(crearProducto(idConVentas));
			await base.insert('sales', {
				'id': 'venta-1',
				'tienda_id': tiendaId,
				'caja_id': 'caja-1',
				'metodo_pago': 'efectivo',
				'total': 50.0,
				'creada_en': DateTime.now().toUtc().toIso8601String(),
			});
			await base.insert('sale_lines', {
				'venta_id': 'venta-1',
				'producto_id': idConVentas,
				'nombre_producto': 'Pistache',
				'cantidad': 1,
				'precio_unitario': 50.0,
				'regla_precio': 'base',
			});

			// Entrante con id menor, pero SIN historial de ventas.
			await repo.guardar(crearProducto('id-aaa-sin-ventas'));

			final filas = await base.query(
				'products',
				where: 'tienda_id = ?',
				whereArgs: [tiendaId],
			);
			expect(filas, hasLength(2));

			final activos = filas.where((f) => f['activo'] == 1).toList();
			expect(activos, hasLength(1));
			// Gana el que tiene ventas, aunque su id sea "mayor".
			expect(activos.single['id'], idConVentas);

			await base.close();
		},
	);
}
