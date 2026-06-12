/// Contenedor de servicios de aplicacion listos para inyeccion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:posia_inventory/posia_inventory.dart';
import 'package:posia_module_butcher/posia_module_butcher.dart';
import 'package:posia_module_pharmacy/posia_module_pharmacy.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';

import '../database/posia_local_database.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_farmacia_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/sync_event_repository.dart';
import '../repositories/sync_state_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/turno_caja_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../repositories/venta_repository.dart';
import '../services/servicio_admin.dart';
import '../services/servicio_caja.dart';
import '../services/servicio_corte_caja.dart';
import '../sync/aplicador_eventos_sqlite.dart';

/// Agrupa servicios construidos sobre SQLite local.
class ContenedorServicios {
	/// Crea contenedor con servicios cableados.
	///
	/// [servicioCaja] Servicio principal de operaciones de caja.
	/// [servicioAdmin] Servicio de panel administrativo.
	/// [servicioCarniceria] Modulo vertical carniceria.
	/// [servicioFarmacia] Modulo vertical farmacia.
	/// [syncOrchestrator] Orquestador de sincronizacion.
	/// [hardwareListo] Indica si dependencias fueron resueltas.
	ContenedorServicios({
		required this.servicioCaja,
		required this.servicioAdmin,
		required this.servicioCarniceria,
		required this.servicioFarmacia,
		required this.syncOrchestrator,
		required this.hardwareListo,
	});

	/// Servicio de ventas en caja.
	final ServicioCaja servicioCaja;

	/// Servicio de administracion y reportes.
	final ServicioAdmin servicioAdmin;

	/// Servicio de venta por peso carniceria.
	final ServicioCarniceria servicioCarniceria;

	/// Servicio de lotes farmacia.
	final ServicioFarmacia servicioFarmacia;

	/// Orquestador de eventos sync.
	final SyncOrchestrator syncOrchestrator;

	/// Bandera de inicializacion completa.
	final bool hardwareListo;
}

/// Fabrica de servicios POSIA para arranque de aplicacion.
class FabricaServicios {
	/// Construye contenedor con tenant, tienda y caja indicados.
	///
	/// [tenantId] Identificador del tenant licenciado.
	/// [tiendaId] Tienda activa de la caja.
	/// [cajaId] Identificador del dispositivo caja.
	/// Retorna [ContenedorServicios] listo para UI.
	static Future<ContenedorServicios> construir({
		String? tenantId,
		String? tiendaId,
		String? cajaId,
	}) async {
		final gestor = PosiaLocalDatabase.obtenerInstancia();
		final base = await gestor.obtenerBaseDatos();
		final configRepo = ConfigRepository(baseDatos: base);
		final configDispositivo = await configRepo.obtenerConfigDispositivo();
		tenantId ??= configDispositivo.tenantId;
		tiendaId ??= configDispositivo.tiendaId;
		cajaId ??= configDispositivo.cajaId;
		final productoRepo = ProductoRepository(baseDatos: base);
		final clienteRepo = ClienteRepository(baseDatos: base);
		final ventaRepo = VentaRepository(baseDatos: base);
		final precioRepo = PrecioRepository(baseDatos: base);
		final inventarioRepo = InventarioRepository(baseDatos: base);
		final tiendaRepo = TiendaRepository(baseDatos: base);
		final colaSync = SyncEventRepository(baseDatos: base);
		final loteRepo = LoteFarmaciaRepository(baseDatos: base);
		final estadoSyncRepo = SyncStateRepository(baseDatos: base);
		final categoriaRepo = CategoriaRepository(baseDatos: base);
		final vendedorRepo = VendedorRepository(baseDatos: base);
		final proveedorRepo = ProveedorRepository(baseDatos: base);
		final movimientoRepo = MovimientoInventarioRepository(baseDatos: base);
		final turnoRepo = TurnoCajaRepository(baseDatos: base);
		final traspasoRepo = TraspasoRepository(baseDatos: base);
		final varianteRepo = VarianteRepository(baseDatos: base);
		final servicioCorteCaja = ServicioCorteCaja(
			turnoRepository: turnoRepo,
			tiendaId: tiendaId,
			cajaId: cajaId,
		);
		final motorPrecio = MotorPrecio(repositorioPrecio: precioRepo);
		final gestorInventario = GestorInventario(repositorioInventario: inventarioRepo);
		final servicioCarniceria = ServicioCarniceria();
		final servicioFarmacia = ServicioFarmacia(repositorioLote: loteRepo);
		final aplicadorRemoto = AplicadorEventosSqlite(
			baseDatos: base,
			productoRepository: productoRepo,
			clienteRepository: clienteRepo,
			ventaRepository: ventaRepo,
			inventarioRepository: inventarioRepo,
			categoriaRepository: categoriaRepo,
			traspasoRepository: traspasoRepo,
			varianteRepository: varianteRepo,
		);
		final clienteHub = await _crearClienteHub(configRepo);
		final sync = SyncOrchestrator(
			colaLocal: colaSync,
			clienteHub: clienteHub,
			clienteLan: null,
			aplicadorRemoto: aplicadorRemoto,
			almacenCursor: estadoSyncRepo,
			tenantId: tenantId,
			tiendaId: tiendaId,
			dispositivoId: cajaId,
		);
		final servicioCaja = ServicioCaja(
			productoRepository: productoRepo,
			varianteRepository: varianteRepo,
			clienteRepository: clienteRepo,
			ventaRepository: ventaRepo,
			motorPrecio: motorPrecio,
			gestorInventario: gestorInventario,
			syncOrchestrator: sync,
			servicioCarniceria: servicioCarniceria,
			servicioFarmacia: servicioFarmacia,
			categoriaRepository: categoriaRepo,
			vendedorRepository: vendedorRepo,
			servicioCorteCaja: servicioCorteCaja,
			tenantId: tenantId,
			tiendaId: tiendaId,
			cajaId: cajaId,
		);
		final servicioAdmin = ServicioAdmin(
			tiendaRepository: tiendaRepo,
			ventaRepository: ventaRepo,
			productoRepository: productoRepo,
			inventarioRepository: inventarioRepo,
			syncEventRepository: colaSync,
			syncOrchestrator: sync,
			configRepository: configRepo,
			categoriaRepository: categoriaRepo,
			clienteRepository: clienteRepo,
			vendedorRepository: vendedorRepo,
			proveedorRepository: proveedorRepo,
			precioRepository: precioRepo,
			movimientoRepository: movimientoRepo,
			traspasoRepository: traspasoRepo,
			varianteRepository: varianteRepo,
			servicioCorteCaja: servicioCorteCaja,
			tenantId: tenantId,
			tiendaActivaId: tiendaId,
			cajaId: cajaId,
		);
		return ContenedorServicios(
			servicioCaja: servicioCaja,
			servicioAdmin: servicioAdmin,
			servicioCarniceria: servicioCarniceria,
			servicioFarmacia: servicioFarmacia,
			syncOrchestrator: sync,
			hardwareListo: true,
		);
	}

	/// Crea cliente hub desde configuracion local.
	///
	/// [configRepo] Acceso a app_config.
	/// Retorna cliente o null si no hay URL configurada.
	static Future<HubSyncClient?> _crearClienteHub(ConfigRepository configRepo) async {
		final hubUrl = await configRepo.obtenerHubUrl();
		if (hubUrl == null) {
			return null;
		}
		final claveApi = await configRepo.obtenerValor(CLAVE_CONFIG_HUB_API_KEY);
		return HubSyncClient(urlBase: hubUrl, claveApi: claveApi);
	}
}
