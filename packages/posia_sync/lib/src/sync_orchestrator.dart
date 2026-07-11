/// Orquestador de sincronizacion hub y LAN.
library;

import 'package:posia_core/posia_core.dart';

import 'almacen_cursor_sync.dart';
import 'aplicador_eventos_remotos.dart';
import 'hub_sync_client.dart';
import 'lan_sync_client.dart';
import 'local_event_queue.dart';
import 'progreso_sync.dart';

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
    this.alAplicarEventoRemoto,
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

  /// Invocado tras aplicar cada evento recibido del hub (ventas de otras cajas).
  Future<void> Function(SyncEvent evento)? alAplicarEventoRemoto;

  bool tieneHubConfigurado() => _clienteHub != null;

  Future<void> mantenerHubVivo() async {
    await _clienteHub?.mantenerHubVivo();
  }

  Future<void> registrarEvento(SyncEvent evento) async {
    await _colaLocal.encolar(evento);
  }

  Future<int> sincronizarPendientes({ReporteProgresoSync? alProgreso}) async {
    final pendientes = await _colaLocal.obtenerPendientes();
    if (pendientes.isEmpty) {
      return 0;
    }
    final total = pendientes.length;
    var enviados = 0;
    var fallosConsecutivos = 0;
    const maxFallosConsecutivos = 3;
    for (final evento in pendientes) {
      alProgreso?.call(
        ProgresoSync(
          fase: FaseProgresoSync.enviar,
          indice: enviados,
          total: total,
          mensaje: 'Enviando cambios (${enviados + 1} de $total)…',
        ),
      );
      final exito = await _transmitirEvento(evento);
      if (exito) {
        await _colaLocal.marcarEnviado(evento.id);
        enviados = enviados + 1;
        fallosConsecutivos = 0;
      } else {
        await _colaLocal.marcarError(evento.id);
        fallosConsecutivos = fallosConsecutivos + 1;
        // Hub caido o red lenta: no bloquear minutos/horas reintentando
        // cada evento con timeout individual.
        if (fallosConsecutivos >= maxFallosConsecutivos) {
          break;
        }
      }
    }
    alProgreso?.call(
      ProgresoSync(
        fase: FaseProgresoSync.enviar,
        indice: total,
        total: total,
        mensaje: 'Envío completado ($enviados de $total)',
      ),
    );
    return enviados;
  }

  Future<ResultadoSync> sincronizarCompleto({ReporteProgresoSync? alProgreso}) async {
    return _sincronizarInterno(reiniciarCursor: false, alProgreso: alProgreso);
  }

  Future<ResultadoSync> sincronizarDesdeOrigen({ReporteProgresoSync? alProgreso}) async {
    return _sincronizarInterno(reiniciarCursor: true, alProgreso: alProgreso);
  }

  Future<ResultadoSync> _sincronizarInterno({
    required bool reiniciarCursor,
    ReporteProgresoSync? alProgreso,
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
    // No abortar el ciclo si /health falla: tras offline el hub puede despertar
    // lento, pero POST/GET /v1/events aún pueden funcionar. Un return temprano
    // dejaba la cola local sin enviar mientras el pull de otra caja sí llegaba.
    final hubOk = await clienteHub.verificarSalud();
    alProgreso?.call(
      const ProgresoSync(
        fase: FaseProgresoSync.enviar,
        indice: 0,
        total: 0,
        mensaje: 'Conectando con la nube…',
      ),
    );
    final enviados = await sincronizarPendientes(alProgreso: alProgreso);
    final recibidos = await _ejecutarPull(clienteHub, alProgreso: alProgreso);
    alProgreso?.call(
      ProgresoSync(
        fase: FaseProgresoSync.listo,
        indice: enviados + recibidos,
        total: enviados + recibidos,
        mensaje: 'Sincronización completada',
      ),
    );
    return ResultadoSync(
      eventosEnviados: enviados,
      eventosRecibidos: recibidos,
      hubDisponible: hubOk || enviados > 0 || recibidos > 0,
    );
  }

  Future<int> _ejecutarPull(
    HubSyncClient clienteHub, {
    ReporteProgresoSync? alProgreso,
  }) async {
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
      for (final evento in resultado.eventos) {
        await aplicador.aplicarEvento(evento);
        await alAplicarEventoRemoto?.call(evento);
        aplicados = aplicados + 1;
        alProgreso?.call(
          ProgresoSync(
            fase: FaseProgresoSync.recibir,
            indice: aplicados,
            total: 0,
            mensaje: 'Recibiendo cambios ($aplicados eventos)…',
          ),
        );
      }
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
      // El hub exige storeId/deviceId no vacíos. Preferir los del evento (que
      // se fijaron al guardar localmente) por si el orquestador se construyó
      // antes de seleccionar tienda o con identidad incompleta.
      final tiendaId = evento.tiendaId.trim().isNotEmpty
          ? evento.tiendaId
          : _tiendaId;
      final dispositivoId = evento.dispositivoId.trim().isNotEmpty
          ? evento.dispositivoId
          : _dispositivoId;
      if (tiendaId.trim().isEmpty || dispositivoId.trim().isEmpty) {
        return false;
      }
      exitoHub = await clienteHub.enviarEventos(
        dispositivoId: dispositivoId,
        tiendaId: tiendaId,
        eventos: [evento],
      );
    }
    return exitoLan || exitoHub;
  }
}
