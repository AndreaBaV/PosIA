/// Proveedores Riverpod de servicios y estado de caja POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 16:00:00 (UTC-6)
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_hardware/posia_hardware.dart';
import 'package:posia_licensing/posia_licensing.dart';

import '../services/impresora_documentos_marca.dart';
import '../bootstrap/inicializador_app.dart';
import '../bootstrap/limpiador_cache_local.dart';
import '../sync/sincronizador_automatico.dart';
import '../services/gestor_sesion_persistente.dart';
import '../util/plataforma_util.dart';
import '../utils/imprimir_ticket_digital_util.dart';
import '../utils/ticket_credito_util.dart';
import '../utils/ticket_venta_util.dart';

/// Estado de inicializacion de la aplicacion.
final estadoInicializacionProvider = FutureProvider<void>((ref) async {
	await InicializadorApp.preparar();
});

/// Restaura sesion persistida tras inicializar SQLite (sin pedir PIN de nuevo).
final restauracionSesionProvider = FutureProvider<void>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	await GestorSesionPersistente.restaurarSiExiste(ref);
});

/// Usuario autenticado en la sesion actual.
final sesionUsuarioProvider = NotifierProvider<SesionUsuarioNotifier, Usuario?>(
	SesionUsuarioNotifier.new,
);

/// Gestiona la cuenta de usuario activa.
class SesionUsuarioNotifier extends Notifier<Usuario?> {
	@override
	Usuario? build() => null;

	void iniciar(Usuario usuario) => state = usuario;

	void cerrar() => state = null;
}

/// Gestiona confirmacion de tienda al iniciar la aplicacion.
final sesionTiendaProvider = NotifierProvider<SesionTiendaNotifier, String?>(
	SesionTiendaNotifier.new,
);

/// Estado de tienda confirmada en la sesion actual.
class SesionTiendaNotifier extends Notifier<String?> {
	@override
	String? build() => null;

	void confirmar(String tiendaId) => state = tiendaId;

	void cerrar() => state = null;
}

/// Admin: false mientras se importan tiendas del hub tras login.
final sesionAdminListoProvider = NotifierProvider<SesionAdminListoNotifier, bool>(
	SesionAdminListoNotifier.new,
);

class SesionAdminListoNotifier extends Notifier<bool> {
	@override
	bool build() => true;

	void preparando() => state = false;

	void listo() => state = true;
}

/// Tiendas disponibles para el administrador tras login.
final tiendasAccesoProvider = FutureProvider<List<Tienda>>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final usuario = ref.watch(sesionUsuarioProvider);
	return contenedor.servicioAdmin.obtenerTiendasPermitidas(operador: usuario);
});

/// Contenedor de servicios de dominio (requiere sesion activa).
final contenedorServiciosProvider = FutureProvider<ContenedorServicios>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final usuario = ref.watch(sesionUsuarioProvider);
	if (usuario == null) {
		throw StateError('Inicie sesión para cargar servicios');
	}
	return FabricaServicios.construir();
});

/// Sincronizador automatico activo mientras vive la app.
final sincronizadorAutomaticoProvider = FutureProvider<SincronizadorAutomatico>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	contenedor.syncOrchestrator.alAplicarEventoRemoto =
		(evento) => _imprimirVentaRemotaTrasSync(ref, evento);
	final sincronizador = SincronizadorAutomatico(
		orquestador: contenedor.syncOrchestrator,
		sincronizarConCatalogo: () async {
			if (LimpiadorCacheLocal.seLimpioEnEsteArranque) {
				await contenedor.syncOrchestrator.sincronizarDesdeOrigen();
				await PosiaLocalDatabase.obtenerInstancia()
					.completarMigracionIntegridadTrasSync();
				return;
			}
			await contenedor.servicioAdmin.sincronizarManual(incluirCatalogo: true);
		},
	);
	sincronizador.iniciar();
	ref.onDispose(sincronizador.detener);
	return sincronizador;
});

