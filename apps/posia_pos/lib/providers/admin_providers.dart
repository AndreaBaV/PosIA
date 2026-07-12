/// Proveedores de administracion y sesion admin POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

export 'app_providers.dart' show sesionTiendaProvider, sesionUsuarioProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:posia_ui/posia_ui.dart';

import '../models/item_historial.dart';
import 'app_providers.dart';

/// Repositorio de config del dispositivo (independiente del tenant activo).
final configDispositivoRepoProvider = FutureProvider<ConfigRepository>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatosDispositivo();
	return ConfigRepository(baseDatos: base);
});

/// Servicio de autenticacion (hub + copia local offline).
final servicioAutenticacionProvider = FutureProvider<ServicioAutenticacion>((ref) async {
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	final hubUrl = await configRepo.obtenerHubUrl();
	HubSyncClient? cliente;
	if (hubUrl != null) {
		final clave = await configRepo.obtenerValor(claveConfigHubApiKey);
		cliente = HubSyncClient(urlBase: hubUrl, claveApi: clave);
	}
	return ServicioAutenticacion(clienteHub: cliente);
});

/// Configuracion de hub/caja sin requerir sesion de tenant.
final servicioConfigDispositivoProvider =
	FutureProvider<ServicioConfiguracionDispositivo>((ref) async {
		final configRepo = await ref.watch(configDispositivoRepoProvider.future);
		return ServicioConfiguracionDispositivo(config: configRepo);
	});

/// Servicio de panel administrativo.
final servicioAdminProvider = FutureProvider<ServicioAdmin>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioAdmin;
});

/// Indica si el tile administrativo es visible para el rol actual.
bool tileAdminVisible(
	Usuario? usuario,
	String clave, {
	RolPersonalizado? rolPersonalizado,
}) {
	if (usuario == null) {
		return true;
	}
	return PoliticaAccesoAdmin.puedeVerSeccionAdmin(
		usuario,
		rolPersonalizado,
		clave,
	);
}

/// Indica si el usuario puede ver la pestaña Admin en la navegacion principal.
bool puedeAccederPanelAdmin(
	Usuario usuario, {
	RolPersonalizado? rolPersonalizado,
}) => PoliticaAccesoAdmin.puedeAccederPanelAdmin(usuario, rolPersonalizado);

/// Destinos de la barra inferior del shell principal.
enum DestinoNavegacionInicio { caja, asistencia, pedidos, admin }

/// Pestañas visibles segun rol base y permisos de administracion.
List<DestinoNavegacionInicio> destinosNavegacionInicio({
	required Usuario usuario,
	required bool muestraAdmin,
}) {
	final destinos = <DestinoNavegacionInicio>[DestinoNavegacionInicio.caja];
	if (usuario.rol == RolUsuario.empleado) {
		destinos.addAll([
			DestinoNavegacionInicio.asistencia,
			DestinoNavegacionInicio.pedidos,
		]);
	}
	if (muestraAdmin) {
		destinos.add(DestinoNavegacionInicio.admin);
	}
	return destinos;
}

/// Indice de un destino en la barra inferior, o null si no esta visible.
int? indiceDestinoNavegacionInicio(
	List<DestinoNavegacionInicio> destinos,
	DestinoNavegacionInicio destino,
) {
	final indice = destinos.indexOf(destino);
	return indice >= 0 ? indice : null;
}

/// Rol personalizado por identificador.
final rolPersonalizadoPorIdProvider =
	FutureProvider.family<RolPersonalizado?, String>((ref, rolId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		return servicio.obtenerRolPersonalizado(rolId);
	});

/// Rol personalizado del usuario en sesion (null si no aplica).
final rolPersonalizadoSesionProvider = Provider<RolPersonalizado?>((ref) {
	final usuario = ref.watch(sesionUsuarioProvider);
	final rolId = usuario?.rolPersonalizadoId;
	if (rolId == null || rolId.isEmpty) {
		return null;
	}
	return ref.watch(rolPersonalizadoPorIdProvider(rolId)).value;
});

/// Catalogo de roles personalizados para administracion.
final rolesPersonalizadosAdminProvider =
	FutureProvider<List<RolPersonalizado>>((ref) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final operador = ref.watch(sesionUsuarioProvider);
		return servicio.listarRolesPersonalizados(operador: operador);
	});

/// Roles activos para asignar a usuarios.
final rolesPersonalizadosActivosProvider =
	FutureProvider<List<RolPersonalizado>>((ref) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		return servicio.listarRolesPersonalizadosActivos();
	});

/// PIN administrativo configurado en el dispositivo.
final pinAdminProvider = FutureProvider<String>((ref) async {
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	return (await configRepo.obtenerValor(claveConfigPinAdmin)) ?? '';
});

/// ID de tienda activa del dispositivo.
final tiendaActivaIdProvider = FutureProvider<String>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.tiendaActivaId;
});

