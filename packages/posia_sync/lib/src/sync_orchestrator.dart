/// Orquestador de sincronizacion hub y LAN.
library;

import 'package:posia_core/posia_core.dart';

import 'almacen_cursor_sync.dart';
import 'aplicador_eventos_remotos.dart';
import 'diagnostico_sync.dart';
import 'hub_sync_client.dart';
import 'lan_sync_client.dart';
import 'local_event_queue.dart';
import 'progreso_sync.dart';

class ResultadoSync {
  const ResultadoSync({
    required this.eventosEnviados,
    required this.eventosRecibidos,
    required this.hubDisponible,
    this.eventosFallidos = 0,
    this.eventosRecuperados = 0,
  });

  final int eventosEnviados;
  final int eventosRecibidos;
  final bool hubDisponible;

  /// Eventos que no se pudieron aplicar y quedaron en cuarentena.
  final int eventosFallidos;

  /// Eventos que estaban en cuarentena y se aplicaron en este ciclo.
  final int eventosRecuperados;
}

class SyncOrchestrator {
  SyncOrchestrator({
    required LocalEventQueue colaLocal,
    required HubSyncClient? clienteHub,
    required LanSyncClient? clienteLan,
    AplicadorEventosRemotos? aplicadorRemoto,
    AlmacenCursorSync? almacenCursor,
    DiagnosticoSync? diagnostico,
    Future<int> Function()? contarCatalogoActivo,
    required String tiendaId,
    required String dispositivoId,
    this.alAplicarEventoRemoto,
  }) : _colaLocal = colaLocal,
       _clienteHub = clienteHub,
       _clienteLan = clienteLan,
       _aplicadorRemoto = aplicadorRemoto,
       _almacenCursor = almacenCursor,
       _diagnostico = diagnostico,
       _contarCatalogoActivo = contarCatalogoActivo,
       _tiendaId = tiendaId,
       _dispositivoId = dispositivoId;

  /// Eventos aplicados entre dos escrituras del cursor.
  ///
  /// Persistir en cada evento multiplicaria las escrituras de una reconstruccion
  /// completa (decenas de miles de eventos). Reaplicar como mucho este puñado
  /// tras un cierre abrupto es inocuo: los upserts son idempotentes y los
  /// eventos transaccionales llevan su propia tabla de deduplicacion.
  static const int _eventosPorConfirmacionCursor = 25;

  final LocalEventQueue _colaLocal;
  final HubSyncClient? _clienteHub;
  final LanSyncClient? _clienteLan;
  final AplicadorEventosRemotos? _aplicadorRemoto;
  final AlmacenCursorSync? _almacenCursor;
  final DiagnosticoSync? _diagnostico;
  final Future<int> Function()? _contarCatalogoActivo;
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

  /// Solo descarga eventos nuevos del hub (sin empujar cola ni auditar catalogo).
  ///
  /// Pensado para asistencia: el PIN generado en otro equipo debe llegar en
  /// segundos, no esperar el ciclo completo (puede tardar minutos con cola
  /// grande o auditoria de catalogo).
  Future<int> traerCambiosRapido() async {
    final clienteHub = _clienteHub;
    if (clienteHub == null) {
      return 0;
    }
    try {
      final resultado = await _ejecutarPull(
        clienteHub,
        incluirEventosPropios: false,
      );
      return resultado.aplicados;
    } on Object {
      return 0;
    }
  }

  /// Baja el desafio PIN activo de [tiendaId] sin recorrer el log de sync.
  ///
  /// Un celular atrasado miles de eventos no puede esperar el pull completo
  /// solo para marcar entrada; esta ruta lee el espejo del hub y aplica un
  /// evento sintetico local. Retorna true si habia desafio y se guardo.
  Future<bool> traerDesafioAsistenciaActivo({String? tiendaId}) async {
    final clienteHub = _clienteHub;
    final aplicador = _aplicadorRemoto;
    if (clienteHub == null || aplicador == null) {
      return false;
    }
    final tienda = (tiendaId ?? _tiendaId).trim();
    if (tienda.isEmpty) {
      return false;
    }
    try {
      final challenge = await clienteHub.obtenerDesafioAsistenciaActivo(tienda);
      if (challenge == null) {
        return false;
      }
      final id = challenge['id'] as String? ?? '';
      final pinHash = challenge['pinHash'] as String? ?? '';
      if (id.isEmpty || pinHash.isEmpty) {
        return false;
      }
      final evento = SyncEvent(
        id: 'attendanceChallengeCreated:$id',
        tiendaId: tienda,
        dispositivoId: challenge['creadoPor'] as String? ?? 'hub',
        tipo: TipoSyncEvento.attendanceChallengeCreated,
        payload: challenge,
        creadoEn: DateTime.now().toUtc(),
        estado: EstadoSyncEvento.enviado,
      );
      await aplicador.aplicarEvento(evento);
      return true;
    } on Object {
      return false;
    }
  }