/// Licencia activa del despliegue.
final licenciaProvider = FutureProvider<Licencia>((ref) async {
	await ref.watch(contenedorServiciosProvider.future);
	return Licencia(
		modulos: [
			ModuloLicencia.core,
			ModuloLicencia.multiStore,
			ModuloLicencia.syncHub,
			ModuloLicencia.syncLan,
			ModuloLicencia.wholesalePricing,
			ModuloLicencia.customerPricing,
			ModuloLicencia.butcher,
			ModuloLicencia.pharmacy,
			ModuloLicencia.voiceCommands,
		],
		maxTiendas: 5,
		maxCajas: 10,
		maxUsuarios: LIMITE_MAX_USUARIOS,
		soporteExpiraEn: DateTime.utc(2027, 6, 7),
	);
});

/// Registro de hardware segun configuracion de impresora del dispositivo.
final hardwareRegistryProvider = FutureProvider<HardwareRegistry>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final configImpresora = await contenedor.servicioAdmin.obtenerConfigImpresora();
	final directorioTickets = await _resolverDirectorioTickets();
	final modo = _resolverModoImpresoraParaPlataforma(configImpresora);
	final cajon = _construirCajon(configImpresora, modo);
	return HardwareRegistry(
		scanner: TecladoBarcodeScanner(),
		impresora: ImpresoraDocumentosMarca.crear(
			modo: modo,
			hostRed: configImpresora.hostRed,
			puertoRed: configImpresora.puertoRed,
			directorioArchivo: directorioTickets,
			nombreImpresoraUsb: configImpresora.nombreImpresoraUsb,
			anchoRolloMm: configImpresora.anchoRolloMm,
			permitirRespaldoArchivo: _permitirRespaldoArchivoEnPlataforma(
				configImpresora,
				modo,
			),
		),
		cajon: cajon,
	);
});

CashDrawer? _construirCajon(ConfigImpresora config, ModoImpresora modo) {
	if (!config.abrirCajonAlCobrar) {
		return null;
	}
	if (modo == ModoImpresora.usbWindows) {
		if (config.nombreImpresoraUsb.trim().isEmpty) {
			return null;
		}
		return EscPosWindowsCashDrawer(
			nombreImpresora: config.nombreImpresoraUsb,
		);
	}
	if ((modo == ModoImpresora.red || modo == ModoImpresora.ambos) &&
		config.hostRed.trim().isNotEmpty) {
		return EscPosCashDrawer(
			host: config.hostRed,
			port: config.puertoRed,
		);
	}
	return null;
}

ModoImpresora _resolverModoImpresora(String modo) {
	switch (modo) {
		case 'archivo':
			return ModoImpresora.archivo;
		case 'red':
			return ModoImpresora.red;
		case 'usb_windows':
			return ModoImpresora.usbWindows;
		default:
			return ModoImpresora.ambos;
	}
}

/// En movil no hay spooler USB de Windows; prioriza impresora de red si hay IP.
ModoImpresora _resolverModoImpresoraParaPlataforma(ConfigImpresora config) {
	final base = _resolverModoImpresora(config.modo);
	if (!esPlataformaMovilNativa()) {
		return base;
	}
	final host = config.hostRed.trim();
	if (base == ModoImpresora.usbWindows) {
		return host.isNotEmpty ? ModoImpresora.red : ModoImpresora.archivo;
	}
	if (base == ModoImpresora.ambos && host.isNotEmpty) {
		return ModoImpresora.red;
	}
	return base;
}

/// En movil con IP configurada, no guardar PNG local si falla la red.
bool _permitirRespaldoArchivoEnPlataforma(
	ConfigImpresora config,
	ModoImpresora modo,
) {
	if (!esPlataformaMovilNativa()) {
		return true;
	}
	if (modo == ModoImpresora.red && config.hostRed.trim().isNotEmpty) {
		return false;
	}
	return true;
}

