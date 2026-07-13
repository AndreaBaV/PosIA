/// Fixture de prueba con ServicioAdmin sobre SQLite en memoria.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const tiendaOrigenPruebaId = 'tienda-origen';
const tiendaDestinoPruebaId = 'tienda-destino';
const categoriaPruebaId = 'cat-general';
const cajaPruebaId = 'caja-prueba';

/// Entorno de prueba con base en memoria y servicios admin.
class FixtureAdmin {
	FixtureAdmin._({
		required this.base,
		required this.inventarioRepository,
		required this.ventaRepository,
		required this.almacenRepository,
		required this.cotizacionRepository,
		required this.tiendaOrigenId,
		required this.tiendaDestinoId,
		required this.categoriaId,
	});

	final Database base;
	final InventarioRepository inventarioRepository;
	final VentaRepository ventaRepository;
	final AlmacenRepository almacenRepository;
	final CotizacionRepository cotizacionRepository;
	final String tiendaOrigenId;
	final String tiendaDestinoId;
	final String categoriaId;

	ServicioAdmin crearServicio({required String tiendaId}) {
		final colaSync = SyncEventRepository(baseDatos: base);
		final sync = SyncOrchestrator(
			colaLocal: colaSync,
			clienteHub: null,
			clienteLan: null,
			tiendaId: tiendaId,
			dispositivoId: cajaPruebaId,
		);
		return ServicioAdmin(
			tiendaRepository: TiendaRepository(baseDatos: base),
			ventaRepository: ventaRepository,
			productoRepository: ProductoRepository(baseDatos: base),
			inventarioRepository: inventarioRepository,
			syncEventRepository: colaSync,
			syncOrchestrator: sync,
			configRepository: ConfigRepository(baseDatos: base),
			categoriaRepository: CategoriaRepository(baseDatos: base),
			clienteRepository: ClienteRepository(baseDatos: base),
			vendedorRepository: VendedorRepository(baseDatos: base),
			proveedorRepository: ProveedorRepository(baseDatos: base),
			compraRepository: CompraRepository(baseDatos: base),
			cotizacionRepository: cotizacionRepository,
			almacenRepository: almacenRepository,
			precioRepository: PrecioRepository(baseDatos: base),
			movimientoRepository: MovimientoInventarioRepository(baseDatos: base),
			traspasoRepository: TraspasoRepository(baseDatos: base),
			varianteRepository: VarianteRepository(baseDatos: base),
			baseDatos: base,
			tiendaActivaId: tiendaId,
			cajaId: cajaPruebaId,
		);
	}

	ServicioCaja crearServicioCaja({required String tiendaId}) {
		final productoRepo = ProductoRepository(baseDatos: base);
		return ServicioCaja(
			productoRepository: productoRepo,
			inventarioRepository: inventarioRepository,
			baseDatos: base,
			clienteRepository: ClienteRepository(baseDatos: base),
			ventaRepository: ventaRepository,
			cotizacionRepository: cotizacionRepository,
			motorPrecio: MotorPrecio(
				repositorioPrecio: PrecioRepository(baseDatos: base),
			),
			gestorInventario: GestorInventario(repositorioInventario: inventarioRepository),
			syncOrchestrator: SyncOrchestrator(
				colaLocal: SyncEventRepository(baseDatos: base),
				clienteHub: null,
				clienteLan: null,
				tiendaId: tiendaId,
				dispositivoId: cajaPruebaId,
			),
			tiendaId: tiendaId,
			cajaId: cajaPruebaId,
		);
	}

	Future<void> cerrar() => base.close();

	static Future<FixtureAdmin> abrir() async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
		final base = await openDatabase(
			inMemoryDatabasePath,
			version: SCHEMA_VERSION,
			singleInstance: false,
			onCreate: (db, _) => MigracionesEsquema.crearEsquemaCompleto(db),
		);
		final tiendaRepo = TiendaRepository(baseDatos: base);
		await tiendaRepo.guardar(
			Tienda(
				id: tiendaOrigenPruebaId,
				nombre: 'Origen',
				direccion: 'Calle 1',
				activa: true,
			),
		);
		await tiendaRepo.guardar(
			Tienda(
				id: tiendaDestinoPruebaId,
				nombre: 'Destino',
				direccion: 'Calle 2',
				activa: true,
			),
		);
		final categoriaRepo = CategoriaRepository(baseDatos: base);
		await categoriaRepo.guardar(
			Categoria(
				id: categoriaPruebaId,
				nombre: 'General',
				icono: 'shopping_basket',
				colorHex: '#4CAF50',
				orden: 0,
				activa: true,
			),
		);
		return FixtureAdmin._(
			base: base,
			inventarioRepository: InventarioRepository(baseDatos: base),
			ventaRepository: VentaRepository(baseDatos: base),
			almacenRepository: AlmacenRepository(baseDatos: base),
			cotizacionRepository: CotizacionRepository(baseDatos: base),
			tiendaOrigenId: tiendaOrigenPruebaId,
			tiendaDestinoId: tiendaDestinoPruebaId,
			categoriaId: categoriaPruebaId,
		);
	}
}
