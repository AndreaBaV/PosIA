/// Cliente HTTP para sincronizacion con hub central.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:posia_core/posia_core.dart';

import 'auth_hub.dart';

class ResultadoPullHub {
  const ResultadoPullHub({
    required this.eventos,
    required this.ultimoSeq,
    required this.exitoso,
  });

  final List<SyncEvent> eventos;
  final int ultimoSeq;
  final bool exitoso;
}

class HubSyncClient {
  HubSyncClient({
    required String urlBase,
    String? claveApi,
    http.Client? clienteHttp,
  }) : _urlBase = urlBase,
       _claveApi = claveApi,
       _clienteHttp = clienteHttp ?? http.Client();

  final String _urlBase;
  final String? _claveApi;
  final http.Client _clienteHttp;

  Future<bool> enviarEventos({
    required String dispositivoId,
    required String tiendaId,
    required List<SyncEvent> eventos,
  }) async {
    final uri = Uri.parse('$_urlBase/v1/events');
    final cuerpo = jsonEncode({
      'deviceId': dispositivoId,
      'storeId': tiendaId,
      'events': eventos.map(_serializarEvento).toList(),
    });
    try {
      final respuesta = await _clienteHttp
          .post(uri, headers: _construirCabeceras(), body: cuerpo)
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        return false;
      }
      final json = jsonDecode(respuesta.body) as Map<String, Object?>;
      final aceptados = json['accepted'] as int? ?? 0;
      // Solo cuenta como exito si el hub persistio y proyecto el evento.
      // Antes, received > 0 marcaba enviado aunque accepted = 0 (fallo en Neon).
      return aceptados >= eventos.length;
    } on Object {
      return false;
    }
  }

  Future<ResultadoPullHub> obtenerEventos({
    required int desdeSeq,
    String? excluirDispositivoId,
  }) async {
    final uri = Uri.parse('$_urlBase/v1/events').replace(
      queryParameters: {
        'since': desdeSeq.toString(),
        if (excluirDispositivoId != null) 'excludeDevice': excluirDispositivoId,
      },
    );
    final http.Response respuesta;
    try {
      respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
    } on Object {
      return const ResultadoPullHub(eventos: [], ultimoSeq: 0, exitoso: false);
    }
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      return const ResultadoPullHub(eventos: [], ultimoSeq: 0, exitoso: false);
    }
    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final lista = json['events'];
    final eventos = <SyncEvent>[];
    if (lista is List) {
      for (final item in lista) {
        if (item is! Map) {
          continue;
        }
        final evento = _deserializarEvento(Map<String, dynamic>.from(item));
        if (evento != null) {
          eventos.add(evento);
        }
      }
    }
    return ResultadoPullHub(
      eventos: eventos,
      ultimoSeq: json['lastSeq'] as int? ?? desdeSeq,
      exitoso: true,
    );
  }

  /// Indica si el hub tiene Postgres y puede autenticar usuarios.
  ///
  /// Wrapper retrocompatible sobre [verificarEstadoAuth].
  Future<bool> tieneAuthHub() async {
    final estado = await verificarEstadoAuth();
    return estado == EstadoAuthHub.disponible;
  }

  /// Diagnostica el estado del canal de autenticacion del hub.
  ///
  /// Devuelve un estado tipado que distingue "hub sin Postgres" (503),
  /// "clave API invalida" (401) y "hub inalcanzable" (timeout/red/5xx).
  Future<EstadoAuthHub> verificarEstadoAuth() async {
    final uri = Uri.parse(
      '$_urlBase/v1/auth/preview',
    ).replace(queryParameters: {'codigo': '__posia_probe__'});
    try {
      final respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
      final status = respuesta.statusCode;
      if (status == 503) {
        return EstadoAuthHub.sinPostgres;
      }
      if (status == 401 || status == 403) {
        return EstadoAuthHub.apiKeyInvalida;
      }
      // 200 (perfil encontrado, improbable con el codigo sonda) o
      // 404 (respuesta definitiva "no existe") indican que la ruta esta viva.
      if (status == 200 || status == 400 || status == 404) {
        return EstadoAuthHub.disponible;
      }
      return EstadoAuthHub.inalcanzable;
    } on Object {
      return EstadoAuthHub.inalcanzable;
    }
  }

  /// Consulta un perfil por codigo con resultado tipado.
  ///
  /// Distingue "usuario no existe" (404) de errores transitorios o de
  /// configuracion (401, 5xx, timeout). Preferir sobre [obtenerPerfilUsuario]
  /// para flujos de inicio de sesion donde importa distinguir el motivo.
  Future<ConsultaPerfilHub> consultarPerfil(String codigo) async {
    final limpio = codigo.trim();
    if (limpio.isEmpty) {
      return const ConsultaPerfilHub.noEncontrado();
    }
    final uri = Uri.parse(
      '$_urlBase/v1/auth/preview',
    ).replace(queryParameters: {'codigo': limpio});
    final http.Response respuesta;
    try {
      respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
    } on Object catch (error) {
      return ConsultaPerfilHub.errorHub(
        estado: EstadoAuthHub.inalcanzable,
        detalle: '$error',
      );
    }
    final status = respuesta.statusCode;
    if (status == 200) {
      try {
        final json = jsonDecode(respuesta.body) as Map<String, Object?>;
        final perfil = _mapearPerfil(json);
        if (perfil == null) {
          return const ConsultaPerfilHub.errorHub(
            estado: EstadoAuthHub.inalcanzable,
            codigoHttp: 200,
            detalle: 'Perfil sin id',
          );
        }
        return ConsultaPerfilHub.encontrado(perfil);
      } on Object catch (error) {
        return ConsultaPerfilHub.errorHub(
          estado: EstadoAuthHub.inalcanzable,
          codigoHttp: 200,
          detalle: '$error',
        );
      }
    }
    if (status == 404) {
      return const ConsultaPerfilHub.noEncontrado();
    }
    if (status == 503) {
      return const ConsultaPerfilHub.errorHub(
        estado: EstadoAuthHub.sinPostgres,
        codigoHttp: 503,
      );
    }
    if (status == 401 || status == 403) {
      return ConsultaPerfilHub.errorHub(
        estado: EstadoAuthHub.apiKeyInvalida,
        codigoHttp: status,
      );
    }
    return ConsultaPerfilHub.errorHub(
      estado: EstadoAuthHub.inalcanzable,
      codigoHttp: status,
    );
  }

  /// Detecta si un cuerpo de error 401 corresponde a "Clave API invalida".
  ///
  /// Ambas rutas del hub responden 401 (middleware de clave y handler de
  /// login), pero solo el middleware devuelve un mensaje de clave.
  bool _pareceErrorClaveApi(String cuerpo) {
    final normalizado = cuerpo.toLowerCase();
    return normalizado.contains('clave api') || normalizado.contains('api key');
  }

  /// Wrapper retrocompatible: devuelve el perfil solo si el hub confirma 200.
  Future<PerfilUsuarioHub?> obtenerPerfilUsuario(String codigo) async {
    final consulta = await consultarPerfil(codigo);
    return consulta.perfil;
  }

  /// Intenta iniciar sesion con resultado tipado.
  ///
  /// Distingue credenciales invalidas (401) de errores de red/config/servidor
  /// para poder mostrar mensajes accionables en pantalla.
  Future<IntentoLoginHub> intentarLogin({
    required String codigo,
    required String pin,
  }) async {
    final limpio = codigo.trim();
    if (limpio.isEmpty || pin.isEmpty) {
      return const IntentoLoginHub.credencialesInvalidas();
    }
    final uri = Uri.parse('$_urlBase/v1/auth/login');
    final http.Response respuesta;
    try {
      respuesta = await _clienteHttp
          .post(
            uri,
            headers: _construirCabeceras(),
            body: jsonEncode({'codigo': limpio, 'pin': pin}),
          )
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
    } on Object catch (error) {
      return IntentoLoginHub.errorHub(
        estado: EstadoAuthHub.inalcanzable,
        detalle: '$error',
      );
    }
    final status = respuesta.statusCode;
    if (status == 200) {
      try {
        final json = jsonDecode(respuesta.body) as Map<String, Object?>;
        final perfil = _mapearPerfil(json);
        if (perfil == null) {
          return const IntentoLoginHub.errorHub(
            estado: EstadoAuthHub.inalcanzable,
            codigoHttp: 200,
            detalle: 'Login sin id',
          );
        }
        final pinCredencial = json['pinCredencial'] as String? ?? '';
        if (pinCredencial.isEmpty) {
          return const IntentoLoginHub.errorHub(
            estado: EstadoAuthHub.inalcanzable,
            codigoHttp: 200,
            detalle: 'Login sin pinCredencial',
          );
        }
        return IntentoLoginHub.exito(
          RespuestaLoginHub(
            perfil: perfil,
            pinCredencial: pinCredencial,
            creadoEn: json['creadoEn'] as String? ?? '',
            actualizadoEn: json['actualizadoEn'] as String? ?? '',
            tiendas: _mapearTiendas(json['tiendas']),
          ),
        );
      } on Object catch (error) {
        return IntentoLoginHub.errorHub(
          estado: EstadoAuthHub.inalcanzable,
          codigoHttp: 200,
          detalle: '$error',
        );
      }
    }
    // Un 401 puede venir del middleware (clave API mal) o del handler
    // (credenciales invalidas). Se distingue leyendo el cuerpo del error
    // para no reportar "PIN incorrecto" cuando el problema es de configuracion.
    if (status == 401) {
      if (_pareceErrorClaveApi(respuesta.body)) {
        return const IntentoLoginHub.errorHub(
          estado: EstadoAuthHub.apiKeyInvalida,
          codigoHttp: 401,
        );
      }
      return const IntentoLoginHub.credencialesInvalidas();
    }
    if (status == 503) {
      return const IntentoLoginHub.errorHub(
        estado: EstadoAuthHub.sinPostgres,
        codigoHttp: 503,
      );
    }
    if (status == 403) {
      return const IntentoLoginHub.errorHub(
        estado: EstadoAuthHub.apiKeyInvalida,
        codigoHttp: 403,
      );
    }
    return IntentoLoginHub.errorHub(
      estado: EstadoAuthHub.inalcanzable,
      codigoHttp: status,
    );
  }

  /// Wrapper retrocompatible: devuelve login solo si el hub confirma 200.
  Future<RespuestaLoginHub?> iniciarSesion({
    required String codigo,
    required String pin,
  }) async {
    final intento = await intentarLogin(codigo: codigo, pin: pin);
    return intento.login;
  }

  PerfilUsuarioHub? _mapearPerfil(Map<String, Object?> json) {
    final id = json['id'] as String? ?? '';
    if (id.isEmpty) {
      return null;
    }
    return PerfilUsuarioHub(
      id: id,
      nombre: json['nombre'] as String? ?? '',
      codigo: json['codigo'] as String? ?? '',
      rol: json['rol'] as String? ?? 'empleado',
      tiendaId: json['tiendaId'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  List<TiendaHub> _mapearTiendas(Object? crudo) {
    if (crudo is! List) {
      return const [];
    }
    final tiendas = <TiendaHub>[];
    for (final item in crudo) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) {
        continue;
      }
      tiendas.add(
        TiendaHub(
          id: id,
          nombre: map['nombre'] as String? ?? '',
          direccion: map['direccion'] as String? ?? '',
          activa: _leerActiva(map['activa']),
          latitud: (map['latitud'] as num?)?.toDouble(),
          longitud: (map['longitud'] as num?)?.toDouble(),
          radioMetrosAsistencia:
              (map['radioMetros'] as num?)?.toDouble() ??
              (map['radioMetrosAsistencia'] as num?)?.toDouble() ??
              150,
        ),
      );
    }
    return tiendas;
  }

  Future<bool> verificarSalud() async {
    final uri = Uri.parse('$_urlBase/v1/health');
    try {
      final respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
      return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
    } on Object {
      return false;
    }
  }

  Future<List<TiendaHub>> obtenerTiendas() async {
    final uri = Uri.parse('$_urlBase/v1/stores');
    try {
      final respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
      if (respuesta.statusCode != 200) {
        return const [];
      }
      final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return _mapearTiendas(json['tiendas']);
    } on Object {
      return const [];
    }
  }

  Future<List<UsuarioHub>> obtenerUsuarios() async {
    final uri = Uri.parse('$_urlBase/v1/users');
    try {
      final respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
      if (respuesta.statusCode != 200) {
        return const [];
      }
      final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return _mapearUsuarios(json['usuarios']);
    } on Object {
      return const [];
    }
  }

  List<UsuarioHub> _mapearUsuarios(Object? crudo) {
    if (crudo is! List) {
      return const [];
    }
    final usuarios = <UsuarioHub>[];
    for (final item in crudo) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final id = map['id'] as String? ?? '';
      final pinCredencial = map['pinCredencial'] as String? ?? '';
      if (id.isEmpty || pinCredencial.isEmpty) {
        continue;
      }
      usuarios.add(
        UsuarioHub(
          id: id,
          nombre: map['nombre'] as String? ?? '',
          codigo: map['codigo'] as String? ?? '',
          rol: map['rol'] as String? ?? 'empleado',
          tiendaId: map['tiendaId'] as String?,
          rolPersonalizadoId: map['rolPersonalizadoId'] as String?,
          activo: _leerActiva(map['activo']),
          pinCredencial: pinCredencial,
          creadoEn: map['creadoEn'] as String? ?? '',
          actualizadoEn: map['actualizadoEn'] as String? ?? '',
        ),
      );
    }
    return usuarios;
  }

  Future<List<RolPersonalizadoHub>> obtenerRolesPersonalizados() async {
    final uri = Uri.parse('$_urlBase/v1/custom-roles');
    try {
      final respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_SYNC_SEGUNDOS));
      if (respuesta.statusCode != 200) {
        return const [];
      }
      final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return _mapearRolesPersonalizados(json['roles']);
    } on Object {
      return const [];
    }
  }

  List<RolPersonalizadoHub> _mapearRolesPersonalizados(Object? crudo) {
    if (crudo is! List) {
      return const [];
    }
    final roles = <RolPersonalizadoHub>[];
    for (final item in crudo) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) {
        continue;
      }
      roles.add(
        RolPersonalizadoHub(
          id: id,
          nombre: map['nombre'] as String? ?? '',
          descripcion: map['descripcion'] as String? ?? '',
          permisosAdmin: _leerListaTexto(map['permisosAdmin']),
          categoriasPermitidas: _leerListaTexto(map['categoriasPermitidas']),
          activo: _leerActiva(map['activo']),
          tiendaId: map['tiendaId'] as String?,
        ),
      );
    }
    return roles;
  }

  List<String> _leerListaTexto(Object? crudo) {
    if (crudo is! List) {
      return const [];
    }
    return crudo.map((e) => e.toString()).toList();
  }

  Future<bool> mantenerHubVivo() async {
    final uri = Uri.parse('$_urlBase/v1/health');
    try {
      final respuesta = await _clienteHttp
          .get(uri, headers: _construirCabeceras())
          .timeout(const Duration(seconds: TIMEOUT_HUB_DESPERTAR_SEGUNDOS));
      return respuesta.statusCode >= 200 && respuesta.statusCode < 300;
    } on Object {
      return false;
    }
  }

  Map<String, String> _construirCabeceras() {
    final clave = _claveApi;
    return {
      'Content-Type': 'application/json',
      if (clave != null && clave.isNotEmpty) 'x-api-key': clave,
    };
  }

  Map<String, Object?> _serializarEvento(SyncEvent evento) {
    return {
      'id': evento.id,
      'type': evento.tipo.name,
      'payload': evento.payload,
      'createdAt': evento.creadoEn.toIso8601String(),
    };
  }

  SyncEvent? _deserializarEvento(Map<String, dynamic> json) {
    final tipoNombre = json['type'] as String? ?? '';
    final TipoSyncEvento tipo;
    try {
      tipo = TipoSyncEvento.values.byName(tipoNombre);
    } on ArgumentError {
      return null;
    }
    return SyncEvent(
      id: json['id'] as String? ?? '',
      tiendaId: json['storeId'] as String? ?? '',
      dispositivoId: json['deviceId'] as String? ?? '',
      tipo: tipo,
      payload: Map<String, Object?>.from(
        json['payload'] as Map<Object?, Object?>? ?? {},
      ),
      creadoEn: DateTime.parse(json['createdAt'] as String? ?? ''),
      estado: EstadoSyncEvento.enviado,
    );
  }

  bool _leerActiva(Object? valor) {
    if (valor is bool) {
      return valor;
    }
    if (valor is num) {
      return valor != 0;
    }
    return true;
  }
}