Future<void> _imprimirVentaRemotaTrasSync(Ref ref, SyncEvent evento) async {
	if (evento.tipo != TipoSyncEvento.saleCompleted) {
		return;
	}
	if (esPlataformaMovilNativa()) {
		return;
	}
	try {
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final servicio = contenedor.servicioAdmin;
		final configImpresora = await servicio.obtenerConfigImpresora();
		if (!_dispositivoPuedeImprimirFisicamente(configImpresora)) {
			return;
		}
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final venta = await servicio.obtenerVenta(ventaId);
		if (venta == null) {
			return;
		}
		final config = await servicio.obtenerConfigDispositivo();
		final hardware = await ref.read(hardwareRegistryProvider.future);
		final impresora = hardware.obtenerImpresora();
		if (venta.metodoPago == MetodoPago.credito) {
			final pagares = await obtenerTicketsDigitalesPagareCredito(
				venta: venta,
				servicioAdmin: servicio,
			);
			await imprimirTicketsDigitales(
				impresora: impresora,
				contenidos: pagares,
			);
			return;
		}
		final digital = await obtenerTicketDigitalVenta(
			venta: venta,
			servicioAdmin: servicio,
			config: config,
		);
		await imprimirTicketDigital(
			impresora: impresora,
			contenido: digital,
		);
	} on Object {
		// La venta ya quedó en SQLite; no bloquear el ciclo de sync.
	}
}

bool _dispositivoPuedeImprimirFisicamente(ConfigImpresora config) {
	if (config.modo == 'archivo') {
		return false;
	}
	if (config.modo == 'usb_windows') {
		return config.nombreImpresoraUsb.trim().isNotEmpty;
	}
	return config.hostRed.trim().isNotEmpty;
}

Future<String> _resolverDirectorioTickets() async {
	if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
		final docs = await getApplicationDocumentsDirectory();
		final dir = Directory('${docs.path}${Platform.pathSeparator}$CARPETA_DOCUMENTOS_APP${Platform.pathSeparator}tickets');
		if (!dir.existsSync()) {
			dir.createSync(recursive: true);
		}
		return dir.path;
	}
	final perfil = Platform.environment['USERPROFILE'];
	if (perfil != null && perfil.isNotEmpty) {
		return '$perfil${Platform.pathSeparator}Documents${Platform.pathSeparator}$CARPETA_DOCUMENTOS_APP${Platform.pathSeparator}tickets';
	}
	return '${Directory.current.path}${Platform.pathSeparator}tickets';
}

/// Servicio principal de operaciones de caja.
final servicioCajaProvider = FutureProvider<ServicioCaja>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioCaja;
});

/// Notificador de estado del carrito en pantalla de caja.
final carritoNotifierProvider = AsyncNotifierProvider<CarritoNotifier, EstadoCarrito>(
	CarritoNotifier.new,
);

/// Estado inmutable del carrito y catalogo en UI.
class EstadoCarrito {
	/// Crea estado visual de caja.
	const EstadoCarrito({
		required this.productos,
		required this.categorias,
		required this.categoriaSeleccionadaId,
		required this.lineas,
		required this.total,
		this.descuentoTicket = 0.0,
		required this.nombreTienda,
		this.nombreVendedor,
		this.nombreCliente,
		this.turnoAbierto = false,
		this.favoritos = const [],
		this.ticketsEnEspera = 0,
		this.indiceBusquedaSeleccionado = 0,
		this.stockLocalPorProducto = const {},
	});

	/// Catalogo visible en lista.
	final List<Producto> productos;

	/// Categorias activas para filtro.
	final List<Categoria> categorias;

	/// Categoria seleccionada en barra.
	final String categoriaSeleccionadaId;

	/// Lineas del carrito activo.
	final List<LineaCarrito> lineas;

	/// Total actual del carrito.
	final double total;

	/// Descuento global aplicado al ticket activo.
	final double descuentoTicket;

	/// Nombre de tienda activa.
	final String nombreTienda;

	/// Nombre del vendedor activo.
	final String? nombreVendedor;

	/// Cliente asignado al ticket activo (null = mostrador).
	final String? nombreCliente;

	/// Indica si hay turno de caja abierto.
	final bool turnoAbierto;

	/// Productos favoritos para venta rapida.
	final List<Producto> favoritos;

	/// Carritos apartados en esta caja.
	final int ticketsEnEspera;

	/// Producto resaltado al buscar con teclado.
	final int indiceBusquedaSeleccionado;

	/// Existencia local por productoId para resaltar sin stock en lista.
	final Map<String, double> stockLocalPorProducto;

