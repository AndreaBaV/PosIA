/// Prueba de integracion del hub: push, pull y deduplicacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 16:20:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 16:20:00 (UTC-6)
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:posia_sync_api/posia_sync_api.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  late HttpServer servidor;
  late String urlBase;
  late Directory directorioTemporal;

  setUp(() async {
    directorioTemporal = Directory.systemTemp.createTempSync('posia_hub_test');
    final almacen = AlmacenEventosArchivo(
      rutaArchivo:
          '${directorioTemporal.path}${Platform.pathSeparator}eventos.jsonl',
    );
    await almacen.inicializar();
    final enrutador = EnrutadorApi(almacen: almacen, claveApi: null);
    servidor = await shelf_io.serve(
      enrutador.construirHandler(),
      InternetAddress.loopbackIPv4,
      0,
    );
    urlBase = 'http://127.0.0.1:${servidor.port}';
  });

  tearDown(() async {
    await servidor.close(force: true);
    directorioTemporal.deleteSync(recursive: true);
  });

  /// Envia lote de prueba al hub.
  Future<Map<String, Object?>> enviarLote(
    List<Map<String, Object?>> eventos,
  ) async {
    final respuesta = await http.post(
      Uri.parse('$urlBase/v1/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceId': 'caja-1',
        'storeId': 'tienda-1',
        'events': eventos,
      }),
    );
    return jsonDecode(respuesta.body) as Map<String, Object?>;
  }

  test('health responde ok', () async {
    final respuesta = await http.get(Uri.parse('$urlBase/v1/health'));
    expect(respuesta.statusCode, 200);
  });

  test('health responde ok con API_KEY configurada', () async {
    await servidor.close(force: true);
    final almacen = AlmacenEventosArchivo(
      rutaArchivo:
          '${directorioTemporal.path}${Platform.pathSeparator}eventos_auth.jsonl',
    );
    await almacen.inicializar();
    final enrutador = EnrutadorApi(almacen: almacen, claveApi: 'clave-secreta');
    servidor = await shelf_io.serve(
      enrutador.construirHandler(),
      InternetAddress.loopbackIPv4,
      0,
    );
    urlBase = 'http://127.0.0.1:${servidor.port}';
    final respuesta = await http.get(Uri.parse('$urlBase/v1/health'));
    expect(respuesta.statusCode, 200);
  });

  test('push acepta eventos y pull los regresa con cursor', () async {
    final resultadoPush = await enviarLote([
      {
        'id': 'ev-1',
        'type': 'saleCompleted',
        'payload': {'ventaId': 'v1', 'total': 99.5},
        'createdAt': '2026-06-11T16:20:00Z',
      },
    ]);
    expect(resultadoPush['accepted'], 1);

    final respuestaPull = await http.get(
      Uri.parse('$urlBase/v1/events?since=0'),
    );
    final cuerpoPull = jsonDecode(respuestaPull.body) as Map<String, Object?>;
    final eventos = cuerpoPull['events'] as List<Object?>;
    expect(eventos.length, 1);
    expect(cuerpoPull['lastSeq'], 1);
  });

  test('push duplicado se ignora por id', () async {
    final evento = {
      'id': 'ev-dup',
      'type': 'productUpserted',
      'payload': {'nombre': 'Frijol'},
      'createdAt': '2026-06-11T16:20:00Z',
    };
    final primero = await enviarLote([evento]);
    final segundo = await enviarLote([evento]);
    expect(primero['accepted'], 1);
    expect(segundo['accepted'], 0);
  });

  test('excludeDevice omite eventos del propio dispositivo', () async {
    await enviarLote([
      {
        'id': 'ev-propio',
        'type': 'saleCompleted',
        'payload': {'ventaId': 'v2'},
        'createdAt': '2026-06-11T16:20:00Z',
      },
    ]);
    final respuesta = await http.get(
      Uri.parse('$urlBase/v1/events?since=0&excludeDevice=caja-1'),
    );
    final cuerpo = jsonDecode(respuesta.body) as Map<String, Object?>;
    expect((cuerpo['events'] as List<Object?>).isEmpty, isTrue);
  });

  test('lote sin deviceId es rechazado', () async {
    final respuesta = await http.post(
      Uri.parse('$urlBase/v1/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(<String, Object?>{'events': <Object?>[]}),
    );
    expect(respuesta.statusCode, 400);
  });

  test('pull devuelve todos los eventos del despliegue', () async {
    await enviarLote([
      {
        'id': 'ev-sin-tenant',
        'type': 'saleCompleted',
        'payload': {'ventaId': 'v3'},
        'createdAt': '2026-06-11T16:21:00Z',
      },
    ]);
    final respuesta = await http.get(Uri.parse('$urlBase/v1/events?since=0'));
    final cuerpo = jsonDecode(respuesta.body) as Map<String, Object?>;
    final eventos = cuerpo['events'] as List<Object?>;
    expect(eventos.length, greaterThanOrEqualTo(1));
  });
}
