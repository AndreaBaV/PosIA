/// Repara stubs "Producto" que un dispositivo pudo haber creado localmente al
/// recibir el evento de presentaciones de una fusión anterior (antes del fix
/// que ahora reafirma el alta del canónico en cada merge). Busca productos
/// ACTIVOS cuyo nombre normalizado coincide con el de un producto INACTIVO
/// (la huella de una fusión ya hecha) y reemite su productUpserted con datos
/// reales, para que cualquier dispositivo que lo tenga como stub lo corrija
/// al sincronizar.
///
/// DRY-RUN por defecto. Pasar --apply para ejecutar.
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../lib/src/evento_hub.dart';
import '../lib/src/proyector_eventos_postgres.dart';

Future<void> main(List<String> args) async {
  final aplicar = args.contains('--apply');
  final urlStr = Platform.environment['MERGE_DB_URL'] ??
      File('.env')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('DATABASE_URL='))
          .substring('DATABASE_URL='.length)
          .trim();
  final uri = Uri.parse(urlStr);
  final info = uri.userInfo.split(':');
  final conn = await Connection.open(
    Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: uri.pathSegments.first,
      username: info[0],
      password: info.length > 1 ? info.sublist(1).join(':') : '',
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );

  print(aplicar
      ? '=== MODO APLICAR (escribe) ===  host=${uri.host}'
      : '=== DRY-RUN (no escribe) ===  host=${uri.host}');

  final resultado = await conn.execute('''
    SELECT DISTINCT ON (activo.id)
      activo.id, activo.nombre, activo.codigo_barras, activo.precio_base,
      activo.unidad_medida, activo.ruta_imagen, activo.tienda_id,
      activo.modulo_vertical, activo.categoria_id, activo.piezas_por_caja,
      activo.proveedor_id, activo.unidades_por_bulto, activo.notas,
      activo.costo_unitario, activo.permite_stock_negativo, activo.favorito_caja
    FROM products activo
    JOIN products inactivo
      ON lower(trim(inactivo.nombre)) = lower(trim(activo.nombre))
      AND inactivo.activo = 0
      AND inactivo.id <> activo.id
    WHERE activo.activo = 1
    ORDER BY activo.id
  ''');

  if (resultado.isEmpty) {
    print('\nNada que reafirmar.');
    await conn.close();
    return;
  }

  print('\nCanónicos a reafirmar: ${resultado.length}');
  for (final fila in resultado) {
    final c = fila.toColumnMap();
    final id = c['id'] as String;
    final nombre = c['nombre'] as String;
    print('  $id  "$nombre"');
    if (!aplicar) continue;
    final evento = EventoHub(
      seq: 0,
      id: 'productUpserted:reafirma:$id',
      tiendaId: c['tienda_id'] as String? ?? '',
      dispositivoId: 'reafirma-neon',
      tipo: 'productUpserted',
      payload: {
        'id': id,
        'nombre': nombre,
        'codigoBarras': c['codigo_barras'] ?? '',
        'precioBase': c['precio_base'],
        'unidadMedida': c['unidad_medida'],
        'rutaImagen': c['ruta_imagen'] ?? '',
        'activo': true,
        'tiendaId': c['tienda_id'],
        'moduloVertical': c['modulo_vertical'],
        'categoriaId': c['categoria_id'],
        'piezasPorCaja': c['piezas_por_caja'],
        'proveedorId': c['proveedor_id'],
        'unidadesPorBulto': c['unidades_por_bulto'],
        'notas': c['notas'] ?? '',
        'costoUnitario': c['costo_unitario'],
        'permiteStockNegativo': (c['permite_stock_negativo'] as int) != 0,
        'favoritoCaja': (c['favorito_caja'] as int) != 0,
      },
      creadoEn: DateTime.now().toUtc(),
    );
    await conn.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO sync_events (id, store_id, device_id, type, payload, created_at)
          VALUES (@id, @storeId, @deviceId, @type, @payload, @createdAt)
          ON CONFLICT (id) DO UPDATE SET
            store_id = EXCLUDED.store_id,
            device_id = EXCLUDED.device_id,
            type = EXCLUDED.type,
            payload = EXCLUDED.payload,
            created_at = EXCLUDED.created_at
        '''),
        parameters: {
          'id': evento.id,
          'storeId': evento.tiendaId,
          'deviceId': evento.dispositivoId,
          'type': evento.tipo,
          'payload': jsonEncode(evento.payload),
          'createdAt': evento.creadoEn,
        },
      );
      await ProyectorEventosPostgres(tx).aplicar(evento);
    });
  }

  print(aplicar
      ? '\nReafirmados: ${resultado.length}'
      : '\nDRY-RUN: nada se escribió. Corre con --apply para ejecutar.');
  await conn.close();
}
