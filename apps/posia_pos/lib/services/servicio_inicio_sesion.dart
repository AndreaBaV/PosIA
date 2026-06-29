/// Logica compartida para completar el inicio de sesion POSIA.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_sync/posia_sync.dart';

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
		final usuario = resultado.usuario;

		final auth = await ref.read(servicioAutenticacionProvider.future);
		await auth.guardarUsuarioRemoto(resultado);
		final configRepo = await ref.read(configDispositivoRepoProvider.future);
		await GestorSesionPersistente.guardar(configRepo, usuario);

		ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);
		if (usuario.rol == RolUsuario.administrador) {
			ref.read(sesionTiendaProvider.notifier).cerrar();
		}
		ref.invalidate(contenedorServiciosProvider);
		await ref.read(contenedorServiciosProvider.future);

		final servicio = await ref.read(servicioAdminProvider.future);
		final hubUrl = await configRepo.obtenerHubUrl();
		final hubApiKey = await configRepo.obtenerValor(claveConfigHubApiKey);
		HubSyncClient? clienteHub;
		if (hubUrl != null && hubUrl.isNotEmpty) {
			clienteHub = HubSyncClient(urlBase: hubUrl, claveApi: hubApiKey);
		}
		await servicio.activarSesionTrasLogin(
			usuario,
			tiendasDesdeHub: resultado.tiendas,
			obtenerTiendasRemotas: clienteHub == null
				? null
				: () async {
					final remotas = await clienteHub!.obtenerTiendas();
					return remotas
						.map(
							(t) => Tienda(
								id: t.id,
								nombre: t.nombre,
								direccion: t.direccion,
								activa: t.activa,
							),
						)
						.toList();
				},
		);
		ref.invalidate(contenedorServiciosProvider);

		if (usuario.rol != RolUsuario.administrador) {
			final tiendaId = usuario.tiendaId;
			if (tiendaId == null) {
				throw StateError('Usuario sin tienda asignada');
			}
			ref.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
		}

		ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);
		final servicioCaja = await ref.read(servicioCajaProvider.future);
		await servicioCaja.asegurarVendedorDesdeUsuario(usuario);

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
	}
}
