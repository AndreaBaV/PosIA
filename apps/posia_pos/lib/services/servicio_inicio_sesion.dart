/// Logica compartida para completar el inicio de sesion POSIA.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import '../bootstrap/limpiador_cache_local.dart';
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
			if (resultado.desdeHub) {
				final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
				final tiendaRepo = TiendaRepository(baseDatos: base);
				for (final tienda in resultado.tiendas) {
					if (tienda.activa) {
						await tiendaRepo.fusionarRemota(tienda);
					}
				}
			}
			await auth.guardarUsuarioRemoto(resultado);
			final configRepo = await container.read(configDispositivoRepoProvider.future);
			await GestorSesionPersistente.guardar(configRepo, usuario);

			container.read(sesionUsuarioProvider.notifier).iniciar(usuario);
			if (esAdmin) {
				container.read(sesionTiendaProvider.notifier).cerrar();
			}
			container.invalidate(contenedorServiciosProvider);
			final contenedor = await container.read(contenedorServiciosProvider.future);
			// Solo trabajo local / tiendas ya traidas en el login. Nada de hub aqui:
			// si el hub cuelga, la UI no debe quedarse en "Iniciando…".
			try {
				await contenedor.servicioAdmin
					.activarSesionTrasLogin(
						usuario,
						tiendasDesdeHub: resultado.tiendas,
					)
					.timeout(const Duration(seconds: 8));
			} on Object {
				// Continuar con datos locales; sync de fondo reintentara.
			}
			container.invalidate(contenedorServiciosProvider);
			final contenedorActivo = await container.read(contenedorServiciosProvider.future);

			// Desbloquear selector de tienda / caja antes de cualquier sync.
			if (esAdmin) {
				container.read(sesionAdminListoProvider.notifier).listo();
				container.invalidate(tiendasAccesoProvider);
			}

			// Sync (cola + catalogo) siempre en segundo plano.
			unawaited(() async {
				try {
					if (LimpiadorCacheLocal.seLimpioEnEsteArranque) {
						await contenedorActivo.syncOrchestrator
							.sincronizarDesdeOrigen()
							.timeout(
								const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS + 5),
							);
					} else {
						await contenedorActivo.syncOrchestrator
							.sincronizarCompleto()
							.timeout(
								const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS + 5),
							);
					}
					await PosiaLocalDatabase.obtenerInstancia()
						.completarMigracionIntegridadTrasSync();
				} on Object {
					// La caja opera localmente aunque el hub no responda.
				}
				if (!LimpiadorCacheLocal.seLimpioEnEsteArranque) {
					try {
						await contenedorActivo.servicioNomina?.reencolarPerfilesParaSync();
						await contenedorActivo.servicioNomina?.reencolarPeriodosParaSync();
						// incluirCatalogo: false — el login no re-sube el catalogo
						// completo (eso satura la cola en cada inicio de sesion);
						// solo empuja cambios reales pendientes y hace pull.
						await contenedorActivo.servicioAdmin.sincronizarManual(
							incluirCatalogo: false,
						);
						await PosiaLocalDatabase.obtenerInstancia()
							.completarMigracionIntegridadTrasSync();
					} on Object {
						// Catalogo se reintentara en sync automatico / manual.
					}
				}
				// Lectura integra del equipo en cada dispositivo: no solo el usuario
				// logueado. Requiere hub en linea; si falla, el equipo local queda
				// como estaba (no bloquea el login, ya se corrio en segundo plano).
				try {
					await contenedorActivo.servicioAdmin
						.importarUsuariosDesdeHub()
						.timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
				} on Object {
					// Se reintenta en el proximo login o con "Reparar equipo y roles".
				}
			}());
			container.invalidate(carritoNotifierProvider);

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
