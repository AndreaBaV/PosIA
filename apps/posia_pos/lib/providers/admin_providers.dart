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

import 'app_providers.dart';

/// Repositorio de config del dispositivo (independiente del tenant activo).
final configDispositivoRepoProvider = FutureProvider<ConfigRepository>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatosDispositivo();
	return ConfigRepository(baseDatos: base);
});

/// Servicio de autenticacion multi-tenant (hub + copia local).
final servicioAutenticacionProvider = FutureProvider<ServicioAutenticacion>((ref) async {
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	final hubUrl = await configRepo.obtenerHubUrl();
	HubSyncClient? cliente;
	if (hubUrl != null) {
		final clave = await configRepo.obtenerValor(CLAVE_CONFIG_HUB_API_KEY);
		cliente = HubSyncClient(urlBase: hubUrl, claveApi: clave);
	}
	return ServicioAutenticacion(configDispositivo: configRepo, clienteHub: cliente);
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
	return (await configRepo.obtenerValor(CLAVE_CONFIG_PIN_ADMIN)) ?? '';
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

/// Tecla configurada para cobrar en caja (ej. F12).
final teclaCobrarConfigProvider = FutureProvider<String>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerTeclaCobrar();
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
	await ref.read(contenedorServiciosProvider.future);
	final carrito = ref.read(carritoNotifierProvider.notifier);
	if (ref.read(carritoNotifierProvider).hasValue) {
		await carrito.recargar(invalidarCatalogo: true);
	} else {
		ref.invalidate(carritoNotifierProvider);
	}
}

/// Indica si el tecnico completo la instalacion inicial (hub + caja).
final instalacionCompletaProvider = FutureProvider<bool>((ref) async {
	await ref.watch(estadoInicializacionProvider.future);
	final configRepo = await ref.watch(configDispositivoRepoProvider.future);
	return configRepo.esInstalacionCompleta();
});
