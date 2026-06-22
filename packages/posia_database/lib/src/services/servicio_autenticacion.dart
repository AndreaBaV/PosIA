/// Autenticacion multi-tenant: resuelve tenant al iniciar sesion.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

import '../database/posia_local_database.dart';
import '../models/motivo_fallo_auth.dart';
import '../models/resultado_autenticacion.dart';
import '../repositories/config_repository.dart';
import '../repositories/usuario_repository.dart';

/// Valida credenciales contra el hub o la copia local del tenant.
class ServicioAutenticacion {
	ServicioAutenticacion({
		required ConfigRepository configDispositivo,
		HubSyncClient? clienteHub,
	}) : _configDispositivo = configDispositivo,
	     _clienteHub = clienteHub;

	final ConfigRepository _configDispositivo;
	final HubSyncClient? _clienteHub;

	/// Busca perfil publico por codigo (sin validar PIN).
	Future<BusquedaPerfilAuth> buscarPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		final errorFormato = ValidadorCodigoUsuario.validar(limpio);
		if (errorFormato != null) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		if (limpio.isEmpty) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		final hub = _clienteHub;
		if (hub != null) {
			final salud = await hub.verificarSalud();
			if (!salud) {
				final offline = await _buscarPerfilLocal(limpio);
				if (offline != null) {
					return BusquedaPerfilAuth.usuario(offline);
				}
				return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoDisponible);
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
		final local = await _buscarPerfilLocal(limpio);
		if (local != null) {
			return BusquedaPerfilAuth.usuario(local);
		}
		final tenantId = await _configDispositivo.obtenerValor(CLAVE_CONFIG_TENANT_ID);
		if (tenantId == null || tenantId.isEmpty) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
		}
		return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
	}

	/// Autentica y devuelve el tenant al que pertenece la cuenta.
	Future<IntentoAutenticacionAuth> autenticar(String codigo, String pin) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty || pin.isEmpty) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
		}
		final hub = _clienteHub;
		if (hub != null) {
			final salud = await hub.verificarSalud();
			if (salud) {
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
		final tenantId = await _configDispositivo.obtenerValor(CLAVE_CONFIG_TENANT_ID);
		if (tenantId == null || tenantId.isEmpty) {
			if (hub == null) {
				return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
			}
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoDisponible);
		}
		await PosiaLocalDatabase.obtenerInstancia().establecerTenant(tenantId);
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
		final usuario = await UsuarioRepository(baseDatos: base).autenticar(limpio, pin);
		if (usuario == null) {
			if (hub != null) {
				return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoDisponible);
			}
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
		}
		return IntentoAutenticacionAuth.exito(
			ResultadoAutenticacion(
				usuario: usuario.copiarCon(tenantId: tenantId),
				tenantId: tenantId,
			),
		);
	}

	Future<Usuario?> _buscarPerfilLocal(String codigo) async {
		final tenantId = await _configDispositivo.obtenerValor(CLAVE_CONFIG_TENANT_ID);
		if (tenantId == null || tenantId.isEmpty) {
			return null;
		}
		await PosiaLocalDatabase.obtenerInstancia().establecerTenant(tenantId);
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
		final usuario = await UsuarioRepository(baseDatos: base).obtenerPorCodigo(codigo);
		if (usuario == null) {
			return null;
		}
		if (!usuario.activo) {
			return null;
		}
		return usuario.copiarCon(tenantId: tenantId);
	}

	/// Persiste en SQLite local la cuenta recibida del hub.
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
			pinHash: resultado.pinHash!,
			pinSalt: resultado.pinSalt!,
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
			tenantId: perfil.tenantId,
		);
	}

	ResultadoAutenticacion _mapearLoginHub(RespuestaLoginHub login) {
		return ResultadoAutenticacion(
			usuario: _mapearPerfilHub(login.perfil),
			tenantId: login.perfil.tenantId,
			pinHash: login.pinHash,
			pinSalt: login.pinSalt,
			creadoEn: login.creadoEn,
			actualizadoEn: login.actualizadoEn,
		);
	}
}
