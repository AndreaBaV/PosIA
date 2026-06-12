/// Proveedores de administracion y sesion admin POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 19:45:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 19:45:00 (UTC-6)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_database/posia_database.dart';

import 'app_providers.dart';

/// Servicio de panel administrativo.
final servicioAdminProvider = FutureProvider<ServicioAdmin>((ref) async {
	final contenedor = await ref.watch(contenedorServiciosProvider.future);
	return contenedor.servicioAdmin;
});

/// Gestiona confirmacion de tienda al iniciar la aplicacion.
final sesionTiendaProvider = NotifierProvider<SesionTiendaNotifier, String?>(
	SesionTiendaNotifier.new,
);

/// Estado de tienda confirmada en la sesion actual.
class SesionTiendaNotifier extends Notifier<String?> {
	@override
	String? build() {
		return null;
	}

	void confirmar(String tiendaId) {
		state = tiendaId;
	}

	void cerrar() {
		state = null;
	}
}

/// Indica si el administrador ha desbloqueado el panel con PIN.
final sesionAdminProvider = NotifierProvider<SesionAdminNotifier, bool>(
	SesionAdminNotifier.new,
);

/// Gestiona estado de sesion administrativa desbloqueada.
class SesionAdminNotifier extends Notifier<bool> {
	@override
	bool build() {
		return false;
	}

	/// Marca sesion admin como desbloqueada.
	void desbloquear() {
		state = true;
	}

	/// Cierra sesion administrativa.
	void cerrar() {
		state = false;
	}
}

/// PIN administrativo configurado en el dispositivo.
final pinAdminProvider = FutureProvider<String>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerPinAdmin();
});

/// ID de tienda activa del dispositivo.
final tiendaActivaIdProvider = FutureProvider<String>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.tiendaActivaId;
});

/// Configuracion operativa del dispositivo.
final configDispositivoProvider = FutureProvider<ConfigDispositivo>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerConfigDispositivo();
});

/// Configuracion de impresora del dispositivo.
final configImpresoraProvider = FutureProvider<ConfigImpresora>((ref) async {
	final servicio = await ref.watch(servicioAdminProvider.future);
	return servicio.obtenerConfigImpresora();
});