/// Configuracion operativa del dispositivo.
final configDispositivoProvider = FutureProvider<ConfigDispositivo>((ref) async {
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	return configRepo.obtenerConfigDispositivo();
});

/// Configuracion de impresora del dispositivo.
final configImpresoraProvider = FutureProvider<ConfigImpresora>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerConfigImpresora();
});

/// Solicitud de navegacion disparada por atajos desde caja.
class SolicitudNavegacionDesdeCaja {
	const SolicitudNavegacionDesdeCaja.admin() : clave = null;
	const SolicitudNavegacionDesdeCaja.seccion(this.clave);

	final String? clave;

	bool get esAdmin => clave == null;
}

/// Canal para que caja pida abrir Admin o una seccion concreta.
final solicitudNavegacionDesdeCajaProvider =
	NotifierProvider<SolicitudNavegacionDesdeCajaNotifier, SolicitudNavegacionDesdeCaja?>(
		SolicitudNavegacionDesdeCajaNotifier.new,
	);

class SolicitudNavegacionDesdeCajaNotifier extends Notifier<SolicitudNavegacionDesdeCaja?> {
	@override
	SolicitudNavegacionDesdeCaja? build() => null;

	void solicitar(SolicitudNavegacionDesdeCaja solicitud) {
		state = solicitud;
	}

	void limpiar() {
		state = null;
	}
}

/// Atajos de teclado personalizables en pantalla de caja.
final atajosCajaConfigProvider = FutureProvider<AtajosCajaConfig>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final json = await servicio.obtenerAtajosCajaJson();
	return AtajosCajaConfig.desdeJson(json);
});

/// Tecla configurada para cobrar en caja (derivada de atajos).
final teclaCobrarConfigProvider = FutureProvider<String>((ref) async {
	final atajos = await ref.watch(atajosCajaConfigProvider.future);
	return atajos.atajo(atajoAccionCobrar);
});

/// Empleados activos que pueden recibir pedidos asignados.
final empleadosAsignacionProvider = FutureProvider<List<Usuario>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	return servicio.listarEmpleadosParaAsignacion(operador: operador);
});

/// Recarga servicios y catalogo de caja tras cambios en productos, categorias o usuarios.
Future<void> refrescarDatosMaestros(WidgetRef ref) async {
	ref.invalidate(contenedorServiciosProvider);
	ref.invalidate(empleadosAsignacionProvider);
	ref.invalidate(listasPreciosAdminProvider);
	ref.invalidate(detalleListaPreciosProvider);
	ref.invalidate(productosCatalogoAdminProvider);
	await ref.read(contenedorServiciosProvider.future);
	final carrito = ref.read(carritoNotifierProvider.notifier);
	if (ref.read(carritoNotifierProvider).hasValue) {
		await carrito.recargar(invalidarCatalogo: true);
	} else {
		ref.invalidate(carritoNotifierProvider);
	}
}

/// Catalogo de productos para administracion (unificado).
final productosCatalogoAdminProvider = FutureProvider<List<Producto>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	final rolPersonalizado = ref.watch(rolPersonalizadoSesionProvider);
	return servicio.listarProductosCatalogoFiltrados(
		operador: operador,
		rolPersonalizado: rolPersonalizado,
	);
});

/// Detalle de una lista de precios: clientes asignados y productos con precio.
class DetalleListaPrecios {
	const DetalleListaPrecios({
		required this.clientes,
		required this.items,
	});

	final List<Cliente> clientes;
	final List<ItemListaPrecios> items;
}

/// Catalogo de listas de precios para administracion.
final listasPreciosAdminProvider = FutureProvider<List<ListaPrecios>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarListasPrecios();
});

/// Clientes y productos de una lista de precios.
final detalleListaPreciosProvider =
	FutureProvider.family<DetalleListaPrecios, String>((ref, listaId) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final clientes = await servicio.listarClientesPorLista(listaId);
		final items = await servicio.listarItemsListaPrecios(listaId);
		return DetalleListaPrecios(clientes: clientes, items: items);
	});

/// Invalida cache de listas de precios tras cambios en listas o asignacion de clientes.
void invalidarListasPrecios(WidgetRef ref) {
	ref.invalidate(listasPreciosAdminProvider);
	ref.invalidate(detalleListaPreciosProvider);
}

/// Clientes para administracion.
final clientesAdminProvider = FutureProvider<List<Cliente>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarClientes();
});

/// Creditos pendientes de liquidar en panel admin.
final creditosPendientesAdminProvider = FutureProvider<List<Venta>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCreditosPendientes();
});