	/// Genera copia con campos actualizados.
	EstadoCarrito copiarCon({
		List<Producto>? productos,
		List<Categoria>? categorias,
		String? categoriaSeleccionadaId,
		List<LineaCarrito>? lineas,
		double? total,
		double? descuentoTicket,
		String? nombreTienda,
		String? nombreVendedor,
		String? nombreCliente,
		bool? turnoAbierto,
		List<Producto>? favoritos,
		int? ticketsEnEspera,
		int? indiceBusquedaSeleccionado,
		Map<String, double>? stockLocalPorProducto,
	}) {
		return EstadoCarrito(
			productos: productos ?? this.productos,
			categorias: categorias ?? this.categorias,
			categoriaSeleccionadaId:
				categoriaSeleccionadaId ?? this.categoriaSeleccionadaId,
			lineas: lineas ?? this.lineas,
			total: total ?? this.total,
			descuentoTicket: descuentoTicket ?? this.descuentoTicket,
			nombreTienda: nombreTienda ?? this.nombreTienda,
			nombreVendedor: nombreVendedor ?? this.nombreVendedor,
			nombreCliente: nombreCliente ?? this.nombreCliente,
			turnoAbierto: turnoAbierto ?? this.turnoAbierto,
			favoritos: favoritos ?? this.favoritos,
			ticketsEnEspera: ticketsEnEspera ?? this.ticketsEnEspera,
			indiceBusquedaSeleccionado:
				indiceBusquedaSeleccionado ?? this.indiceBusquedaSeleccionado,
			stockLocalPorProducto:
				stockLocalPorProducto ?? this.stockLocalPorProducto,
		);
	}
}

/// Gestiona estado reactivo del carrito conectado a [ServicioCaja].
class CarritoNotifier extends AsyncNotifier<EstadoCarrito> {
	String _categoriaSeleccionadaId = CATEGORIA_TODOS_ID;
	String _textoBusqueda = '';
	List<Producto>? _catalogoCompleto;
	List<Categoria>? _categoriasCache;

	@override
	Future<EstadoCarrito> build() async {
		return _cargarEstadoInicial();
	}

	/// Cambia categoria activa filtrando el catalogo en memoria (sin parpadeo).
	void seleccionarCategoria(String categoriaId) {
		_categoriaSeleccionadaId = categoriaId;
		final actual = state.value;
		if (actual == null || _catalogoCompleto == null) {
			recargar(mostrarCarga: true);
			return;
		}
		state = AsyncData(
			actual.copiarCon(
				categoriaSeleccionadaId: categoriaId,
				productos: _filtrarProductos(_catalogoCompleto!, categoriaId, _textoBusqueda),
				indiceBusquedaSeleccionado: 0,
			),
		);
	}

	/// Filtra productos visibles por nombre o codigo de barras.
	void establecerBusqueda(String texto) {
		_textoBusqueda = texto.trim().toLowerCase();
		final actual = state.value;
		if (actual == null || _catalogoCompleto == null) {
			return;
		}
		final productos = _filtrarProductos(
			_catalogoCompleto!,
			_categoriaSeleccionadaId,
			_textoBusqueda,
		);
		state = AsyncData(
			actual.copiarCon(
				productos: productos,
				indiceBusquedaSeleccionado: 0,
			),
		);
	}

	/// Mueve el resaltado de busqueda en la lista (flechas arriba/abajo).
	void moverSeleccionBusqueda({required int delta}) {
		if (_textoBusqueda.isEmpty) {
			return;
		}
		final actual = state.value;
		if (actual == null || actual.productos.isEmpty) {
			return;
		}
		final indiceActual = actual.indiceBusquedaSeleccionado.clamp(
			0,
			actual.productos.length - 1,
		);
		var nuevoIndice = indiceActual + delta;
		if (nuevoIndice < 0) {
			nuevoIndice = actual.productos.length - 1;
		} else if (nuevoIndice >= actual.productos.length) {
			nuevoIndice = 0;
		}
		if (nuevoIndice == indiceActual) {
			return;
		}
		state = AsyncData(
			actual.copiarCon(indiceBusquedaSeleccionado: nuevoIndice),
		);
	}

	/// Limpia el texto de busqueda y restaura la lista.
	void limpiarBusqueda() {
		establecerBusqueda('');
	}

