/// Logica compartida para completar el inicio de sesion POSIA.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import 'gestor_acceso_biometrico.dart';
import 'gestor_sesion_persistente.dart';

class ServicioInicioSesion {
	ServicioInicioSesion._();

	static Future<Usuario> completar(
		WidgetRef ref,
		ResultadoAutenticacion resultado, {
		String? pinPlano,
		bool registrarBiometria = false,
	}) async {
		// WidgetRef no es seguro tras desmontar la pantalla de login; usar container.
		final container = ref.container;
		final usuario = resultado.usuario;
		final esAdmin = usuario.rol == RolUsuario.administrador;

		if (esAdmin) {
			container.read(sesionAdminListoProvider.notifier).preparando();
		}

		try {
			final auth = await container.read(servicioAutenticacionProvider.future);
			await auth.guardarUsuarioRemoto(resultado);
			final configRepo = await container.read(configDispositivoRepoProvider.future);
			await GestorSesionPersistente.guardar(configRepo, usuario);

			container.read(sesionUsuarioProvider.notifier).iniciar(usuario);
			if (esAdmin) {
				container.read(sesionTiendaProvider.notifier).cerrar();
			}
			container.invalidate(contenedorServiciosProvider);
			await container.read(contenedorServiciosProvider.future);

			final servicio = await container.read(servicioAdminProvider.future);
			await servicio
				.activarSesionTrasLogin(
					usuario,
					tiendasDesdeHub: resultado.tiendas,
				)
				.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS + 10));
			container.invalidate(contenedorServiciosProvider);

			if (!esAdmin) {
				final tiendaId = usuario.tiendaId;
				if (tiendaId == null) {
					throw StateError('Usuario sin tienda asignada');
				}
				container.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
				final servicioCaja = await container.read(servicioCajaProvider.future);
				await servicioCaja.asegurarVendedorDesdeUsuario(usuario);
			}

			container.read(sesionUsuarioProvider.notifier).iniciar(usuario);

			if (registrarBiometria && pinPlano != null && pinPlano.isNotEmpty) {
				final gestor = GestorAccesoBiometrico();
				if (await gestor.estaDisponible()) {
					await gestor.registrarPerfil(
						PerfilAccesoBiometrico(
							usuarioId: usuario.id,
							codigo: usuario.codigo,
							pin: pinPlano,
							nombre: usuario.nombre,
						),
					);
				}
			}

			return usuario;
		} finally {
			if (esAdmin) {
				container.read(sesionAdminListoProvider.notifier).listo();
				container.invalidate(tiendasAccesoProvider);
			}
		}
	}
}
