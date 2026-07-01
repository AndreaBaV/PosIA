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
bool tileAdminVisible(Usuario? usuario, String clave) {
	if (usuario == null) {
		return true;
	}
	if (usuario.rol == RolUsuario.empleado) {
		return clave == 'mi_cuenta';
	}
	if (usuario.rol == RolUsuario.supervisor) {
		return !{'tiendas', 'sync', 'config'}.contains(clave);
	}
	return true;
}

/// Indica si el usuario puede ver la pestaña Admin en la navegacion principal.
bool puedeAccederPanelAdmin(Usuario usuario) => usuario.rol != RolUsuario.empleado;

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
	await ref.read(contenedorServiciosProvider.future);
	final carrito = ref.read(carritoNotifierProvider.notifier);
	if (ref.read(carritoNotifierProvider).hasValue) {
		await carrito.recargar(invalidarCatalogo: true);
	} else {
		ref.invalidate(carritoNotifierProvider);
	}
}

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

/// Indica si el tecnico completo la instalacion inicial (hub + caja).
final instalacionCompletaProvider = FutureProvider<bool>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	return configRepo.esInstalacionCompleta();
});
