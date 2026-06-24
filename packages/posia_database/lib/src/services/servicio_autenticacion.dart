/// Autenticacion multi-tenant: resuelve tenant al iniciar sesion.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

import '../database/posia_local_database.dart';
import '../models/motivo_fallo_auth.dart';
import '../models/resultado_autenticacion.dart';
import '../repositories/config_repository.dart';
import '../repositories/usuario_repository.dart';

/// Valida credenciales contra el hub (fuente de verdad) con respaldo local offline.
class ServicioAutenticacion {
	ServicioAutenticacion({
		required ConfigRepository configDispositivo,
		HubSyncClient? clienteHub,
		SyncOrchestrator? orquestadorSync,
	}) : _configDispositivo = configDispositivo,
	     _clienteHub = clienteHub,
	     _orquestadorSync = orquestadorSync;

	final ConfigRepository _configDispositivo;
	final HubSyncClient? _clienteHub;
	final SyncOrchestrator? _orquestadorSync;

	/// Busca perfil publico por codigo (sin validar PIN).
	///
	/// Sincroniza con el hub antes de consultar para que cuentas creadas en
	/// este u otro dispositivo esten actualizadas.
	Future<BusquedaPerfilAuth> buscarPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		final errorFormato = ValidadorCodigoUsuario.validar(limpio);
		if (errorFormato != null) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		if (limpio.isEmpty) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		await _sincronizarConHubSiPosible();
		final tenantId = await _tenantIdConfigurado();
		final hub = _clienteHub;
		if (hub != null) {
			final salud = await hub.verificarSalud();
			if (salud) {
				final perfil = await hub.obtenerPerfilUsuario(
					limpio,
					tenantId: tenantId,
				);
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
			final tenant = await _tenantIdConfigurado();
			if (tenant == null || tenant.isEmpty) {
				return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
			}
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoDisponible);
	}

	/// Autentica y devuelve el tenant al que pertenece la cuenta.
	Future<IntentoAutenticacionAuth> autenticar(String codigo, String pin) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty || pin.isEmpty) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
		}
		await _sincronizarConHubSiPosible();
		final tenantId = await _tenantIdConfigurado();
		final hub = _clienteHub;
		if (hub != null) {
			final salud = await hub.verificarSalud();
			if (salud) {
				final remoto = await hub.iniciarSesion(
					codigo: limpio,
					pin: pin,
					tenantId: tenantId,
				);
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
		if (tenantId != null && tenantId.isNotEmpty) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
		}
		return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoDisponible);
	}

	Future<void> _sincronizarConHubSiPosible() async {
		final orquestador = _orquestadorSync;
		if (orquestador == null || !orquestador.tieneHubConfigurado()) {
			return;
		}
		try {
			await orquestador.sincronizarCompleto();
		} on Object {
			// El login puede continuar con copia local si el hub falla.
		}
	}

	Future<String?> _tenantIdConfigurado() async {
		return _configDispositivo.obtenerValor(claveConfigTenantId);
	}

	Future<ResultadoAutenticacion?> _autenticarLocal(String codigo, String pin) async {
		final tenantId = await _tenantIdConfigurado();
		if (tenantId == null || tenantId.isEmpty) {
			return null;
		}
		await PosiaLocalDatabase.obtenerInstancia().establecerTenant(tenantId);
		final base = await PosiaLocalDatabase.obtenerInstancia().obtenerBaseDatos();
		final usuario = await UsuarioRepository(baseDatos: base).autenticar(codigo, pin);
		if (usuario == null) {
			return null;
		}
		return ResultadoAutenticacion(
			usuario: usuario.copiarCon(tenantId: tenantId),
			tenantId: tenantId,
		);
	}

	Future<Usuario?> _buscarPerfilLocal(String codigo) async {
		final tenantId = await _tenantIdConfigurado();
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
