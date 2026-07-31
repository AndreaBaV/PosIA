/// Regresion: un producto entrante que choca con el indice unico
/// (tienda_id, codigo_barras) ya NO debe desaparecer en silencio, y quien
/// "gana" (que sus valores -precio, costo, nombre- terminen visibles) lo
/// decide la fecha de edicion mas reciente, no cuantas ventas tenga cada
/// lado ni el orden en que se procesan los eventos.
///
/// Caso real: un dispositivo con catalogo local incompleto da de alta "de
/// nuevo" un producto que en realidad ya existia en el resto de la flota,
/// capturando un costo actualizado. Antes de este fix el producto con mas
/// historial de ventas ganaba siempre, sin importar que su costo fuera el
/// viejo -el costo nuevo quedaba enterrado en una fila inactiva.
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

	Producto crearProducto(
		String id, {
		String nombre = 'Pistache',
		double costoUnitario = 40.0,
		DateTime? actualizadoEn,
	}) {
		return Producto(
			id: id,
			nombre: nombre,
			codigoBarras: codigoCompartido,
			precioBase: 50.0,
			costoUnitario: costoUnitario,
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: tiendaId,
			actualizadoEn: actualizadoEn,
		);
	}

	test(
		'el producto entrante mas reciente gana el canonico y trae su costo nuevo, '
		'aunque el existente tenga mas ventas',
		() async {
			final base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			await base.execute('PRAGMA foreign_keys=ON');
			final repo = ProductoRepository(baseDatos: base);

			const idViejo = 'id-original-con-ventas';
			await repo.guardar(
				crearProducto(
					idViejo,
					costoUnitario: 40.0,
					actualizadoEn: DateTime.utc(2026, 1, 1),
				),
			);
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
				'producto_id': idViejo,
				'nombre_producto': 'Pistache',
				'cantidad': 1,
				'precio_unitario': 50.0,
				'regla_precio': 'base',
			});

			// El cliente, en un dispositivo con catalogo incompleto, "da de alta"
			// el mismo producto con un costo actualizado. Id distinto, sin
			// ventas locales, pero es la edicion mas reciente.
			const idNuevo = 'id-duplicado-costo-nuevo';
			await repo.guardar(
				crearProducto(
					idNuevo,
					costoUnitario: 55.0,
					actualizadoEn: DateTime.utc(2026, 7, 30),
				),
			);

			final activos = await base.query(
				'products',
				where: 'tienda_id = ? AND activo = 1',
				whereArgs: [tiendaId],
			);
			expect(activos, hasLength(1));
			// La fila que sigue activa conserva el id viejo (no rompe la venta ya
			// registrada)...
			expect(activos.single['id'], idViejo);
			// ...pero con el costo NUEVO: la edicion reciente del cliente no se
			// pierde, solo se remapea al id canonico.
			expect(activos.single['costo_unitario'], 55.0);

			final inactivo = await base.query(
				'products',
				where: 'id = ?',
				whereArgs: [idNuevo],
			);
			expect(inactivo, hasLength(1));
			expect(inactivo.single['activo'], 0);

			await base.close();
		},
	);

	test(
		'una edicion historica que llega tarde no sobreescribe la edicion local mas reciente',
		() async {
			final base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			await base.execute('PRAGMA foreign_keys=ON');
			final repo = ProductoRepository(baseDatos: base);

			// El dispositivo corrupto crea el producto AHORA con el costo que
			// acaba de capturar el cliente.
			const idLocal = 'id-creado-ahora-localmente';
			await repo.guardar(
				crearProducto(
					idLocal,
					costoUnitario: 55.0,
					actualizadoEn: DateTime.utc(2026, 7, 30),
				),
			);

			// Mas tarde, al repararse, baja del hub el evento HISTORICO original
			// (de meses atras) del mismo producto real, con el costo viejo.
			const idHistorico = 'id-original-del-hub';
			await repo.guardar(
				crearProducto(
					idHistorico,
					costoUnitario: 40.0,
					actualizadoEn: DateTime.utc(2026, 1, 1),
				),
			);

			final activos = await base.query(
				'products',
				where: 'tienda_id = ? AND activo = 1',
				whereArgs: [tiendaId],
			);
			expect(activos, hasLength(1));
			// La edicion local reciente NO se revierte al costo viejo.
			expect(activos.single['id'], idLocal);
			expect(activos.single['costo_unitario'], 55.0);

			await base.close();
		},
	);

	test(
		'sin fecha conocida en la fila existente, la fecha real del entrante decide',
		() async {
			final base = await openDatabase(
				inMemoryDatabasePath,
				version: 1,
				onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			);
			await base.execute('PRAGMA foreign_keys=ON');
			final repo = ProductoRepository(baseDatos: base);

			// Simula una fila de antes de esta migracion: nunca se re-guardo, asi
			// que actualizado_en quedo NULL tras el ALTER TABLE.
			const idLegado = 'id-legado-sin-fecha';
			await repo.guardar(crearProducto(idLegado, actualizadoEn: DateTime.utc(2020)));
			await base.update(
				'products',
				{'actualizado_en': null},
				where: 'id = ?',
				whereArgs: [idLegado],
			);

			const idNuevo = 'id-con-fecha-real';
			await repo.guardar(
				crearProducto(idNuevo, costoUnitario: 60.0, actualizadoEn: DateTime.utc(2026, 7, 30)),
			);

			final activos = await base.query(
				'products',
				where: 'tienda_id = ? AND activo = 1',
				whereArgs: [tiendaId],
			);
			expect(activos, hasLength(1));
			expect(activos.single['id'], idLegado);
			expect(activos.single['costo_unitario'], 60.0);

			await base.close();
		},
	);
}
