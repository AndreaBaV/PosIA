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

import '../bootstrap/inicializador_app.dart';
import '../sync/sincronizador_automatico.dart';

/// Estado de inicializacion de la aplicacion.
final estadoInicializacionProvider = FutureProvider<void>((ref) async {
	await InicializadorApp.preparar();
});

/// Contenedor de servicios de dominio y persistencia.
final contenedorServiciosProvider = FutureProvider<ContenedorServicios>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	return FabricaServicios.construir();
});

/// Sincronizador automatico activo mientras vive la app.
final sincronizadorAutomaticoProvider = FutureProvider<SincronizadorAutomatico>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final sincronizador = SincronizadorAutomatico(
		orquestador: contenedor.syncOrchestrator,
	);
	sincronizador.iniciar();
	ref.onDispose(sincronizador.detener);
	return sincronizador;
});

/// Licencia activa segun tenant configurado en el dispositivo.
final licenciaProvider = FutureProvider<Licencia>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final config = await contenedor.servicioAdmin.obtenerConfigDispositivo();
	final tenantId = config.tenantId.isNotEmpty ? config.tenantId : TENANT_DEMO_ID;
	return Licencia(
		tenantId: tenantId,
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
		soporteExpiraEn: DateTime.utc(2027, 6, 7),
	);
});

/// Registro de hardware segun configuracion de impresora del dispositivo.
final hardwareRegistryProvider = FutureProvider<HardwareRegistry>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	final configImpresora = await contenedor.servicioAdmin.obtenerConfigImpresora();
	final directorioTickets = await _resolverDirectorioTickets();
	return HardwareRegistry(
		scanner: TecladoBarcodeScanner(),
		impresora: ImpresoraConfigurable(
			modo: _resolverModoImpresora(configImpresora.modo),
			hostRed: configImpresora.hostRed,
			puertoRed: configImpresora.puertoRed,
			directorioArchivo: directorioTickets,
		),
	);
});

ModoImpresora _resolverModoImpresora(String modo) {
	switch (modo) {
		case 'archivo':
			return ModoImpresora.archivo;
		case 'red':
			return ModoImpresora.red;
		default:
			return ModoImpresora.ambos;
	}
}

Future<String> _resolverDirectorioTickets() async {
	if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
		final docs = await getApplicationDocumentsDirectory();
		final dir = Directory('${docs.path}${Platform.pathSeparator}POSIA${Platform.pathSeparator}tickets');
		if (!dir.existsSync()) {
			dir.createSync(recursive: true);
		}
		return dir.path;
	}
	final perfil = Platform.environment['USERPROFILE'];
	if (perfil != null && perfil.isNotEmpty) {
		return '$perfil${Platform.pathSeparator}Documents${Platform.pathSeparator}POSIA${Platform.pathSeparator}tickets';
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
		required this.nombreTienda,
		this.nombreVendedor,
		this.turnoAbierto = false,
	});

	/// Catalogo visible en grilla.
	final List<Producto> productos;

	/// Categorias activas para filtro.
	final List<Categoria> categorias;

	/// Categoria seleccionada en barra.
	final String categoriaSeleccionadaId;

	/// Lineas del carrito activo.
	final List<LineaCarrito> lineas;

	/// Total actual del carrito.
	final double total;

	/// Nombre de tienda activa.
	final String nombreTienda;

	/// Nombre del vendedor activo.
	final String? nombreVendedor;

	/// Indica si hay turno de caja abierto.
	final bool turnoAbierto;

	/// Genera copia con campos actualizados.
	EstadoCarrito copiarCon({
		List<Producto>? productos,
		List<Categoria>? categorias,
		String? categoriaSeleccionadaId,
		List<LineaCarrito>? lineas,
		double? total,
		String? nombreTienda,
		String? nombreVendedor,
		bool? turnoAbierto,
	}) {
		return EstadoCarrito(
			productos: productos ?? this.productos,
			categorias: categorias ?? this.categorias,
			categoriaSeleccionadaId:
				categoriaSeleccionadaId ?? this.categoriaSeleccionadaId,
			lineas: lineas ?? this.lineas,
			total: total ?? this.total,
			nombreTienda: nombreTienda ?? this.nombreTienda,
			nombreVendedor: nombreVendedor ?? this.nombreVendedor,
			turnoAbierto: turnoAbierto ?? this.turnoAbierto,
		);
	}
}

/// Gestiona estado reactivo del carrito conectado a [ServicioCaja].
class CarritoNotifier extends AsyncNotifier<EstadoCarrito> {
	String _categoriaSeleccionadaId = CATEGORIA_TODOS_ID;

	@override
	Future<EstadoCarrito> build() async {
		return _cargarEstadoInicial();
	}

	/// Cambia categoria activa y recarga productos filtrados.
	Future<void> seleccionarCategoria(String categoriaId) async {
		_categoriaSeleccionadaId = categoriaId;
		await recargar();
	}

	/// Recarga catalogo y carrito desde servicio de caja.
	Future<void> recargar() async {
		state = const AsyncLoading();
		state = AsyncData(await _cargarEstadoInicial());
	}

	/// Agrega producto al carrito y actualiza estado UI.
	///
	/// [producto] Producto seleccionado en grilla.
	Future<void> agregarProducto(Producto producto) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		await servicio.agregarProducto(producto);
		await recargar();
	}

	/// Elimina linea del carrito por indice.
	///
	/// [indice] Posicion de linea a eliminar.
	Future<void> eliminarLinea(int indice) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		servicio.eliminarLinea(indice);
		await recargar();
	}

	/// Vacia carrito activo.
	Future<void> vaciarCarrito() async {
		final servicio = await ref.read(servicioCajaProvider.future);
		servicio.vaciarCarrito();
		await recargar();
	}

	/// Ejecuta cobro con metodo de pago indicado.
	///
	/// [metodoPago] Forma de pago seleccionada.
	/// Retorna total cobrado o null si carrito vacio.
	Future<double?> cobrar(MetodoPago metodoPago) async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final venta = await servicio.cobrar(metodoPago);
		await recargar();
		return venta?.total;
	}

	/// Construye estado inicial desde servicio de caja.
	Future<EstadoCarrito> _cargarEstadoInicial() async {
		final servicio = await ref.read(servicioCajaProvider.future);
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		final categorias = await servicio.listarCategorias();
		final productos = await servicio.listarProductos(
			categoriaId: _categoriaSeleccionadaId,
		);
		final vendedor = servicio.obtenerVendedorActivo();
		final turno = await contenedor.servicioAdmin
			.obtenerServicioCorteCaja()
			?.obtenerTurnoAbierto();
		final tienda = await contenedor.servicioAdmin.obtenerTiendaActiva();
		return EstadoCarrito(
			productos: productos,
			categorias: categorias,
			categoriaSeleccionadaId: _categoriaSeleccionadaId,
			lineas: servicio.obtenerCarrito(),
			total: servicio.calcularTotalCarrito(),
			nombreTienda: tienda?.nombre ?? 'Tienda',
			nombreVendedor: vendedor?.nombre,
			turnoAbierto: turno != null,
		);
	}
}
