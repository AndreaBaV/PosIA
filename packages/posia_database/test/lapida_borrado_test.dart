/// El borrado manual del administrador es absoluto y gana sobre el hub.
///
/// Antes, borrar un producto o una categoria no se propagaba (el protocolo no
/// tenia evento de borrado) y el siguiente pull los recreaba: el cliente
/// reportaba "no me deja eliminar, reaparecen".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/sync/aplicador_eventos_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SyncEvent _upsertProducto(String id, {bool activo = true}) => SyncEvent(
	id: 'ev-upsert-$id',
	tiendaId: 'tienda-1',
	dispositivoId: 'otra-caja',
	tipo: TipoSyncEvento.productUpserted,
	payload: {
		'id': id,
		'nombre': 'Arroz Morelos',
		'codigoBarras': '750001',
		'precioBase': 25.0,
		'activo': activo,
		'tiendaId': 'tienda-1',
	},
	creadoEn: DateTime.now().toUtc(),
	estado: EstadoSyncEvento.pendiente,
);

void main() {
	setUpAll(() {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
	});

	Future<Database> abrir() async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');
		await base.insert('stores', {
			'id': 'tienda-1',
			'nombre': 'Centro',
			'direccion': '',
			'activa': 1,
		});
		return base;
	}

	AplicadorEventosSqlite aplicador(Database base) => AplicadorEventosSqlite(
		baseDatos: base,
		productoRepository: ProductoRepository(baseDatos: base),
		clienteRepository: ClienteRepository(baseDatos: base),
		ventaRepository: VentaRepository(baseDatos: base),
		inventarioRepository: InventarioRepository(baseDatos: base),
		categoriaRepository: CategoriaRepository(baseDatos: base),
	);

	test('la migracion v36 crea la tabla de lapidas', () async {
		final base = await abrir();
		final t = await base.rawQuery(
			"SELECT name FROM sqlite_master WHERE name='entidades_eliminadas'",
		);
		expect(t, isNotEmpty);
		await base.close();
	});

	test('un upsert remoto no revive un producto enterrado', () async {
		final base = await abrir();
		final productos = ProductoRepository(baseDatos: base);
		await productos.guardar(
			const Producto(
				id: 'prod-arroz',
				nombre: 'Arroz Morelos',
				codigoBarras: '750001',
				precioBase: 25.0,
				unidadMedida: UnidadMedida.kilogramo,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
			),
		);
		await LapidaRepository(baseDatos: base).registrar(
			tipo: TipoLapida.producto,
			entidadId: 'prod-arroz',
			eliminadoPor: 'admin',
		);
		await productos.guardar(
			(await productos.obtenerPorId('prod-arroz'))!.copiarCon(activo: false),
		);

		// Neon insiste con el producto vivo.
		await aplicador(base).aplicarEvento(_upsertProducto('prod-arroz'));

		final tras = await productos.obtenerPorId('prod-arroz');
		expect(
			tras!.activo,
			isFalse,
			reason: 'la lapida manda: el upsert remoto no puede reactivarlo',
		);
		await base.close();
	});

	test('una lapida remota entierra un producto que llego antes', () async {
		final base = await abrir();
		final productos = ProductoRepository(baseDatos: base);
		final app = aplicador(base);

		await app.aplicarEvento(_upsertProducto('prod-arroz'));
		expect((await productos.obtenerPorId('prod-arroz'))!.activo, isTrue);

		await app.aplicarEvento(
			SyncEvent(
				id: 'ev-lapida',
				tiendaId: 'tienda-1',
				dispositivoId: 'otra-caja',
				tipo: TipoSyncEvento.productDeleted,
				payload: const {'id': 'prod-arroz'},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);
		expect((await productos.obtenerPorId('prod-arroz'))!.activo, isFalse);

		// Y un upsert posterior tampoco lo revive.
		await app.aplicarEvento(_upsertProducto('prod-arroz'));
		expect(
			(await productos.obtenerPorId('prod-arroz'))!.activo,
			isFalse,
			reason: 'la lapida gana sin importar el orden de llegada',
		);
		await base.close();
	});

	test('una categoria enterrada no revive por upsert remoto', () async {
		final base = await abrir();
		final repo = CategoriaRepository(baseDatos: base);
		await repo.guardar(
			const Categoria(
				id: 'cat-1',
				nombre: 'Semillas',
				icono: 'grass',
				colorHex: '#8BC34A',
				orden: 1,
				activa: true,
			),
		);
		await LapidaRepository(baseDatos: base).registrar(
			tipo: TipoLapida.categoria,
			entidadId: 'cat-1',
		);
		await repo.guardar(
			(await repo.obtenerPorId('cat-1'))!.copiarCon(activa: false),
		);

		await aplicador(base).aplicarEvento(
			SyncEvent(
				id: 'ev-cat',
				tiendaId: 'tienda-1',
				dispositivoId: 'otra-caja',
				tipo: TipoSyncEvento.categoryUpserted,
				payload: const {'id': 'cat-1', 'nombre': 'Semillas', 'activa': true},
				creadoEn: DateTime.now().toUtc(),
				estado: EstadoSyncEvento.pendiente,
			),
		);

		expect((await repo.obtenerPorId('cat-1'))!.activa, isFalse);
		await base.close();
	});
}
