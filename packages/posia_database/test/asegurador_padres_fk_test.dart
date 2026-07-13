/// Prueba integral: escrituras fuera de orden no violan FK del esquema v33.
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

	test('repositorios toleran padres faltantes en cadena de sync', () async {
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: 1,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		await base.execute('PRAGMA foreign_keys=ON');

		const tiendaId = 'tienda-a';
		const categoriaId = 'cat-a';
		const proveedorId = 'prov-a';
		const listaId = 'lista-a';
		const productoId = 'prod-a';
		const clienteId = 'cli-a';
		const ventaId = 'venta-a';

		final productoRepo = ProductoRepository(baseDatos: base);
		await productoRepo.guardar(
			Producto(
				id: productoId,
				nombre: 'Leche Santa Clara',
				codigoBarras: '123',
				precioBase: 32,
				unidadMedida: UnidadMedida.pieza,
				rutaImagen: '',
				activo: true,
				tiendaId: tiendaId,
				categoriaId: categoriaId,
				proveedorId: proveedorId,
			),
		);

		final clienteRepo = ClienteRepository(baseDatos: base);
		await clienteRepo.guardar(
			Cliente(
				id: clienteId,
				nombre: 'Cliente prueba',
				listaPreciosId: listaId,
				creditoHabilitado: false,
				activo: true,
			),
		);

		final precioRepo = PrecioRepository(baseDatos: base);
		await precioRepo.guardarPrecioLista(listaId, productoId, 30.0);

		final ventaRepo = VentaRepository(baseDatos: base);
		await ventaRepo.guardar(
			Venta(
				id: ventaId,
				tiendaId: tiendaId,
				cajaId: 'caja-1',
				clienteId: clienteId,
				lineas: [
					LineaVenta(
						productoId: productoId,
						nombreProducto: 'Leche Santa Clara',
						cantidad: 1,
						precioUnitario: 32,
						reglaPrecio: ReglaPrecio.precioBase,
					),
				],
				metodoPago: MetodoPago.efectivo,
				total: 32,
				creadaEn: DateTime.now().toUtc(),
			),
		);

		final traspasoRepo = TraspasoRepository(baseDatos: base);
		await traspasoRepo.guardar(
			Traspaso(
				id: 'trasp-a',
				tiendaOrigenId: tiendaId,
				tiendaDestinoId: 'tienda-b',
				estado: EstadoTraspaso.solicitado,
				solicitadoEn: DateTime.now().toUtc(),
				completadoEn: null,
				notas: '',
				lineas: [
					LineaTraspaso(
						productoId: productoId,
						nombreProducto: 'Leche',
						cantidadSolicitada: 2,
					),
				],
			),
		);

		final fkCheck = await base.rawQuery('PRAGMA foreign_key_check');
		expect(fkCheck, isEmpty);

		await base.close();
	});
}