/// Ventas y pedidos entregados para historial unificado.
final historialOperacionesProvider =
	FutureProvider.family<List<ItemHistorial>, int>((ref, dias) async {
		final servicio = await ref.watch(servicioAdminProvider.future);
		final desde = DateTime.now().toUtc().subtract(Duration(days: dias));
		final hasta = DateTime.now().toUtc();
		final ventas = await servicio.listarHistorialVentas(
			FiltroVentas(tiendaId: servicio.tiendaActivaId, desde: desde, hasta: hasta),
		);
		final pedidos = await servicio.listarPedidosEntregadosHistorial(dias: dias);
		final items = <ItemHistorial>[
			...ventas.map(ItemHistorial.venta),
			...pedidos.map(ItemHistorial.pedido),
		]..sort((a, b) => b.fecha.compareTo(a.fecha));
		return items;
	});

/// Cotizaciones guardadas en panel admin.
final cotizacionesAdminProvider = FutureProvider.family<List<Cotizacion>, int>((ref, dias) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCotizaciones(dias: dias);
});

/// Categorias para formulario de producto.
final categoriasFormularioAdminProvider = FutureProvider<List<Categoria>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarCategorias();
});

/// Proveedores para formulario de producto.
final proveedoresFormularioAdminProvider = FutureProvider<List<Proveedor>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProveedores();
});

/// Proveedores para administracion.
final proveedoresAdminProvider = FutureProvider<List<Proveedor>>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.listarProveedores();
});

/// Ubicación seleccionable para mercancía de compra (almacén o tienda).
class UbicacionMercanciaCompra {
	const UbicacionMercanciaCompra({
		required this.tipo,
		required this.id,
		required this.etiqueta,
	});

	final TipoDestinoCompra tipo;
	final String id;
	final String etiqueta;

	String get clave => '${tipo.name}:$id';
}

/// Datos para pantalla de compras a nivel empresa.
class DatosComprasAdmin {
	const DatosComprasAdmin({
		required this.compras,
		required this.proveedores,
		required this.productos,
		required this.tiendas,
		required this.almacenes,
		required this.ubicaciones,
		required this.ubicacionPorDefecto,
		required this.nombresProveedor,
		required this.nombresUbicacion,
	});

	final List<Compra> compras;
	final List<Proveedor> proveedores;
	final List<Producto> productos;
	final List<Tienda> tiendas;
	final List<Almacen> almacenes;
	final List<UbicacionMercanciaCompra> ubicaciones;
	final UbicacionMercanciaCompra ubicacionPorDefecto;
	final Map<String, String> nombresProveedor;
	final Map<String, String> nombresUbicacion;
}

/// Compras, proveedores, catálogo y ubicaciones de la razón social.
final comprasDatosAdminProvider = FutureProvider<DatosComprasAdmin>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	final operador = ref.watch(sesionUsuarioProvider);
	final proveedores = await ref.watch(proveedoresAdminProvider.future);
	final tiendas = await servicio.obtenerTiendasPermitidas(operador: operador);
	final almacenes = (await servicio.listarAlmacenes()).where((a) => a.activo).toList();
	final compras = await servicio.listarCompras(operador: operador);
	final productos = await servicio.listarProductos();
	final almacenDefecto = await servicio.obtenerAlmacenPorDefectoCompra();
	final ubicaciones = <UbicacionMercanciaCompra>[
		...almacenes.map(
			(a) => UbicacionMercanciaCompra(
				tipo: TipoDestinoCompra.almacen,
				id: a.id,
				etiqueta: 'Almacén · ${a.nombre}',
			),
		),
		...tiendas.map(
			(t) => UbicacionMercanciaCompra(
				tipo: TipoDestinoCompra.tienda,
				id: t.id,
				etiqueta: 'Tienda · ${t.nombre}',
			),
		),
	];
	final ubicacionPorDefecto = ubicaciones.firstWhere(
		(u) => u.tipo == TipoDestinoCompra.almacen && u.id == almacenDefecto.id,
		orElse: () => ubicaciones.firstWhere(
			(u) => u.tipo == TipoDestinoCompra.almacen,
			orElse: () => ubicaciones.first,
		),
	);
	return DatosComprasAdmin(
		compras: compras,
		proveedores: proveedores.where((p) => p.activo).toList(),
		productos: productos,
		tiendas: tiendas,
		almacenes: almacenes,
		ubicaciones: ubicaciones,
		ubicacionPorDefecto: ubicacionPorDefecto,
		nombresProveedor: {for (final p in proveedores) p.id: p.nombre},
		nombresUbicacion: {for (final u in ubicaciones) u.clave: u.etiqueta},
	);
});

/// Invalida caches de proveedores tras altas, ediciones o bajas.
void invalidarProveedores(WidgetRef ref) {
	ref.invalidate(proveedoresAdminProvider);
	ref.invalidate(proveedoresFormularioAdminProvider);
	ref.invalidate(comprasDatosAdminProvider);
}

/// Indica si el tecnico completo la instalacion inicial (hub + caja).
final instalacionCompletaProvider = FutureProvider<bool>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	return configRepo.esInstalacionCompleta();
});
