/// Orquestador de sincronizacion hub y LAN.
library;

import 'package:posia_core/posia_core.dart';

import 'almacen_cursor_sync.dart';
import 'aplicador_eventos_remotos.dart';
import 'hub_sync_client.dart';
import 'lan_sync_client.dart';
import 'local_event_queue.dart';

class ResultadoSync {
  const ResultadoSync({
    required this.eventosEnviados,
    required this.eventosRecibidos,
    required this.hubDisponible,
  });

  final int eventosEnviados;
  final int eventosRecibidos;
  final bool hubDisponible;
}

class SyncOrchestrator {
  SyncOrchestrator({
    required LocalEventQueue colaLocal,
    required HubSyncClient? clienteHub,
    required LanSyncClient? clienteLan,
    AplicadorEventosRemotos? aplicadorRemoto,
    AlmacenCursorSync? almacenCursor,
    required String tiendaId,
    required String dispositivoId,
  }) : _colaLocal = colaLocal,
       _clienteHub = clienteHub,
       _clienteLan = clienteLan,
       _aplicadorRemoto = aplicadorRemoto,
       _almacenCursor = almacenCursor,
       _tiendaId = tiendaId,
       _dispositivoId = dispositivoId;

  final LocalEventQueue _colaLocal;
  final HubSyncClient? _clienteHub;
  final LanSyncClient? _clienteLan;
  final AplicadorEventosRemotos? _aplicadorRemoto;
  final AlmacenCursorSync? _almacenCursor;
  final String _tiendaId;
  final String _dispositivoId;

  bool tieneHubConfigurado() => _clienteHub != null;

  Future<void> mantenerHubVivo() async {
    await _clienteHub?.mantenerHubVivo();
  }

  Future<void> registrarEvento(SyncEvent evento) async {
    await _colaLocal.encolar(evento);
  }

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

  Future<ResultadoSync> sincronizarCompleto() async {
    return _sincronizarInterno(reiniciarCursor: false);
  }

  Future<ResultadoSync> sincronizarDesdeOrigen() async {
    return _sincronizarInterno(reiniciarCursor: true);
  }

  Future<ResultadoSync> _sincronizarInterno({
    required bool reiniciarCursor,
  }) async {
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
        desdeSeq: cursor,
        excluirDispositivoId: _dispositivoId,
      );
      if (!resultado.exitoso || resultado.eventos.isEmpty) {
        continuar = false;
        continue;
      }
      await aplicador.aplicarLote(resultado.eventos);
      aplicados = aplicados + resultado.eventos.length;
      // Guarda de seguridad: si el cursor no avanza, detener el pull para no
      // repetir la misma pagina indefinidamente (evita bloquear la BD y la UI).
      if (resultado.ultimoSeq <= cursor) {
        continuar = false;
        continue;
      }
      cursor = resultado.ultimoSeq;
      await almacenCursor.guardarCursorHub(cursor);
      // Cede el hilo entre paginas para que las lecturas de la UI (Admin,
      // caja) se intercalen y no perciban un spinner interminable.
      await Future<void>.delayed(Duration.zero);
    }
    return aplicados;
  }

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
        dispositivoId: _dispositivoId,
        tiendaId: _tiendaId,
        eventos: [evento],
      );
    }
    return exitoLan || exitoHub;
  }
}
