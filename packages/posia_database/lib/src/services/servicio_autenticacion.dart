/// Autenticacion contra el hub con respaldo local offline.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

import '../database/posia_local_database.dart';
import '../models/motivo_fallo_auth.dart';
import '../models/resultado_autenticacion.dart';
import '../repositories/usuario_repository.dart';

/// Valida credenciales contra el hub (fuente de verdad) con respaldo local offline.
///
/// Reglas clave:
/// - Solo se reporta "usuarioNoEncontrado" o "credencialesInvalidas" cuando el
///   hub da una respuesta HTTP definitiva (200/401/404). Cualquier error
///   transitorio (red, timeout, 5xx) o de configuracion (clave API mal, 503)
///   se traduce a un motivo especifico para no ocultar el problema real bajo
///   "usuario no encontrado" en dispositivos recien instalados.
class ServicioAutenticacion {
	ServicioAutenticacion({
		HubSyncClient? clienteHub,
	}) : _clienteHub = clienteHub;

	final HubSyncClient? _clienteHub;

	Future<BusquedaPerfilAuth> buscarPerfilPorCodigo(String codigo) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		final errorFormato = ValidadorCodigoUsuario.validar(limpio);
		if (errorFormato != null || limpio.isEmpty) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioNoEncontrado);
		}
		final hub = _clienteHub;
		ConsultaPerfilHub? consultaHub;
		if (hub != null) {
			// Un ping al health despierta al hub si estaba suspendido por
			// inactividad antes de disparar auth/preview; el resultado NO se
			// usa como gate porque verificarEstadoAuth ya cubre 401/503.
			await hub.mantenerHubVivo();
			consultaHub = await _consultarPerfilConReintento(hub, limpio);
			if (consultaHub.exitoso) {
				final perfilHub = consultaHub.perfil!;
				if (!perfilHub.activo) {
					return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.usuarioInactivo);
				}
				return BusquedaPerfilAuth.usuario(_mapearPerfilHub(perfilHub));
			}
		}
		// Antes de reportar error, prueba la copia local sincronizada.
		final local = await _buscarPerfilLocal(limpio);
		if (local != null) {
			return BusquedaPerfilAuth.usuario(local);
		}
		if (hub == null) {
			return const BusquedaPerfilAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
		}
		// El hub respondio: interpretar el motivo real.
		final motivo = _mapearErrorConsulta(consultaHub!);
		return BusquedaPerfilAuth.fallo(
			motivo,
			detalleTecnico: _detalleSiHubInalcanzable(
				motivo,
				consultaHub.detalle,
				hub.urlBase,
			),
		);
	}

	Future<IntentoAutenticacionAuth> autenticar(String codigo, String pin) async {
		final limpio = ValidadorCodigoUsuario.normalizar(codigo);
		if (limpio.isEmpty || pin.isEmpty) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.credencialesInvalidas);
		}
		final hub = _clienteHub;
		IntentoLoginHub? intentoHub;
		if (hub != null) {
			await hub.mantenerHubVivo();
			intentoHub = await _intentarLoginConReintento(hub, limpio, pin);
			if (intentoHub.exitoso) {
				final login = intentoHub.login!;
				if (!login.perfil.activo) {
					return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.usuarioInactivo);
				}
				return IntentoAutenticacionAuth.exito(_mapearLoginHub(login));
			}
			if (intentoHub.credencialesInvalidas) {
				// Antes de rechazar duro, chequea si tenemos copia local:
				// puede que la clave local siga vigente aunque el hub la haya
				// rotado. Solo se acepta si valida contra la copia sincronizada.
				final local = await _autenticarLocal(limpio, pin);
				if (local != null) {
					return IntentoAutenticacionAuth.exito(local);
				}
				return const IntentoAutenticacionAuth.fallo(
					MotivoFalloAuth.credencialesInvalidas,
				);
			}
		}
		final local = await _autenticarLocal(limpio, pin);
		if (local != null) {
			return IntentoAutenticacionAuth.exito(local);
		}
		if (hub == null) {
			return const IntentoAutenticacionAuth.fallo(MotivoFalloAuth.hubNoConfigurado);
		}
		final motivo = _mapearErrorLogin(intentoHub!);
		return IntentoAutenticacionAuth.fallo(
			motivo,
			detalleTecnico: _detalleSiHubInalcanzable(
				motivo,
				intentoHub.detalle,
				hub.urlBase,
			),
		);
	}

	static const _reintentosHubTransitorio = 2;
	static const _esperaEntreReintentos = Duration(seconds: 2);

	Future<ConsultaPerfilHub> _consultarPerfilConReintento(
		HubSyncClient hub,
		String codigo,
	) async {
		var ultima = await hub.consultarPerfil(codigo);
		for (var intento = 1; intento <= _reintentosHubTransitorio; intento++) {
			if (ultima.esRespuestaDefinitiva ||
				ultima.estado != EstadoAuthHub.inalcanzable) {
				break;
			}
			await Future<void>.delayed(_esperaEntreReintentos);
			ultima = await hub.consultarPerfil(codigo);
		}
		return ultima;
	}

	Future<IntentoLoginHub> _intentarLoginConReintento(
		HubSyncClient hub,
		String codigo,
		String pin,
	) async {
		var ultima = await hub.intentarLogin(codigo: codigo, pin: pin);
		for (var intento = 1; intento <= _reintentosHubTransitorio; intento++) {
			if (ultima.esRespuestaDefinitiva ||
				ultima.estado != EstadoAuthHub.inalcanzable) {
				break;
			}
			await Future<void>.delayed(_esperaEntreReintentos);
			ultima = await hub.intentarLogin(codigo: codigo, pin: pin);
		}
		return ultima;
	}

	MotivoFalloAuth _mapearErrorConsulta(ConsultaPerfilHub consulta) {
		if (consulta.definitivoNoEncontrado) {
			return MotivoFalloAuth.usuarioNoEncontrado;
		}
		switch (consulta.estado) {
			case EstadoAuthHub.sinPostgres:
				return MotivoFalloAuth.hubSinPostgres;
			case EstadoAuthHub.apiKeyInvalida:
				return MotivoFalloAuth.hubApiKeyInvalida;
			case EstadoAuthHub.inalcanzable:
			case EstadoAuthHub.disponible:
			case null:
				return MotivoFalloAuth.hubNoDisponible;
		}
	}

	MotivoFalloAuth _mapearErrorLogin(IntentoLoginHub intento) {
		if (intento.credencialesInvalidas) {
			return MotivoFalloAuth.credencialesInvalidas;
		}
		switch (intento.estado) {
			case EstadoAuthHub.sinPostgres:
				return MotivoFalloAuth.hubSinPostgres;
			case EstadoAuthHub.apiKeyInvalida:
				return MotivoFalloAuth.hubApiKeyInvalida;
			case EstadoAuthHub.inalcanzable:
			case EstadoAuthHub.disponible:
			case null:
				return MotivoFalloAuth.hubNoDisponible;
		}
	}

	String? _detalleSiHubInalcanzable(
		MotivoFalloAuth motivo,
		String? detalle,
		String urlBase,
	) {
		if (motivo != MotivoFalloAuth.hubNoDisponible) {
			return null;
		}
		final resumen = resumirErrorConexionHub(detalle, urlBase: urlBase);
		return resumen.trim().isEmpty ? null : resumen;
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
						latitud: t.latitud,
						longitud: t.longitud,
						radioMetrosAsistencia: t.radioMetrosAsistencia,
					),
				)
				.toList(),
		);
	}
}