	/// Recarga catalogo y carrito desde servicio de caja.
	Future<void> recargar({
		bool mostrarCarga = false,
		bool invalidarCatalogo = false,
	}) async {
		if (invalidarCatalogo) {
			_catalogoCompleto = null;
			_categoriasCache = null;
		}
		if (mostrarCarga || !state.hasValue) {
			state = const AsyncLoading();
		}
		state = AsyncData(await _cargarEstadoInicial());
	}

	/// Agrega producto al carrito y actualiza estado UI.
	///
	/// [producto] Producto seleccionado en lista.
	/// [cantidad] Unidades a agregar; default 1.0.
	Future<void> agregarProducto(
		Producto producto, {
		double cantidad = 1.0,
	}) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		await servicio.agregarProducto(producto, cantidad: cantidad);
		await _refrescarDespuesDeOperacionCarrito();
	}

	/// Elimina linea del carrito por indice.
	///
	/// [indice] Posicion de linea a eliminar.
	Future<void> eliminarLinea(int indice) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		await servicio.eliminarLinea(indice);
		await _refrescarDespuesDeOperacionCarrito();
	}

	/// Aplica descuento absoluto a una linea del carrito.
	Future<String?> aplicarDescuentoLinea(int indice, double descuento) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = servicio.aplicarDescuentoLinea(indice, descuento);
		if (error == null) {
			await _refrescarDespuesDeOperacionCarrito();
		}
		return error;
	}

	/// Aplica descuento porcentual a una linea del carrito.
	Future<String?> aplicarDescuentoLineaPorcentaje(
		int indice,
		double porcentaje,
	) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = servicio.aplicarDescuentoLineaPorcentaje(indice, porcentaje);
		if (error == null) {
			await _refrescarDespuesDeOperacionCarrito();
		}
		return error;
	}

	/// Aplica descuento global al ticket activo.
	Future<String?> aplicarDescuentoTicket(double descuento) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = servicio.aplicarDescuentoTicket(descuento);
		if (error == null) {
			await _refrescarDespuesDeOperacionCarrito();
		}
		return error;
	}

	/// Aplica descuento porcentual global al ticket activo.
	Future<String?> aplicarDescuentoTicketPorcentaje(double porcentaje) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = servicio.aplicarDescuentoTicketPorcentaje(porcentaje);
		if (error == null) {
			await _refrescarDespuesDeOperacionCarrito();
		}
		return error;
	}

	/// Actualiza cantidad de una linea del carrito.
	Future<String?> actualizarCantidadLinea(int indice, double cantidad) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = await servicio.actualizarCantidadLinea(indice, cantidad);
		if (error == null) {
			await _refrescarDespuesDeOperacionCarrito();
		}
		return error;
	}

	/// Fija precio unitario manual en una linea del carrito.
	Future<String?> actualizarPrecioLinea(int indice, double precioUnitario) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final error = servicio.actualizarPrecioLinea(indice, precioUnitario);
		if (error == null) {
			await _refrescarDespuesDeOperacionCarrito();
		}
		return error;
	}

	/// Vacia carrito activo.
	Future<void> vaciarCarrito() async {
		final servicio = await ref.read(servicioCajaProvider.future);
		servicio.vaciarCarrito();
		await _refrescarDespuesDeOperacionCarrito();
	}

	/// Aparta el carrito actual en espera.
	Future<void> ponerCarritoEnEspera({String notas = ''}) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		await servicio.ponerCarritoEnEspera(notas: notas);
		await recargar(invalidarCatalogo: false);
	}

	/// Restaura un ticket apartado al carrito.
	Future<void> recuperarTicketEnEspera(String ticketId) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		await servicio.recuperarTicketEnEspera(ticketId);
		await _refrescarDespuesDeOperacionCarrito();
	}

	/// Elimina un ticket apartado sin recuperarlo.
	Future<void> eliminarTicketEnEspera(String ticketId) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		await servicio.eliminarTicketEnEspera(ticketId);
		await _refrescarContadorTicketsEnEspera();
	}

	/// Ejecuta cobro con parametros de multipago.
	Future<double?> cobrar(CobroRequest request) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final venta = await servicio.cobrar(request);
		await recargar(invalidarCatalogo: true);
		return venta?.total;
	}

	/// Actualiza lineas y total sin mostrar pantalla de carga.
	Future<void> _refrescarDespuesDeOperacionCarrito({
		bool invalidarCatalogo = false,
	}) async {
		final actual = state.value;
		if (actual == null) {
			await recargar(mostrarCarga: true, invalidarCatalogo: invalidarCatalogo);
			return;
		}
		if (invalidarCatalogo) {
			_catalogoCompleto = null;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		await _asegurarCatalogo();
		final stockLocal = await servicio.mapaStockLocalTienda();
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final turno = await contenedor.servicioAdmin
			.obtenerServicioCorteCaja()
			?.obtenerTurnoAbierto();
		state = AsyncData(
			actual.copiarCon(
				lineas: servicio.obtenerCarrito(),
				total: servicio.calcularTotalCarrito(),
				descuentoTicket: servicio.obtenerDescuentoTicket(),
				productos: _filtrarProductos(_catalogoCompleto!, _categoriaSeleccionadaId, _textoBusqueda),
				turnoAbierto: turno != null,
				nombreVendedor: servicio.obtenerVendedorActivo()?.nombre,
				nombreCliente: servicio.obtenerClienteActivo()?.nombre,
				favoritos: await servicio.listarFavoritosCaja(),
				ticketsEnEspera: await servicio.contarTicketsEnEspera(),
				stockLocalPorProducto: stockLocal,
			),
		);
	}

	Future<void> _refrescarContadorTicketsEnEspera() async {
		final actual = state.value;
		if (actual == null) {
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		state = AsyncData(
			actual.copiarCon(
				ticketsEnEspera: await servicio.contarTicketsEnEspera(),
			),
		);
	}

	Future<void> _asegurarCatalogo() async {
		if (_catalogoCompleto != null) {
			return;
		}
		final servicio = await ref.read(servicioCajaProvider.future);
		_catalogoCompleto = await servicio.listarProductos();
	}

	List<Producto> _filtrarProductos(
		List<Producto> todos,
		String categoriaId,
		String textoBusqueda,
	) {
		Iterable<Producto> lista = todos;
		if (categoriaId != CATEGORIA_TODOS_ID) {
			lista = lista.where((producto) => producto.categoriaId == categoriaId);
		}
		if (textoBusqueda.isNotEmpty) {
			return filtrarProductosPorBusqueda(lista.toList(), textoBusqueda);
		}
		return lista.toList();
	}

	/// Construye estado inicial desde servicio de caja.
	Future<EstadoCarrito> _cargarEstadoInicial() async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final usuario = ref.read(sesionUsuarioProvider);
		if (usuario != null) {
			await servicio.asegurarVendedorDesdeUsuario(usuario);
		}
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		await _asegurarCatalogo();
		_categoriasCache ??= await servicio.listarCategorias();
		final productos = _filtrarProductos(
			_catalogoCompleto!,
			_categoriaSeleccionadaId,
			_textoBusqueda,
		);
		final favoritos = await servicio.listarFavoritosCaja();
		final stockLocal = await servicio.mapaStockLocalTienda();
		final vendedor = servicio.obtenerVendedorActivo();
		final turno = await contenedor.servicioAdmin
			.obtenerServicioCorteCaja()
			?.obtenerTurnoAbierto();
		final tienda = await contenedor.servicioAdmin.obtenerTiendaActiva();
		return EstadoCarrito(
			productos: productos,
			categorias: _categoriasCache!,
			categoriaSeleccionadaId: _categoriaSeleccionadaId,
			lineas: servicio.obtenerCarrito(),
			total: servicio.calcularTotalCarrito(),
			descuentoTicket: servicio.obtenerDescuentoTicket(),
			nombreTienda: tienda?.nombre ?? 'Tienda',
			nombreVendedor: vendedor?.nombre,
			nombreCliente: servicio.obtenerClienteActivo()?.nombre,
			turnoAbierto: turno != null,
			favoritos: favoritos,
			ticketsEnEspera: await servicio.contarTicketsEnEspera(),
			stockLocalPorProducto: stockLocal,
		);
	}
}
