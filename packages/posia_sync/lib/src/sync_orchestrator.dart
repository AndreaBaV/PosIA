/// Orquestador de sincronizacion hub y LAN.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

import 'almacen_cursor_sync.dart';
import 'aplicador_eventos_remotos.dart';
import 'hub_sync_client.dart';
import 'lan_sync_client.dart';
import 'local_event_queue.dart';

/// Resultado de un ciclo completo de sincronizacion.
class ResultadoSync {
	/// Crea resultado de ciclo de sync.
	///
	/// [eventosEnviados] Eventos locales aceptados por el hub.
	/// [eventosRecibidos] Eventos remotos aplicados localmente.
	/// [hubDisponible] Indica si el hub respondio.
	const ResultadoSync({
		required this.eventosEnviados,
		required this.eventosRecibidos,
		required this.hubDisponible,
	});

	/// Eventos locales transmitidos con exito.
	final int eventosEnviados;

	/// Eventos remotos aplicados a la base local.
	final int eventosRecibidos;

	/// Bandera de disponibilidad del hub.
	final bool hubDisponible;
}

/// Coordina envio de cola local a LAN y hub central.
class SyncOrchestrator {
	/// Crea orquestador con dependencias de sync.
	///
	/// [colaLocal] Cola de eventos pendientes.
	/// [clienteHub] Cliente del hub central opcional.
	/// [clienteLan] Cliente LAN opcional para caja par.
	/// [aplicadorRemoto] Aplicador de eventos recibidos opcional.
	/// [almacenCursor] Persistencia del cursor de pull opcional.
	/// [tenantId] Identificador del tenant activo.
	/// [tiendaId] Tienda del dispositivo.
	/// [dispositivoId] Identificador unico de la caja.
	SyncOrchestrator({
		required LocalEventQueue colaLocal,
		required HubSyncClient? clienteHub,
		required LanSyncClient? clienteLan,
		AplicadorEventosRemotos? aplicadorRemoto,
		AlmacenCursorSync? almacenCursor,
		required String tenantId,
		required String tiendaId,
		required String dispositivoId,
	}) : _colaLocal = colaLocal,
	     _clienteHub = clienteHub,
	     _clienteLan = clienteLan,
	     _aplicadorRemoto = aplicadorRemoto,
	     _almacenCursor = almacenCursor,
	     _tenantId = tenantId,
	     _tiendaId = tiendaId,
	     _dispositivoId = dispositivoId;

	final LocalEventQueue _colaLocal;
	final HubSyncClient? _clienteHub;
	final LanSyncClient? _clienteLan;
	final AplicadorEventosRemotos? _aplicadorRemoto;
	final AlmacenCursorSync? _almacenCursor;
	final String _tenantId;
	final String _tiendaId;
	final String _dispositivoId;

	/// Indica si hay hub central configurado.
	///
	/// Retorna verdadero cuando existe cliente hub activo.
	bool tieneHubConfigurado() {
		return _clienteHub != null;
	}

	/// Ping de mantenimiento para hubs que se duermen (Render free).
	Future<void> mantenerHubVivo() async {
		await _clienteHub?.mantenerHubVivo();
	}

	/// Registra evento de dominio en cola local.
	///
	/// [evento] Evento generado por operacion de negocio.
	Future<void> registrarEvento(SyncEvent evento) async {
		await _colaLocal.encolar(evento);
	}

	/// Procesa cola pendiente enviando a LAN y hub.
	///
	/// Retorna cantidad de eventos enviados exitosamente.
	Future<int> sincronizarPendientes() async {
		final pendientes = await _colaLocal.obtenerPendientes();
		if (pendientes.isEmpty) {
			return 0;
		}

		var enviados = 0;
		for (final evento in pendientes) {
			final exito = await _transmitirEvento(evento);
			if (exito) {
				await _colaLocal.marcarEnviado(evento.id);
				enviados = enviados + 1;
			} else {
				await _colaLocal.marcarError(evento.id);
			}
		}
		return enviados;
	}

	/// Ejecuta ciclo completo: push de cola y pull incremental.
	///
	/// Retorna resultado con conteos de envio y recepcion.
	Future<ResultadoSync> sincronizarCompleto() async {
		return _sincronizarInterno(reiniciarCursor: false);
	}

	/// Reinicia cursor y descarga todos los eventos del hub (pull completo).
	Future<ResultadoSync> sincronizarDesdeOrigen() async {
		return _sincronizarInterno(reiniciarCursor: true);
	}

	Future<ResultadoSync> _sincronizarInterno({required bool reiniciarCursor}) async {
		final clienteHub = _clienteHub;
		if (clienteHub == null) {
			return const ResultadoSync(
				eventosEnviados: 0,
				eventosRecibidos: 0,
				hubDisponible: false,
			);
		}
		if (reiniciarCursor) {
			final almacenCursor = _almacenCursor;
			if (almacenCursor != null) {
				await almacenCursor.guardarCursorHub(0);
			}
		}
		final hubOk = await clienteHub.verificarSalud();
		if (!hubOk) {
			return const ResultadoSync(
				eventosEnviados: 0,
				eventosRecibidos: 0,
				hubDisponible: false,
			);
		}
		final enviados = await sincronizarPendientes();
		final recibidos = await _ejecutarPull(clienteHub);
		return ResultadoSync(
			eventosEnviados: enviados,
			eventosRecibidos: recibidos,
			hubDisponible: true,
		);
	}

	/// Descarga y aplica eventos remotos desde el cursor local.
	///
	/// [clienteHub] Cliente activo del hub.
	/// Retorna cantidad de eventos aplicados.
	Future<int> _ejecutarPull(HubSyncClient clienteHub) async {
		final aplicador = _aplicadorRemoto;
		final almacenCursor = _almacenCursor;
		if (aplicador == null || almacenCursor == null) {
			return 0;
		}
		var aplicados = 0;
		var cursor = await almacenCursor.leerCursorHub();
		var continuar = true;
		while (continuar) {
			final resultado = await clienteHub.obtenerEventos(
				tenantId: _tenantId,
				desdeSeq: cursor,
				excluirDispositivoId: _dispositivoId,
			);
			if (!resultado.exitoso || resultado.eventos.isEmpty) {
				continuar = false;
			} else {
				await aplicador.aplicarLote(resultado.eventos);
				aplicados = aplicados + resultado.eventos.length;
				cursor = resultado.ultimoSeq;
				await almacenCursor.guardarCursorHub(cursor);
			}
		}
		return aplicados;
	}

	/// Transmite un evento por LAN y hub segun disponibilidad.
	///
	/// [evento] Evento individual a transmitir.
	/// Retorna verdadero si al menos un canal acepto el envio.
	Future<bool> _transmitirEvento(SyncEvent evento) async {
		var exitoLan = false;
		var exitoHub = false;

		final clienteLan = _clienteLan;
		if (clienteLan != null) {
			exitoLan = await clienteLan.enviarEventos([evento]);
		}

		final clienteHub = _clienteHub;
		if (clienteHub != null) {
			exitoHub = await clienteHub.enviarEventos(
				tenantId: _tenantId,
				dispositivoId: _dispositivoId,
				tiendaId: _tiendaId,
				eventos: [evento],
			);
		}

		return exitoLan || exitoHub;
	}
}
