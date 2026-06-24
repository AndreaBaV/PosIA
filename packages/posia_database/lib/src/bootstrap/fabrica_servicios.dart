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
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/compra_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/config_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_farmacia_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/sync_event_repository.dart';
import '../repositories/sync_state_repository.dart';
import '../repositories/ticket_espera_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/turno_caja_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/vendedor_repository.dart';
import '../repositories/venta_repository.dart';
import '../services/servicio_admin.dart';
import '../services/servicio_caja.dart';
import '../services/servicio_corte_caja.dart';
import '../sync/aplicador_eventos_sqlite.dart';
import '../repositories/almacen_repository.dart';
import '../repositories/asistencia_repository.dart';
import '../repositories/empleado_perfil_repository.dart';
import '../repositories/nomina_repository.dart';
import '../repositories/presentacion_repository.dart';
import '../services/servicio_asistencia.dart';
import '../services/servicio_nomina.dart';

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
		this.servicioAsistencia,
		this.servicioNomina,
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

	/// Servicio de asistencia de empleados.
	final ServicioAsistencia? servicioAsistencia;

	/// Servicio de nomina.
	final ServicioNomina? servicioNomina;

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
		final baseDispositivo = await gestor.obtenerBaseDatosDispositivo();
		final configRepo = ConfigRepository(baseDatos: baseDispositivo);
		final configDispositivo = await configRepo.obtenerConfigDispositivo();
		tenantId ??= configDispositivo.tenantId;
		if (tenantId.isEmpty) {
			throw StateError('Sin tenant activo. Inicie sesion primero.');
		}
		await gestor.establecerTenant(tenantId);
		tiendaId ??= configDispositivo.tiendaId;
		cajaId ??= configDispositivo.cajaId;
		final base = await gestor.obtenerBaseDatos();
		final productoRepo = ProductoRepository(baseDatos: base);
		final clienteRepo = ClienteRepository(baseDatos: base);
		final descuentoClienteRepo = DescuentoClienteRepository(baseDatos: base);
		final ventaRepo = VentaRepository(baseDatos: base);
		final precioRepo = PrecioRepository(baseDatos: base);
		final inventarioRepo = InventarioRepository(baseDatos: base);
		final tiendaRepo = TiendaRepository(baseDatos: base);
		final colaSync = SyncEventRepository(baseDatos: base);
		final loteRepo = LoteFarmaciaRepository(baseDatos: base);
		final estadoSyncRepo = SyncStateRepository(baseDatos: base);
		final categoriaRepo = CategoriaRepository(baseDatos: base);
		final vendedorRepo = VendedorRepository(baseDatos: base);
		final usuarioRepo = UsuarioRepository(baseDatos: base);
		final proveedorRepo = ProveedorRepository(baseDatos: base);
		final movimientoRepo = MovimientoInventarioRepository(baseDatos: base);
		final turnoRepo = TurnoCajaRepository(baseDatos: base);
		final traspasoRepo = TraspasoRepository(baseDatos: base);
		final compraRepo = CompraRepository(baseDatos: base);
		final pedidoRepo = PedidoRepository(baseDatos: base);
		final cotizacionRepo = CotizacionRepository(baseDatos: base);
		final ticketEsperaRepo = TicketEsperaRepository(baseDatos: base);
		final varianteRepo = VarianteRepository(baseDatos: base);
		final almacenRepo = AlmacenRepository(baseDatos: base);
		final presentacionRepo = PresentacionRepository(baseDatos: base);
		final asistenciaRepo = AsistenciaRepository(baseDatos: base);
		final empleadoPerfilRepo = EmpleadoPerfilRepository(baseDatos: base);
		final nominaRepo = NominaRepository(baseDatos: base);
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
			tiendaRepository: tiendaRepo,
			usuarioRepository: usuarioRepo,
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
			presentacionRepository: presentacionRepo,
			clienteRepository: clienteRepo,
			ventaRepository: ventaRepo,
			motorPrecio: motorPrecio,
			gestorInventario: gestorInventario,
			syncOrchestrator: sync,
			servicioCarniceria: servicioCarniceria,
			servicioFarmacia: servicioFarmacia,
			categoriaRepository: categoriaRepo,
			vendedorRepository: vendedorRepo,
			cotizacionRepository: cotizacionRepo,
			ticketEsperaRepository: ticketEsperaRepo,
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
			descuentoClienteRepository: descuentoClienteRepo,
			vendedorRepository: vendedorRepo,
			usuarioRepository: usuarioRepo,
			proveedorRepository: proveedorRepo,
			compraRepository: compraRepo,
			pedidoRepository: pedidoRepo,
			cotizacionRepository: cotizacionRepo,
			precioRepository: precioRepo,
			movimientoRepository: movimientoRepo,
			traspasoRepository: traspasoRepo,
			varianteRepository: varianteRepo,
			almacenRepository: almacenRepo,
			presentacionRepository: presentacionRepo,
			servicioCorteCaja: servicioCorteCaja,
			tenantId: tenantId,
			tiendaActivaId: tiendaId,
			cajaId: cajaId,
		);
		final servicioAsistencia = ServicioAsistencia(
			asistenciaRepository: asistenciaRepo,
			tiendaRepository: tiendaRepo,
			syncOrchestrator: sync,
			tenantId: tenantId,
			tiendaId: tiendaId,
			dispositivoId: cajaId,
		);
		final servicioNomina = ServicioNomina(
			nominaRepository: nominaRepo,
			asistenciaRepository: asistenciaRepo,
			empleadoPerfilRepository: empleadoPerfilRepo,
			usuarioRepository: usuarioRepo,
			syncOrchestrator: sync,
			tenantId: tenantId,
			tiendaId: tiendaId,
			dispositivoId: cajaId,
		);
		return ContenedorServicios(
			servicioCaja: servicioCaja,
			servicioAdmin: servicioAdmin,
			servicioCarniceria: servicioCarniceria,
			servicioFarmacia: servicioFarmacia,
			syncOrchestrator: sync,
			servicioAsistencia: servicioAsistencia,
			servicioNomina: servicioNomina,
			hardwareListo: true,
		);
	}

	/// Orquestador de sync para login (antes de sesion de tenant en UI).
	///
	/// Retorna null si no hay tenant ni hub configurados.
	static Future<SyncOrchestrator?> crearOrquestadorPreLogin() async {
		final gestor = PosiaLocalDatabase.obtenerInstancia();
		final baseDispositivo = await gestor.obtenerBaseDatosDispositivo();
		final configRepo = ConfigRepository(baseDatos: baseDispositivo);
		final config = await configRepo.obtenerConfigDispositivo();
		final tenantId = config.tenantId;
		if (tenantId.isEmpty) {
			return null;
		}
		final clienteHub = await _crearClienteHub(configRepo);
		if (clienteHub == null) {
			return null;
		}
		await gestor.establecerTenant(tenantId);
		final base = await gestor.obtenerBaseDatos();
		final productoRepo = ProductoRepository(baseDatos: base);
		final clienteRepo = ClienteRepository(baseDatos: base);
		final ventaRepo = VentaRepository(baseDatos: base);
		final inventarioRepo = InventarioRepository(baseDatos: base);
		final categoriaRepo = CategoriaRepository(baseDatos: base);
		final traspasoRepo = TraspasoRepository(baseDatos: base);
		final varianteRepo = VarianteRepository(baseDatos: base);
		final tiendaRepo = TiendaRepository(baseDatos: base);
		final usuarioRepo = UsuarioRepository(baseDatos: base);
		final colaSync = SyncEventRepository(baseDatos: base);
		final estadoSyncRepo = SyncStateRepository(baseDatos: base);
		final aplicadorRemoto = AplicadorEventosSqlite(
			baseDatos: base,
			productoRepository: productoRepo,
			clienteRepository: clienteRepo,
			ventaRepository: ventaRepo,
			inventarioRepository: inventarioRepo,
			categoriaRepository: categoriaRepo,
			traspasoRepository: traspasoRepo,
			varianteRepository: varianteRepo,
			tiendaRepository: tiendaRepo,
			usuarioRepository: usuarioRepo,
		);
		return SyncOrchestrator(
			colaLocal: colaSync,
			clienteHub: clienteHub,
			clienteLan: null,
			aplicadorRemoto: aplicadorRemoto,
			almacenCursor: estadoSyncRepo,
			tenantId: tenantId,
			tiendaId: config.tiendaId,
			dispositivoId: config.cajaId,
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
		final claveApi = await configRepo.obtenerValor(claveConfigHubApiKey);
		return HubSyncClient(urlBase: hubUrl, claveApi: claveApi);
	}
}
