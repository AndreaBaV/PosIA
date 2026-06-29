/// Restaura y persiste la sesion del usuario entre reinicios de la app.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';

class GestorSesionPersistente {
	GestorSesionPersistente._();

	static Future<void> restaurarSiExiste(Ref ref) async {
		try {
			await _restaurarSiExisteInterno(ref).timeout(const Duration(seconds: 15));
		} on Object {
			await _abortarRestauracion(ref);
		}
	}

	static Future<void> _abortarRestauracion(Ref ref) async {
		try {
			final configRepo = await ref.read(configDispositivoRepoProvider.future);
			await limpiar(configRepo);
		} on Object {
			// Ignorar: lo importante es no bloquear el arranque.
		}
		ref.read(sesionUsuarioProvider.notifier).cerrar();
		ref.read(sesionTiendaProvider.notifier).cerrar();
	}

	static Future<void> _restaurarSiExisteInterno(Ref ref) async {
		if (ref.read(sesionUsuarioProvider) != null) {
			return;
		}
		try {
			final config = await ref.read(configDispositivoRepoProvider.future);
			if (!await config.esInstalacionCompleta()) {
				return;
			}
			final usuarioId = await config.obtenerValor(claveConfigUltimoUsuarioId);
			if (usuarioId == null || usuarioId.trim().isEmpty) {
				return;
			}
			final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
			final usuario = await UsuarioRepository(baseDatos: base).obtenerPorId(
				usuarioId,
			);
			if (usuario == null ||
				!usuario.activo ||
				usuario.rol == RolUsuario.administrador) {
				await config.guardarValor(claveConfigUltimoUsuarioId, '');
				return;
			}
			ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);

			final tiendaId = usuario.tiendaId;
			if (tiendaId != null && tiendaId.isNotEmpty) {
				ref.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
				final configDispositivo = await config.obtenerConfigDispositivo();
				await config.guardarConfigDispositivo(
					ConfigDispositivo(
						tiendaId: tiendaId,
						cajaId: configDispositivo.cajaId,
						nombreCaja: configDispositivo.nombreCaja,
					),
				);
			}
		} on Object {
			await _abortarRestauracion(ref);
		}
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
