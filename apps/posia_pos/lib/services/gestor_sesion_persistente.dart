/// Restaura y persiste la sesion del usuario entre reinicios de la app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class GestorSesionPersistente {
	GestorSesionPersistente._();

	static Future<void> restaurarSiExiste(Ref ref) async {
		if (ref.read(sesionUsuarioProvider) != null) {
			return;
		}
		final configRepo = await ref.read(configDispositivoRepoProvider.future);
		if (!await configRepo.esInstalacionCompleta()) {
			return;
		}
		final usuarioId = await configRepo.obtenerValor(claveConfigUltimoUsuarioId);
		if (usuarioId == null || usuarioId.trim().isEmpty) {
			return;
		}
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
		final usuario = await UsuarioRepository(baseDatos: base).obtenerPorId(usuarioId);
		if (usuario == null || !usuario.activo) {
			await configRepo.guardarValor(claveConfigUltimoUsuarioId, '');
			return;
		}
		ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);

		if (usuario.rol != RolUsuario.administrador) {
			final tiendaId = usuario.tiendaId;
			if (tiendaId != null && tiendaId.isNotEmpty) {
				ref.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
			}
		}

		ref.invalidate(contenedorServiciosProvider);
		final contenedor = await ref.read(contenedorServiciosProvider.future);
		if (usuario.rol != RolUsuario.administrador) {
			final tiendaId = usuario.tiendaId;
			if (tiendaId != null && tiendaId.isNotEmpty) {
				await contenedor.servicioAdmin.cambiarTiendaActiva(tiendaId);
			}
		}
		final servicioCaja = await ref.read(servicioCajaProvider.future);
		await servicioCaja.asegurarVendedorDesdeUsuario(usuario);
	}

	static Future<void> guardar(
		ConfigRepository configRepo,
		Usuario usuario,
	) async {
		await configRepo.guardarValor(claveConfigUltimoUsuarioId, usuario.id);
	}

	static Future<void> limpiar(ConfigRepository configRepo) async {
		await configRepo.guardarValor(claveConfigUltimoUsuarioId, '');
	}

	static Future<void> cerrarSesion(WidgetRef ref) async {
		final configRepo = await ref.read(configDispositivoRepoProvider.future);
		await limpiar(configRepo);
		await PosiaLocalDatabase.obtenerInstancia().cerrarBaseOperativa();
		ref.read(sesionUsuarioProvider.notifier).cerrar();
		ref.read(sesionTiendaProvider.notifier).cerrar();
		ref.invalidate(contenedorServiciosProvider);
	}
}
