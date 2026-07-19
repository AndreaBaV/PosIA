/// Reproduccion del guardado de empaques sobre la conexion REAL de la app.
///
/// La app no usa una `Database` simple: usa [ConexionOperativaRuteada], que
/// manda las escrituras a una conexion y las lecturas a otra de solo-lectura.
/// Este test replica esa topologia sobre un archivo con WAL, que es lo que
/// corre en produccion.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/database/conexion_operativa_ruteada.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	test('guardar presentacion a traves de ConexionOperativaRuteada', () async {
		final dir = await Directory.systemTemp.createTemp('posia_ruteada');
		final ruta = '${dir.path}/operativa.db';

		final escritura = await openDatabase(
			ruta,
			version: SCHEMA_VERSION,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
			onConfigure: (db) async {
				await db.rawQuery('PRAGMA journal_mode=WAL');
				await db.execute('PRAGMA synchronous=NORMAL');
				await db.execute('PRAGMA foreign_keys=ON');
			},
		);
		final lectura = await openDatabase(ruta, readOnly: true, singleInstance: false);
		final ruteada = ConexionOperativaRuteada(
			escritura: escritura,
			lectura: lectura,
		);

		// Padres minimos.
		await ruteada.insert('stores', {
			'id': 'tienda-1',
			'nombre': 'Centro',
			'direccion': '',
			'activa': 1,
		});
		await ruteada.insert('categories', {
			'id': 'cat-1',
			'nombre': 'Semillas',
			'icono': 'grass',
			'color_hex': '#8BC34A',
			'orden': 1,
			'activa': 1,
		});

		final productoRepo = ProductoRepository(baseDatos: ruteada);
		await productoRepo.guardar(
			const Producto(
				id: 'prod-arroz',
				nombre: 'Arroz Morelos',
				codigoBarras: '750000001',
				precioBase: 25.0,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
				categoriaId: 'cat-1',
				costoUnitario: 15.0,
			),
		);

		final presentacionRepo = PresentacionRepository(baseDatos: ruteada);
		await presentacionRepo.guardarTipo(
			const TipoPresentacion(
				id: 'tp-kg',
				nombre: 'Bulto',
				unidad: 'kilogramo',
				activo: true,
			),
		);

		// El guardado del bulto, tal como lo hace el panel.
		await presentacionRepo.guardarPresentacion(
			const PresentacionProducto(
				id: 'pres-bulto',
				productoId: 'prod-arroz',
				tipoPresentacionId: 'tp-kg',
				nombre: 'Bulto 25 kg',
				factorABase: 25.0,
				esPresentacionBase: false,
				codigoBarras: '',
				precio: 600.0,
				activo: true,
			),
		);

		// Lectura por la conexion ruteada (lo que ve la UI).
		final viaRuteada = await presentacionRepo.listarPorProducto('prod-arroz');
		// ignore: avoid_print
		print('via ConexionOperativaRuteada: '
			'${viaRuteada.map((p) => p.nombre).toList()}');

		// Lectura directa por la conexion de escritura (verdad de fondo).
		final viaEscritura = await escritura.query(
			'presentaciones_producto',
			where: 'producto_id = ?',
			whereArgs: ['prod-arroz'],
		);
		// ignore: avoid_print
		print('via conexion de escritura: '
			'${viaEscritura.map((f) => f['nombre']).toList()}');

		expect(
			viaEscritura,
			isNotEmpty,
			reason: 'la escritura debe haber persistido',
		);
		expect(
			viaRuteada.map((p) => p.nombre),
			contains('Bulto 25 kg'),
			reason: 'la UI lee por la conexion ruteada: si aqui no aparece, el '
				'bulto existe en disco pero es invisible para la aplicacion',
		);

		await ruteada.close();
		await dir.delete(recursive: true);
	});
}
