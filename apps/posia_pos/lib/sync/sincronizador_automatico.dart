/// Sincronizacion automatica por conectividad y temporizador.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 16:00:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 16:00:00 (UTC-6)
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

/// Dispara sync al recuperar conexion y en ciclo periodico.
class SincronizadorAutomatico {
	/// Crea sincronizador sobre el orquestador de la caja.
	///
	/// [orquestador] Orquestador de sincronizacion activo.
	SincronizadorAutomatico({required SyncOrchestrator orquestador})
		: _orquestador = orquestador;

	final SyncOrchestrator _orquestador;
	StreamSubscription<List<ConnectivityResult>>? _suscripcionConectividad;
	Timer? _temporizador;
	bool _sincronizando = false;

	/// Inicia escucha de conectividad y ciclo periodico.
	///
	/// Ejecuta un primer intento inmediato de sincronizacion.
	void iniciar() {
		if (!_orquestador.tieneHubConfigurado()) {
			return;
		}
		_suscripcionConectividad = Connectivity()
			.onConnectivityChanged
			.listen(_alCambiarConectividad);
		_temporizador = Timer.periodic(
			const Duration(seconds: INTERVALO_SYNC_PERIODICO_SEGUNDOS),
			(_) => _intentarSincronizar(),
		);
		unawaited(_intentarSincronizar());
	}

	/// Detiene escucha y temporizador.
	void detener() {
		unawaited(_suscripcionConectividad?.cancel());
		_temporizador?.cancel();
		_suscripcionConectividad = null;
		_temporizador = null;
	}

	/// Reacciona a cambios de conectividad del dispositivo.
	///
	/// [resultados] Interfaces de red activas reportadas.
	void _alCambiarConectividad(List<ConnectivityResult> resultados) {
		final hayConexion = resultados.any(
			(resultado) => resultado != ConnectivityResult.none,
		);
		if (hayConexion) {
			unawaited(_intentarSincronizar());
		}
	}

	/// Ejecuta ciclo de sync evitando ejecuciones simultaneas.
	Future<void> _intentarSincronizar() async {
		if (_sincronizando) {
			return;
		}
		_sincronizando = true;
		try {
			await _orquestador.sincronizarCompleto();
		} finally {
			_sincronizando = false;
		}
	}
}