  /// Encola y empuja de inmediato el mismo evento (sin reconsultar la cola).
  ///
  /// Evita la carrera lectura/escritura de la cola dual donde un
  /// [sincronizarEventosPorIds] justo despues de [registrarEvento] no veia
  /// el pendiente y la asistencia nunca subia al hub.
  Future<ResultadoEnvioHub> registrarYEmpujar(SyncEvent evento) async {
    await _colaLocal.encolar(evento);
    final tienda = evento.tiendaId.trim().isNotEmpty ? evento.tiendaId : _tiendaId;
    final dispositivo = evento.dispositivoId.trim().isNotEmpty
        ? evento.dispositivoId
        : _dispositivoId;
    if (tienda.trim().isEmpty || dispositivo.trim().isEmpty) {
      await _colaLocal.marcarError(evento.id);
      return const ResultadoEnvioHub(
        exitoso: false,
        error: 'tiendaId/dispositivoId vacio',
      );
    }
    if (!tieneHubConfigurado() && _clienteLan == null) {
      return const ResultadoEnvioHub(exitoso: false, error: 'sin hub');
    }
    final resultado = await _transmitirLoteConDetalle(
      [evento],
      tiendaId: tienda,
      dispositivoId: dispositivo,
    );
    if (resultado.exitoso) {
      await _colaLocal.marcarEnviado(evento.id);
    } else {
      await _colaLocal.marcarError(evento.id);
    }
    return resultado;
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
  /// ya venia lento. Quien llega pidiendo un ciclo incremental mientras hay
  /// otro en curso se engancha a ese mismo resultado en vez de abrir otro.
  ///
  /// La reconstruccion desde origen NO se engancha: encadena su propio ciclo al
  /// final del que este corriendo. Enganchada devolvia el resultado de un pull
  /// incremental sin haber reiniciado el cursor, asi que una base ya vaciada
  /// (reconciliacion, limpieza de cache) se quedaba sin catalogo ni historial
  /// hasta que el usuario reinstalaba o volvia a descargar a mano.
  Future<ResultadoSync> _sincronizarInterno({
    required bool reiniciarCursor,
    ReporteProgresoSync? alProgreso,
  }) {
    final enCurso = _cicloEnCurso;
    if (enCurso != null && !reiniciarCursor) {
      return enCurso;
    }
    final ciclo = enCurso == null
        ? _ejecutarCiclo(reiniciarCursor: reiniciarCursor, alProgreso: alProgreso)
        : enCurso.then(
            (_) => _ejecutarCiclo(
              reiniciarCursor: reiniciarCursor,
              alProgreso: alProgreso,
            ),
            onError: (_) => _ejecutarCiclo(
              reiniciarCursor: reiniciarCursor,
              alProgreso: alProgreso,
            ),
          );
    _cicloEnCurso = ciclo;
    return ciclo.whenComplete(() {
      if (_cicloEnCurso == ciclo) {
        _cicloEnCurso = null;
      }
    });
  }

  /// Ejecuta el ciclo dejando rastro de su resultado en el diagnostico.
  ///
  /// Los disparadores automaticos se tragan la excepcion para no molestar al
  /// cajero, asi que sin este registro un ciclo que fallaba siempre era
  /// invisible: la app se veia normal mientras dejaba de recibir datos.
  Future<ResultadoSync> _ejecutarCiclo({
    required bool reiniciarCursor,
    ReporteProgresoSync? alProgreso,
  }) async {
    try {
      final resultado = await _ejecutarCicloInterno(
        reiniciarCursor: reiniciarCursor,
        alProgreso: alProgreso,
      );
      await _registrarErrorCiclo(null);
      return resultado;
    } on Object catch (error) {
      await _registrarErrorCiclo(error);
      rethrow;
    }
  }

  Future<void> _registrarErrorCiclo(Object? error) async {
    try {
      await _diagnostico?.registrarErrorCiclo(error);
    } on Object {
      // El diagnostico es best-effort: nunca debe tumbar el ciclo de sync.
    }
  }

  Future<ResultadoSync> _ejecutarCicloInterno({
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
    var desdeOrigen = reiniciarCursor;
    if (!desdeOrigen && await _catalogoVacioConCursorAvanzado()) {
      desdeOrigen = true;
      alProgreso?.call(
        const ProgresoSync(
          fase: FaseProgresoSync.preparar,
          indice: 0,
          total: 0,
          mensaje: 'Catálogo local vacío: reconstruyendo desde la nube…',
        ),
      );
    }
    // Auditoria de catalogo: a diferencia del chequeo anterior (catalogo en
    // CERO), aqui el catalogo local tiene filas pero puede faltarle un
    // subconjunto -exactamente lo que dejaba pasar el bug de indice unico
    // que se resolvia en silencio con ConflictAlgorithm.ignore. Un pull
    // incremental normal nunca lo repara porque el cursor ya esta al dia; se
    // necesita comparar conteo + huella de contenido contra el hub y, si
    // difieren, repararlo.
    final huellaHub = await _obtenerHuellaHubSiToca(clienteHub);
    if (!desdeOrigen && huellaHub != null) {
      final huellaLocal = await _aplicadorRemoto?.calcularHuellaCatalogoLocal();
      if (huellaLocal != null && !huellaLocal.coincideCon(huellaHub)) {
        alProgreso?.call(
          const ProgresoSync(
            fase: FaseProgresoSync.preparar,
            indice: 0,
            total: 0,
            mensaje: 'Catálogo desalineado con la nube: reparando…',
          ),
        );
        // Reparacion rapida primero: aplica solo los eventos que definen el
        // catalogo (deduplicados al mas reciente por entidad), sin repetir
        // años de ventas/compras/traspasos que el catalogo no necesita. Si el
        // hub desplegado aun no expone la ruta (503/red), cae a la
        // reconstruccion completa desde origen como red de seguridad: mas
        // lenta, pero siempre disponible.
        final reparado = await _repararCatalogoRapido(clienteHub);
        if (!reparado) {
          desdeOrigen = true;
          alProgreso?.call(
            const ProgresoSync(
              fase: FaseProgresoSync.preparar,
              indice: 0,
              total: 0,
              mensaje: 'Reparación rápida no disponible: reconstruyendo desde la nube…',
            ),
          );
        }
      }
    }
    if (desdeOrigen) {
      final almacenCursor = _almacenCursor;
      if (almacenCursor != null) {
        await almacenCursor.guardarCursorHub(0);
      }
    }
    // No abortar el ciclo si /health falla: tras offline el hub puede despertar
    // lento, pero POST/GET /v1/events aún pueden funcionar.
    final hubOk = await clienteHub.verificarSalud();
    // Reintentar lo apartado antes del pull: si la causa era transitoria (una
    // fila padre que ya llego, un bloqueo de la BD) el evento entra ahora y el
    // dispositivo converge solo, sin que nadie pulse nada.
    final recuperados = await _reintentarCuarentena(alProgreso: alProgreso);
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
    final resultadoPull = await _ejecutarPull(
      clienteHub,
      // En una reconstrucción desde origen (cursor a 0) la base local se
      // rehidrata por completo, así que hay que traer también los eventos que
      // este dispositivo originó: si se excluyen, su propio catálogo (p. ej.
      // los nombres de categoría) nunca vuelve y quedan stubs "Categoría".
      incluirEventosPropios: desdeOrigen,
      // Reconstrucción desde origen = replay de TODO el historial de la
      // tienda (cursor a 0), no solo lo pendiente reciente. El hook
      // [alAplicarEventoRemoto] (si alguien lo conecta) no debe dispararse
      // aquí: reimprimiría cada venta histórica de la tienda.
      esReconstruccionDesdeOrigen: desdeOrigen,
      alProgreso: alProgreso,
    );
    // Corrige localmente duplicados/placeholders que este dispositivo ya
    // tenía guardados (no solo los que un evento nuevo "choca" al llegar).
    // Corre en cada sync completo, haya o no eventos nuevos: así cualquier
    // dispositivo converge solo, sin reinstalar ni borrar datos a mano.
    await _aplicadorRemoto?.autoSanarCatalogoLocal();
    // Deja constancia del resultado final (coincide o no) DESPUES del pull y
    // el autosanador: si arriba se forzo una reconstruccion, esto confirma
    // en el mismo ciclo si convergio, sin esperar a la siguiente auditoria.
    if (huellaHub != null) {
      await _registrarAuditoriaCatalogo(huellaHub);
    }
    final recibidos = resultadoPull.aplicados;
    final fallidos = resultadoPull.fallidos;
    alProgreso?.call(
      ProgresoSync(
        fase: FaseProgresoSync.listo,
        indice: enviados + recibidos,
        total: enviados + recibidos,
        mensaje: fallidos > 0
            ? 'Sincronización completada; $fallidos evento(s) apartados para reintento'
            : 'Sincronización completada',
      ),
    );
    return ResultadoSync(
      eventosEnviados: enviados,
      eventosRecibidos: recibidos,
      hubDisponible: hubOk || enviados > 0 || recibidos > 0,
      eventosFallidos: fallidos,
      eventosRecuperados: recuperados,
    );
  }

  /// Vuelve a aplicar los eventos apartados en ciclos anteriores.
  ///
  /// Retorna cuantos se pudieron aplicar por fin; los que siguen fallando se
  /// quedan en cuarentena con un intento mas y su error actualizado.
  Future<int> _reintentarCuarentena({ReporteProgresoSync? alProgreso}) async {
    final diagnostico = _diagnostico;
    final aplicador = _aplicadorRemoto;
    if (diagnostico == null || aplicador == null) {
      return 0;
    }
    final List<EventoEnCuarentena> apartados;
    try {
      apartados = await diagnostico.listarCuarentena();
    } on Object {
      return 0;
    }
    if (apartados.isEmpty) {
      return 0;
    }
    alProgreso?.call(
      ProgresoSync(
        fase: FaseProgresoSync.preparar,
        indice: 0,
        total: apartados.length,
        mensaje: 'Reintentando ${apartados.length} evento(s) pendientes…',
      ),
    );
    var recuperados = 0;
    for (final apartado in apartados) {
      try {
        await aplicador.aplicarEvento(apartado.evento);
        await diagnostico.resolverEventoFallido(apartado.evento.id);
        recuperados = recuperados + 1;
      } on Object catch (error) {
        await _registrarFalloEvento(apartado.evento, error);
      }
    }
    return recuperados;
  }

  Future<void> _registrarFalloEvento(SyncEvent evento, Object error) async {
    try {
      await _diagnostico?.registrarEventoFallido(evento: evento, error: error);
    } on Object {
      // El diagnostico es best-effort: nunca debe tumbar el ciclo de sync.
    }
  }

  /// Catalogo local en cero pero con cursor avanzado: el delta no lo recupera.
  ///
  /// El cursor solo dice "ya vi hasta el evento N", asi que un pull incremental
  /// nunca vuelve a traer los `productUpserted` historicos. Si la base local se
  /// quedo sin catalogo (limpieza que conserva el cursor, reconstruccion a
  /// medias, archivo SQLite recreado) el unico camino de vuelta es reiniciar el
  /// cursor y reproducir desde origen. Antes esto obligaba a descargar el
  /// catalogo a mano o a reinstalar la app.
  Future<bool> _catalogoVacioConCursorAvanzado() async {
    final contar = _contarCatalogoActivo;
    final almacenCursor = _almacenCursor;
    if (contar == null || almacenCursor == null) {
      return false;
    }
    try {
      final cursor = await almacenCursor.leerCursorHub();
      if (cursor <= 0) {
        return false;
      }
      return await contar() == 0;
    } on Object {
      // Ante duda, seguir con el ciclo incremental normal.
      return false;
    }
  }

  /// Pide al hub la huella del catalogo activo, como mucho una vez cada
  /// [INTERVALO_AUDITORIA_CATALOGO_SEGUNDOS].
  ///
  /// Es una consulta de conteo + hash sobre todo `products` en Neon; correrla
  /// en cada ciclo de 60 s golpearia al hub sin necesidad. Si la ultima
  /// auditoria registrada (coincida o no) es reciente, no pide nada y este
  /// ciclo sigue como un pull incremental normal. Un fallo de red devuelve
  /// null y no actualiza el "ultimo intento", asi que el siguiente ciclo (60 s
  /// despues) reintenta en vez de esperar la hora completa.
  Future<HuellaCatalogo?> _obtenerHuellaHubSiToca(HubSyncClient clienteHub) async {
    try {
      final ultima = await _diagnostico?.leerUltimaAuditoriaCatalogo();
      if (ultima != null) {
        final transcurrido = DateTime.now().toUtc().difference(ultima.verificadoEn);
        if (transcurrido <
            const Duration(seconds: INTERVALO_AUDITORIA_CATALOGO_SEGUNDOS)) {
          return null;
        }
      }
    } on Object {
      // Ante duda, intentar la auditoria de todas formas.
    }
    return clienteHub.auditarCatalogo();
  }

  /// Reparacion rapida ante una divergencia de catalogo: aplica solo los
  /// eventos que lo definen (productos, categorías, presentaciones, tiendas,
  /// proveedores, almacenes), deduplicados al más reciente por entidad, SIN
  /// tocar el cursor de sync — el historial transaccional sigue su curso
  /// incremental normal en el resto del ciclo.
  ///
  /// Retorna false si el hub no respondió (desplegado sin esta ruta, o caído
  /// de red): el llamador recurre a la reconstrucción completa desde origen
  /// como red de seguridad. Un evento individual que falle se aparta en
  /// cuarentena igual que en un pull normal, sin abortar el resto del lote.
  Future<bool> _repararCatalogoRapido(HubSyncClient clienteHub) async {
    final aplicador = _aplicadorRemoto;
    if (aplicador == null) {
      return false;
    }
    final resultado = await clienteHub.obtenerCatalogoCompacto();
    if (!resultado.exitoso) {
      return false;
    }
    for (final evento in resultado.eventos) {
      try {
        await aplicador.aplicarEvento(evento);
      } on Object catch (error) {
        await _registrarFalloEvento(evento, error);
      }
    }
    return true;
  }

  /// Registra si el catalogo local, tras este ciclo, coincide con [huellaHub].
  ///
  /// Best-effort: un fallo aqui no debe tumbar el ciclo de sync, solo deja de
  /// actualizarse el diagnostico visible en el panel de sync.
  Future<void> _registrarAuditoriaCatalogo(HuellaCatalogo huellaHub) async {
    final diagnostico = _diagnostico;
    final aplicador = _aplicadorRemoto;
    if (diagnostico == null || aplicador == null) {
      return;
    }
    try {
      final huellaLocal = await aplicador.calcularHuellaCatalogoLocal();
      await diagnostico.registrarAuditoriaCatalogo(
        AuditoriaCatalogo(
          coincide: huellaLocal.coincideCon(huellaHub),
          productosHub: huellaHub.productosActivos,
          productosLocal: huellaLocal.productosActivos,
          categoriasHub: huellaHub.categoriasActivas,
          categoriasLocal: huellaLocal.categoriasActivas,
          verificadoEn: DateTime.now().toUtc(),
        ),
      );
    } on Object {
      // El diagnostico es best-effort: nunca debe tumbar el ciclo de sync.
    }
  }

  /// Descarga y aplica el historial pendiente del hub.
  ///
  /// Cada evento se aplica aislado: si uno falla se aparta en cuarentena y el
  /// recorrido continua. El cursor avanza con los eventos ya procesados, no al
  /// terminar la pagina, para que un fallo a mitad de camino no obligue a
  /// repetirla ni —peor— deje al dispositivo anclado en ese punto del historial
  /// ciclo tras ciclo, mostrando un catalogo de semanas atras.
  Future<_ResultadoPullLocal> _ejecutarPull(
    HubSyncClient clienteHub, {
    bool incluirEventosPropios = false,
    bool esReconstruccionDesdeOrigen = false,
    ReporteProgresoSync? alProgreso,
  }) async {
    final aplicador = _aplicadorRemoto;
    final almacenCursor = _almacenCursor;
    if (aplicador == null || almacenCursor == null) {
      return const _ResultadoPullLocal(aplicados: 0, fallidos: 0);
    }

    var aplicados = 0;
    var fallidos = 0;
    var cursor = await almacenCursor.leerCursorHub();
    var cursorConfirmado = cursor;
    var desdeUltimaConfirmacion = 0;
    var continuar = true;

    Future<void> confirmarCursor() async {
      if (cursor <= cursorConfirmado) {
        return;
      }
      await almacenCursor.guardarCursorHub(cursor);
      cursorConfirmado = cursor;
      desdeUltimaConfirmacion = 0;
    }

    while (continuar) {
      final cursorAlPedirPagina = cursor;
      final resultado = await clienteHub.obtenerEventos(
        desdeSeq: cursor,
        excluirDispositivoId: incluirEventosPropios ? null : _dispositivoId,
      );
      if (!resultado.exitoso || resultado.eventos.isEmpty) {
        continuar = false;
        continue;
      }
      for (final evento in resultado.eventos) {
        try {
          await aplicador.aplicarEvento(evento);
          if (!esReconstruccionDesdeOrigen) {
            await alAplicarEventoRemoto?.call(evento);
          }
          aplicados = aplicados + 1;
        } on Object catch (error) {
          fallidos = fallidos + 1;
          await _registrarFalloEvento(evento, error);
        }
        // El evento queda atras pase lo que pase: aplicado o apartado para
        // reintento. Lo que no puede es bloquear a los que vienen detras.
        if (evento.seq > cursor) {
          cursor = evento.seq;
        }
        desdeUltimaConfirmacion = desdeUltimaConfirmacion + 1;
        if (desdeUltimaConfirmacion >= _eventosPorConfirmacionCursor) {
          await confirmarCursor();
        }
        alProgreso?.call(
          ProgresoSync(
            fase: FaseProgresoSync.recibir,
            indice: aplicados,
            total: 0,
            mensaje: 'Recibiendo cambios ($aplicados eventos)…',
          ),
        );
      }
      // El hub puede haber saltado eventos filtrados por dispositivo: su
      // `lastSeq` va por delante del ultimo que llego y tambien cuenta.
      if (resultado.ultimoSeq > cursor) {
        cursor = resultado.ultimoSeq;
      }
      await confirmarCursor();
      // Guarda de seguridad: si el cursor no avanza, detener el pull para no
      // repetir la misma pagina indefinidamente (evita bloquear la BD y la UI).
      if (cursor <= cursorAlPedirPagina) {
        continuar = false;
        continue;
      }
      // Cede el hilo entre paginas para que las lecturas de la UI (Admin,
      // caja) se intercalen y no perciban un spinner interminable.
      await Future<void>.delayed(Duration.zero);
    }
    await confirmarCursor();
    return _ResultadoPullLocal(aplicados: aplicados, fallidos: fallidos);
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

  /// Mide el atraso de este dispositivo contra la cabeza del log del hub.
  Future<AtrasoSync> medirAtraso() async {
    final cursorLocal = await _almacenCursor?.leerCursorHub() ?? 0;
    final cursorHub = await _clienteHub?.obtenerUltimoSeqHub();
    return AtrasoSync(cursorLocal: cursorLocal, cursorHub: cursorHub);
  }
}

/// Distancia entre el cursor local y el ultimo evento publicado por el hub.
class AtrasoSync {
  const AtrasoSync({required this.cursorLocal, required this.cursorHub});

  /// Ultimo seq confirmado por este dispositivo.
  final int cursorLocal;

  /// Ultimo seq del hub; null si el hub no expone la ruta o no responde.
  final int? cursorHub;

  /// Eventos sin aplicar, o null si no se pudo consultar al hub.
  int? get eventosAtrasados {
    final hub = cursorHub;
    if (hub == null) {
      return null;
    }
    return hub > cursorLocal ? hub - cursorLocal : 0;
  }
}

/// Conteo de eventos aplicados y apartados en un pull.
class _ResultadoPullLocal {
  const _ResultadoPullLocal({required this.aplicados, required this.fallidos});

  final int aplicados;
  final int fallidos;
}
