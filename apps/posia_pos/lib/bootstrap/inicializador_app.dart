/// Inicializacion de servicios locales offline de POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

/// Prepara motor SQLite y datos iniciales antes de mostrar caja.
class InicializadorApp {
	InicializadorApp._();

	static bool _preparado = false;

	/// Ejecuta inicializacion idempotente de base de datos.
	static Future<void> preparar() async {
		if (_preparado) {
			return;
		}
		await ConfiguracionEntorno.cargar();
		await PosiaLocalDatabase.inicializarMotor();
		final gestor = PosiaLocalDatabase.obtenerInstancia();
		final base = await gestor.obtenerBaseDatosDispositivo();
		final config = ConfigRepository(baseDatos: base);
		await AprovisionadorDispositivo.asegurar(config);
		await _limpiarSesionSiDatosInconsistentes(config);
		_preparado = true;
	}

	/// Quita sesion persistida si el usuario ya no existe en SQLite local.
	static Future<void> _limpiarSesionSiDatosInconsistentes(
		ConfigRepository config,
	) async {
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
		}
	}
}
