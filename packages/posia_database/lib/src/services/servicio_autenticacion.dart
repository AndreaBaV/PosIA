/// Autenticacion contra el hub con respaldo local offline.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

import '../database/posia_local_database.dart';
import '../models/motivo_fallo_auth.dart';
import '../models/resultado_autenticacion.dart';
import '../repositories/usuario_repository.dart';
import '../utils/limpiador_base_local.dart';

/// Valida credenciales contra el hub (fuente de verdad) con respaldo local offline.
class ServicioAutenticacion {
	ServicioAutenticacion({
		HubSyncClient? clienteHub,
		SyncOrchestrator? orquestadorSync,
	}) : _clienteHub = clienteHub,
	     _orquestadorSync = orquestadorSync;

	final HubSyncClient? _clienteHub;
	final SyncOrchestrator? _orquestadorSync;

	Future<BusquedaPerfilAuth> buscarPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		final errorFormato = ValidadorCodigoUsuario.validar(limpio);
		if (errorFormato != null || limpio.isEmpty) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		await _sincronizarConHubSiPosible();
		final hub = _clienteHub;
		if (hub != null) {
			// Render free puede tardar ~50 s en despertar; usar timeout largo.
			final salud = await hub.mantenerHubVivo();
			if (salud) {
				if (!await hub.tieneAuthHub()) {
					return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubSinPostgres);
				}
				final perfil = await hub.obtenerPerfilUsuario(limpio);
				if (perfil != null) {
					if (!perfil.activo) {
						return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioInactivo);
					}
					return BusquedaPerfilAuth.usuario(_mapearPerfilHub(perfil));
				}
				return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
			}
		}
		final local = await _buscarPerfilLocal(limpio);
		if (local != null) {
			return BusquedaPerfilAuth.usuario(local);
		}
		if (hub == null) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
		}
		return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoDisponible);
	}

	Future<IntentoAutenticacionAuth> autenticar(String codigo, String pin) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty || pin.isEmpty) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
		}
		await _sincronizarConHubSiPosible();
		final hub = _clienteHub;
		if (hub != null) {
			final salud = await hub.mantenerHubVivo();
			if (salud) {
				if (!await hub.tieneAuthHub()) {
					return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubSinPostgres);
				}
				final remoto = await hub.iniciarSesion(codigo: limpio, pin: pin);
				if (remoto != null) {
					if (!remoto.perfil.activo) {
						return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.usuarioInactivo);
					}
					return IntentoAutenticacionAuth.exito(_mapearLoginHub(remoto));
				}
				return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
			}
		}
		final local = await _autenticarLocal(limpio, pin);
		if (local != null) {
			return IntentoAutenticacionAuth.exito(local);
		}
		if (hub == null) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
		}
		return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoDisponible);
	}

	Future<void> _sincronizarConHubSiPosible() async {
		final orquestador = _orquestadorSync;
		if (orquestador == null || !orquestador.tieneHubConfigurado()) {
			return;
		}
		try {
			final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
			await LimpiadorBaseLocal.eliminarDatosEjemplo(base);
			await orquestador.sincronizarCompleto();
		} on Object {
			// El login puede continuar con copia local si el hub falla.
		}
	}

	Future<ResultadoAutenticacion?> _autenticarLocal(String codigo, String pin) async {
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
		final usuario = await UsuarioRepository(baseDatos: base).autenticar(codigo, pin);
		if (usuario == null) {
			return null;
		}
		return ResultadoAutenticacion(usuario: usuario);
	}

	Future<Usuario?> _buscarPerfilLocal(String codigo) async {
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
		final usuario = await UsuarioRepository(baseDatos: base).obtenerPorCodigo(codigo);
		if (usuario == null || !usuario.activo) {
			return null;
		}
		return usuario;
	}

	Future<void> guardarUsuarioRemoto(ResultadoAutenticacion resultado) async {
		if (!resultado.desdeHub) {
			return;
		}
		final u = resultado.usuario;
		await UsuarioRepository(
			baseDatos: await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos(),
		).guardarRemoto(
			id: u.id,
			nombre: u.nombre,
			codigo: u.codigo,
			rol: u.rol,
			tiendaId: u.tiendaId,
			activo: u.activo,
			pinCredencial: resultado.pinCredencial!,
			creadoEn: resultado.creadoEn!,
			actualizadoEn: resultado.actualizadoEn!,
		);
	}

	Usuario _mapearPerfilHub(PerfilUsuarioHub perfil) {
		return Usuario(
			id: perfil.id,
			nombre: perfil.nombre,
			codigo: perfil.codigo,
			rol: RolUsuario.values.byName(perfil.rol),
			tiendaId: perfil.tiendaId,
			activo: perfil.activo,
		);
	}

	ResultadoAutenticacion _mapearLoginHub(RespuestaLoginHub login) {
		return ResultadoAutenticacion(
			usuario: _mapearPerfilHub(login.perfil),
			pinCredencial: login.pinCredencial,
			creadoEn: login.creadoEn,
			actualizadoEn: login.actualizadoEn,
			tiendas: login.tiendas
				.map(
					(t) => Tienda(
						id: t.id,
						nombre: t.nombre,
						direccion: t.direccion,
						activa: t.activa,
					),
				)
				.toList(),
		);
	}
}
