/// Prueba de autoSanarCatalogoLocal: cualquier dispositivo debe converger
/// a un estado limpio en su propio sync, sin reinstalar ni borrar datos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_database/src/sync/aplicador_eventos_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
	late Database base;
	late CategoriaRepository categoriaRepo;
	late TiendaRepository tiendaRepo;
	late ProductoRepository productoRepo;
	late AplicadorEventosSqlite aplicador;

	setUp(() async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
		base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		categoriaRepo = CategoriaRepository(baseDatos: base);
		tiendaRepo = TiendaRepository(baseDatos: base);
		productoRepo = ProductoRepository(baseDatos: base);
		await tiendaRepo.guardar(
			const Tienda(id: 'tienda-1', nombre: 'Origen', direccion: 'Calle 1', activa: true),
		);
		aplicador = AplicadorEventosSqlite(
			baseDatos: base,
			productoRepository: productoRepo,
			clienteRepository: ClienteRepository(baseDatos: base),
			ventaRepository: VentaRepository(baseDatos: base),
			inventarioRepository: InventarioRepository(baseDatos: base),
			categoriaRepository: categoriaRepo,
			tiendaRepository: tiendaRepo,
		);
	});

	tearDown(() => base.close());

	test('fusiona categorias duplicadas por nombre y reasigna productos', () async {
		// Perdedora: 1 producto.
		await categoriaRepo.guardar(
			const Categoria(
				id: 'cat-slug-abarrotes',
				nombre: 'Abarrotes',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 0,
				activa: true,
			),
		);
		// Ganadora: 2 productos (mas uso local = mas probable que sea la real).
		await categoriaRepo.guardar(
			const Categoria(
				id: 'cat-uuid-abarrotes',
				nombre: 'abarrotes', // mismo nombre, distinta capitalizacion
				icono: 'egg',
				colorHex: '#9C27B0',
				orden: 1,
				activa: true,
			),
		);
		await productoRepo.guardar(
			const Producto(
				id: 'prod-1',
				nombre: 'Arroz',
				codigoBarras: '1',
				precioBase: 10,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
				categoriaId: 'cat-uuid-abarrotes',
			),
		);
		await productoRepo.guardar(
			const Producto(
				id: 'prod-2',
				nombre: 'Frijol',
				codigoBarras: '2',
				precioBase: 12,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
				categoriaId: 'cat-uuid-abarrotes',
			),
		);
		await productoRepo.guardar(
			const Producto(
				id: 'prod-3',
				nombre: 'Azucar',
				codigoBarras: '3',
				precioBase: 8,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: 'tienda-1',
				categoriaId: 'cat-slug-abarrotes',
			),
		);

		await aplicador.autoSanarCatalogoLocal();

		final todas = await categoriaRepo.listarTodas();
		final ganadora = todas.firstWhere((c) => c.id == 'cat-uuid-abarrotes');
		final perdedora = todas.firstWhere((c) => c.id == 'cat-slug-abarrotes');
		expect(ganadora.activa, isTrue, reason: 'la que tenia mas productos gana');
		expect(perdedora.activa, isFalse, reason: 'la duplicada se desactiva localmente');

		final prod3 = await productoRepo.obtenerPorId('prod-3');
		expect(
			prod3!.categoriaId,
			'cat-uuid-abarrotes',
			reason: 'el producto de la perdedora se reasigna a la ganadora',
		);
		final prod1 = await productoRepo.obtenerPorId('prod-1');
		expect(prod1!.categoriaId, 'cat-uuid-abarrotes', reason: 'no se toca lo que ya estaba bien');
	});

	test('no toca categorias con nombres distintos', () async {
		await categoriaRepo.guardar(
			const Categoria(
				id: 'cat-a',
				nombre: 'Lácteos',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 0,
				activa: true,
			),
		);
		await categoriaRepo.guardar(
			const Categoria(
				id: 'cat-b',
				nombre: 'Carnes',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 1,
				activa: true,
			),
		);

		await aplicador.autoSanarCatalogoLocal();

		final todas = await categoriaRepo.listarTodas();
		expect(todas.every((c) => c.activa), isTrue);
	});

	test('desactiva tiendas placeholder (stub FK) sin tocar tiendas reales', () async {
		await tiendaRepo.guardar(
			const Tienda(id: 'tienda-sync', nombre: 'Tienda', direccion: '', activa: true),
		);

		await aplicador.autoSanarCatalogoLocal();

		final stub = await tiendaRepo.obtenerPorId('tienda-sync');
		final real = await tiendaRepo.obtenerPorId('tienda-1');
		expect(stub!.activa, isFalse, reason: 'placeholder se desactiva');
		expect(real!.activa, isTrue, reason: 'tienda real no se toca');
	});

	test('no colapsa categorias stub aunque compartan el nombre "Categoría"', () async {
		// Regresion: los stubs FK se llaman todos "Categoría" y normalizan a la
		// misma clave. Antes la auto-sanacion los trataba como duplicados, dejaba
		// uno y reasignaba TODOS los productos a esa unica categoria — el resto
		// de las categorias reales (que habian quedado como stub tras una
		// reconstruccion) se perdian.
		for (final entry in {
			'cat-abarrotes': 'prod-a',
			'cat-lacteos': 'prod-l',
			'cat-semillas': 'prod-s',
		}.entries) {
			await categoriaRepo.guardar(
				Categoria(
					id: entry.key,
					nombre: 'Categoría', // forma de stub FK
					icono: 'shopping_basket',
					colorHex: '#4CAF50',
					orden: 0,
					activa: true,
				),
			);
			await productoRepo.guardar(
				Producto(
					id: entry.value,
					nombre: entry.value,
					codigoBarras: entry.value,
					precioBase: 5,
					unidadMedida: UnidadMedida.pieza,
					rutaImagen: '',
					activo: true,
					tiendaId: 'tienda-1',
					categoriaId: entry.key,
				),
			);
		}

		await aplicador.autoSanarCatalogoLocal();

		final todas = await categoriaRepo.listarTodas();
		final stubs = todas.where((c) => c.esStubFk).toList();
		expect(
			stubs.where((c) => c.activa).length,
			3,
			reason: 'ninguna categoria stub se desactiva ni se colapsa',
		);
		// Cada producto conserva su propia categoria (no se reasignan a una sola).
		for (final entry in {
			'prod-a': 'cat-abarrotes',
			'prod-l': 'cat-lacteos',
			'prod-s': 'cat-semillas',
		}.entries) {
			final prod = await productoRepo.obtenerPorId(entry.key);
			expect(prod!.categoriaId, entry.value);
		}
	});

	test('es re-ejecutable sin efectos adicionales (idempotente)', () async {
		await categoriaRepo.guardar(
			const Categoria(
				id: 'cat-slug',
				nombre: 'Semillas',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 0,
				activa: true,
			),
		);
		await categoriaRepo.guardar(
			const Categoria(
				id: 'cat-uuid',
				nombre: 'Semillas',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 1,
				activa: true,
			),
		);

		await aplicador.autoSanarCatalogoLocal();
		await aplicador.autoSanarCatalogoLocal();
		await aplicador.autoSanarCatalogoLocal();

		final todas = await categoriaRepo.listarTodas();
		final semillas = todas.where((c) => c.nombre == 'Semillas').toList();
		final activas = semillas.where((c) => c.activa).toList();
		expect(activas.length, 1);
	});
}
