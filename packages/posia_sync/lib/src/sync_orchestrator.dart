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

  /// Empuja solo los ids indicados (p. ej. empaque recien guardado).
  ///
  /// Evita que la cola antigua (centenas de eventos en error) consuma los
  /// 3 reintentos/timeouts y deje el evento nuevo sin enviar a Neon.
  Future<ResultadoEnvioHub> sincronizarEventosPorIds(
    Iterable<String> ids,
  ) async {
    final idSet = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (idSet.isEmpty) {
      return const ResultadoEnvioHub(exitoso: false, error: 'sin ids');
    }
    final pendientes = await _colaLocal.obtenerPendientes();
    final alvo = pendientes.where((e) => idSet.contains(e.id)).toList();
    if (alvo.isEmpty) {
      return const ResultadoEnvioHub(
        exitoso: false,
        error: 'ids no pendientes (colapsados o ya enviados)',
      );
    }
    final tienda = alvo.first.tiendaId.trim().isNotEmpty
        ? alvo.first.tiendaId
        : _tiendaId;
    final dispositivo = alvo.first.dispositivoId.trim().isNotEmpty
        ? alvo.first.dispositivoId
        : _dispositivoId;
    if (tienda.trim().isEmpty || dispositivo.trim().isEmpty) {
      for (final evento in alvo) {
        await _colaLocal.marcarError(evento.id);
      }
      return const ResultadoEnvioHub(
        exitoso: false,
        error: 'tiendaId/dispositivoId vacio',
      );
    }
    final resultado = await _transmitirLoteConDetalle(
      alvo,
      tiendaId: tienda,
      dispositivoId: dispositivo,
    );
    if (resultado.exitoso) {
      for (final evento in alvo) {
        await _colaLocal.marcarEnviado(evento.id);
      }
    } else {
      for (final evento in alvo) {
        await _colaLocal.marcarError(evento.id);
      }
    }
    return resultado;
  }

  Future<int> sincronizarPendientes({ReporteProgresoSync? alProgreso}) async {
    final pendientes = await _colaLocal.obtenerPendientes();
    if (pendientes.isEmpty) {
      return 0;
    }
    final total = pendientes.length;
    var enviados = 0;
    var fallosConsecutivos = 0;
    var detener = false;
    const maxFallosConsecutivos = 3;
    // Acota el ciclo completo: un lote puede tardar hasta
    // TIMEOUT_HUB_ENVIO_EVENTOS_SEGUNDOS, y sin presupuesto varios lotes lentos
    // dejarian la UI en "Sincronizando…" durante mucho tiempo. Lo que no quepa
    // sigue en cola para el siguiente ciclo.
    final cronometro = Stopwatch()..start();
    const presupuesto = Duration(seconds: PRESUPUESTO_ENVIO_SYNC_SEGUNDOS);

    // Agrupar por identidad hub: un POST admite un solo storeId/deviceId.
    final porIdentidad = <String, List<SyncEvent>>{};
    for (final evento in pendientes) {
      final tienda = evento.tiendaId.trim().isNotEmpty
          ? evento.tiendaId
          : _tiendaId;
      final dispositivo = evento.dispositivoId.trim().isNotEmpty
          ? evento.dispositivoId
          : _dispositivoId;
      final clave = '$tienda|$dispositivo';
      porIdentidad.putIfAbsent(clave, () => []).add(evento);
    }

    for (final entrada in porIdentidad.entries) {
      final partes = entrada.key.split('|');
      final tiendaId = partes[0];
      final dispositivoId = partes.length > 1 ? partes[1] : '';
      if (tiendaId.trim().isEmpty || dispositivoId.trim().isEmpty) {
        for (final evento in entrada.value) {
          await _colaLocal.marcarError(evento.id);
        }
        fallosConsecutivos = fallosConsecutivos + 1;
        if (fallosConsecutivos >= maxFallosConsecutivos) {
          detener = true;
          break;
        }
        continue;
      }
      final eventosGrupo = entrada.value;
      for (var i = 0; i < eventosGrupo.length; i += TAMANO_LOTE_SYNC_HUB) {
        final fin = i + TAMANO_LOTE_SYNC_HUB > eventosGrupo.length
            ? eventosGrupo.length
            : i + TAMANO_LOTE_SYNC_HUB;
        final lote = eventosGrupo.sublist(i, fin);
        if (cronometro.elapsed >= presupuesto) {
          detener = true;
          break;
        }
        alProgreso?.call(
          ProgresoSync(
            fase: FaseProgresoSync.enviar,
            indice: enviados,
            total: total,
            mensaje:
                'Enviando cambios (${enviados + 1}–${enviados + lote.length} de $total)…',
          ),
        );
        final exito = await _transmitirLote(
          lote,
          tiendaId: tiendaId,
          dispositivoId: dispositivoId,
        );
        if (exito) {
          for (final evento in lote) {
            await _colaLocal.marcarEnviado(evento.id);
          }
          enviados = enviados + lote.length;
          fallosConsecutivos = 0;
        } else {
          for (final evento in lote) {
            await _colaLocal.marcarError(evento.id);
          }
          fallosConsecutivos = fallosConsecutivos + 1;
          if (fallosConsecutivos >= maxFallosConsecutivos) {
            detener = true;
            break;
          }
        }
      }
      if (detener) {
        break;
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

  /// Ciclo en vuelo, si lo hay. Ver [_sincronizarInterno].
  Future<ResultadoSync>? _cicloEnCurso;

  /// Serializa los ciclos de sync de este dispositivo.
  ///
  /// Hay varios disparadores (temporizador de 60 s, boton "Sincronizar ahora",
  /// login, corte de caja, reconciliacion) y cada uno tenia su propio candado o
  /// ninguno, asi que podian solaparse y multiplicar los POST contra un hub que
  /// ya venia lento. Quien llega mientras hay un ciclo en curso se engancha a
  /// ese mismo resultado en vez de abrir otro.
  Future<ResultadoSync> _sincronizarInterno({
    required bool reiniciarCursor,
    ReporteProgresoSync? alProgreso,
  }) {
    final enCurso = _cicloEnCurso;
    if (enCurso != null) {
      return enCurso;
    }
    final ciclo = _ejecutarCiclo(
      reiniciarCursor: reiniciarCursor,
      alProgreso: alProgreso,
    );
    _cicloEnCurso = ciclo;
    return ciclo.whenComplete(() => _cicloEnCurso = null);
  }

  Future<ResultadoSync> _ejecutarCiclo({
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
    // lento, pero POST/GET /v1/events aún pueden funcionar.
    final hubOk = await clienteHub.verificarSalud();
    // Empujar primero los cambios locales (incl. empaques/presentaciones).
    // Antes se descartaba todo el catálogo pendiente y luego el pull desde Neon
    // sobrescribía SQLite: los bultos nuevos nunca llegaban a la nube y se
    // perdían al reconstruir desde origen.
    alProgreso?.call(
      const ProgresoSync(
        fase: FaseProgresoSync.preparar,
        indice: 0,
        total: 0,
        mensaje: 'Colapsando catálogo duplicado en cola…',
      ),
    );
    await _colaLocal.colapsarDuplicadosCatalogo();
    alProgreso?.call(
      const ProgresoSync(
        fase: FaseProgresoSync.enviar,
        indice: 0,
        total: 0,
        mensaje: 'Enviando cambios locales a la nube…',
      ),
    );
    final enviados = await sincronizarPendientes(alProgreso: alProgreso);
    alProgreso?.call(
      const ProgresoSync(
        fase: FaseProgresoSync.recibir,
        indice: 0,
        total: 0,
        mensaje: 'Descargando cambios desde la nube…',
      ),
    );
    final recibidos = await _ejecutarPull(
      clienteHub,
      // En una reconstrucción desde origen (cursor a 0) la base local se
      // rehidrata por completo, así que hay que traer también los eventos que
      // este dispositivo originó: si se excluyen, su propio catálogo (p. ej.
      // los nombres de categoría) nunca vuelve y quedan stubs "Categoría".
      incluirEventosPropios: reiniciarCursor,
      alProgreso: alProgreso,
    );
    // Corrige localmente duplicados/placeholders que este dispositivo ya
    // tenía guardados (no solo los que un evento nuevo "choca" al llegar).
    // Corre en cada sync completo, haya o no eventos nuevos: así cualquier
    // dispositivo converge solo, sin reinstalar ni borrar datos a mano.
    await _aplicadorRemoto?.autoSanarCatalogoLocal();
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
    bool incluirEventosPropios = false,
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
        excluirDispositivoId: incluirEventosPropios ? null : _dispositivoId,
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

  Future<bool> _transmitirLote(
    List<SyncEvent> eventos, {
    required String tiendaId,
    required String dispositivoId,
  }) async {
    final r = await _transmitirLoteConDetalle(
      eventos,
      tiendaId: tiendaId,
      dispositivoId: dispositivoId,
    );
    return r.exitoso;
  }

  Future<ResultadoEnvioHub> _transmitirLoteConDetalle(
    List<SyncEvent> eventos, {
    required String tiendaId,
    required String dispositivoId,
  }) async {
    if (eventos.isEmpty) {
      return const ResultadoEnvioHub(exitoso: true);
    }
    var exitoLan = false;
    final clienteLan = _clienteLan;
    if (clienteLan != null) {
      exitoLan = await clienteLan.enviarEventos(eventos);
    }
    final clienteHub = _clienteHub;
    if (clienteHub == null) {
      return ResultadoEnvioHub(
        exitoso: exitoLan,
        error: exitoLan ? null : 'sin hub ni lan',
      );
    }
    final hub = await clienteHub.enviarEventosConDetalle(
      dispositivoId: dispositivoId,
      tiendaId: tiendaId,
      eventos: eventos,
    );
    if (exitoLan || hub.exitoso) {
      return ResultadoEnvioHub(
        exitoso: true,
        statusCode: hub.statusCode,
        aceptados: hub.aceptados,
        esperados: hub.esperados,
        error: hub.exitoso ? null : 'lan ok; hub: ${hub.error}',
      );
    }
    return hub;
  }
}
