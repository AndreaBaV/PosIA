/// Asigna un código interno idempotente (`#nombre-normalizado`) a todos los
/// productos ACTIVOS que en Neon todavía no tienen código de barras real,
/// después de fusionar duplicados por nombre para que dos productos distintos
/// no reciban el mismo código.
///
/// Pensado para el caso "productos a granel": la usuaria importa listas de
/// precios sin código, el sistema no puede deduplicar por código y termina
/// creando N copias del mismo artículo. Este script:
///
///  1. Deduplica en Neon por nombre normalizado (mismo criterio que
///     `merge_productos_duplicados.dart`): canónico = más presentaciones →
///     más stock → id menor. Los perdedores quedan como alias inactivos.
///  2. Asigna al canónico el código interno derivado del nombre
///     (`#almendra-fileteada`, etc.) para que futuras altas o importaciones
///     colisionen contra el índice único `(tienda_id, codigo_barras)` y no
///     puedan volver a duplicarlo.
///  3. Emite todos los cambios como `productUpserted` con id determinista al
///     event log. Los dispositivos convergen en el próximo pull. Los productos
///     con código real (7501…) no se tocan.
///
/// La generación del código replica exactamente `generarCodigoInternoDesdeNombre`
/// de `posia_core` para que servidor y cliente lleguen al mismo valor.
///
/// URL: usa `MERGE_DB_URL` si está, si no la `DATABASE_URL` del `.env`.
/// DRY-RUN por defecto. Pasar `--apply` para escribir.
library;

import 'dart:convert';
import 'dart:io';

import 'package:posia_core/posia_core.dart' show generarCodigoInternoDesdeNombre;
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
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );

  print(aplicar
      ? '=== MODO APLICAR (escribe) === host=${uri.host}'
      : '=== DRY-RUN (no escribe) === host=${uri.host}');

  // ---------------------------------------------------------------------------
  // Fase 1: dedup por nombre normalizado.
  // ---------------------------------------------------------------------------
  print('\n--- Fase 1: fusionando duplicados por nombre ---');
  final grupos = await conn.execute('''
    SELECT lower(trim(nombre)) AS clave, array_agg(id) AS ids
    FROM products
    WHERE activo = 1 AND trim(nombre) <> '' AND trim(nombre) <> 'Producto'
    GROUP BY lower(trim(nombre))
    HAVING COUNT(*) > 1
    ORDER BY clave
  ''');

  var totalGrupos = 0;
  var totalDesactivados = 0;
  final canonicosPorClave = <String, String>{};
  final tiendaPorCanonico = <String, String>{};

  for (final fila in grupos) {
    final clave = fila[0] as String;
    final ids = (fila[1] as List).cast<String>();

    final metricas = <String, (int pres, double stock)>{};
    for (final id in ids) {
      final rp = await conn.execute(
        Sql.named(
            'SELECT COUNT(*) FROM product_presentations WHERE producto_id = @id'),
        parameters: {'id': id},
      );
      final rs = await conn.execute(
        Sql.named(
            'SELECT COALESCE(SUM(cantidad),0) FROM stock_levels WHERE producto_id = @id'),
        parameters: {'id': id},
      );
      metricas[id] = ((rp.first[0] as int), (rs.first[0] as num).toDouble());
    }
    final ordenados = [...ids]..sort((a, b) {
        final ma = metricas[a]!;
        final mb = metricas[b]!;
        if (mb.$1 != ma.$1) return mb.$1.compareTo(ma.$1);
        if (mb.$2 != ma.$2) return mb.$2.compareTo(ma.$2);
        return a.compareTo(b);
      });
    final canonico = ordenados.first;
    final perdedores = ordenados.skip(1).toList();
    totalGrupos++;
    totalDesactivados += perdedores.length;

    final filaCanonico = await conn.execute(
      Sql.named('''
        SELECT nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
               tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
               proveedor_id, unidades_por_bulto, notas, costo_unitario,
               permite_stock_negativo, favorito_caja
        FROM products WHERE id = @id
      '''),
      parameters: {'id': canonico},
    );
    final datosCanonico = filaCanonico.first.toColumnMap();
    final tiendaId = datosCanonico['tienda_id'] as String;
    canonicosPorClave[clave] = canonico;
    tiendaPorCanonico[canonico] = tiendaId;

    print('"$clave"');
    print('  canónico=$canonico (tienda $tiendaId)  pres=${metricas[canonico]!.$1}');
    for (final l in perdedores) {
      print('  perdedor=$l pres=${metricas[l]!.$1} -> desactivar (alias)');
    }

    if (!aplicar) continue;

    // Unión de presentaciones al canónico.
    final presRows = await conn.execute(
      Sql.named('''
        SELECT id, tipo_presentacion_id, nombre, factor_a_base, es_presentacion_base,
               codigo_barras, precio, activo
        FROM product_presentations
        WHERE producto_id = ANY(@ids)
      '''),
      parameters: {'ids': ids},
    );
    final presentaciones = presRows.map((r) {
      final c = r.toColumnMap();
      return {
        'id': c['id'],
        'tipoPresentacionId': c['tipo_presentacion_id'],
        'nombre': c['nombre'],
        'factorABase': c['factor_a_base'],
        'esPresentacionBase': (c['es_presentacion_base'] as int) != 0,
        'codigoBarras': c['codigo_barras'] ?? '',
        'precio': c['precio'],
        'activo': (c['activo'] as int) != 0,
      };
    }).toList();

    // Reafirmar el alta del canónico.
    await _guardarYAplicar(
      conn,
      EventoHub(
        seq: 0,
        id: 'productUpserted:merge-reafirma:$canonico',
        tiendaId: tiendaId,
        dispositivoId: 'backfill-codigo-interno',
        tipo: 'productUpserted',
        payload: {
          'id': canonico,
          'nombre': datosCanonico['nombre'],
          'codigoBarras': datosCanonico['codigo_barras'] ?? '',
          'precioBase': datosCanonico['precio_base'],
          'unidadMedida': datosCanonico['unidad_medida'],
          'rutaImagen': datosCanonico['ruta_imagen'] ?? '',
          'activo': true,
          'tiendaId': tiendaId,
          'moduloVertical': datosCanonico['modulo_vertical'],
          'categoriaId': datosCanonico['categoria_id'],
          'piezasPorCaja': datosCanonico['piezas_por_caja'],
          'proveedorId': datosCanonico['proveedor_id'],
          'unidadesPorBulto': datosCanonico['unidades_por_bulto'],
          'notas': datosCanonico['notas'] ?? '',
          'costoUnitario': datosCanonico['costo_unitario'],
          'permiteStockNegativo':
              (datosCanonico['permite_stock_negativo'] as int) != 0,
          'favoritoCaja': (datosCanonico['favorito_caja'] as int) != 0,
        },
        creadoEn: DateTime.now().toUtc(),
      ),
    );

    if (presentaciones.isNotEmpty) {
      await _guardarYAplicar(
        conn,
        EventoHub(
          seq: 0,
          id: 'productPresentationsReplaced:merge:$canonico',
          tiendaId: tiendaId,
          dispositivoId: 'backfill-codigo-interno',
          tipo: 'productPresentationsReplaced',
          payload: {
            'productoId': canonico,
            'presentaciones': presentaciones,
          },
          creadoEn: DateTime.now().toUtc(),
        ),
      );
    }

    // Desactivar perdedores (alias inactivos, con codigo_barras vacío para no
    // pelearse por el slot del índice único cuando el canónico reciba su
    // código interno abajo).
    for (final loser in perdedores) {
      final row = await conn.execute(
        Sql.named('''
          SELECT nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
                 tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
                 proveedor_id, unidades_por_bulto, notas, costo_unitario,
                 permite_stock_negativo, favorito_caja
          FROM products WHERE id = @id
        '''),
        parameters: {'id': loser},
      );
      final c = row.first.toColumnMap();
      await _guardarYAplicar(
        conn,
        EventoHub(
          seq: 0,
          id: 'productUpserted:merge-desactiva:$loser',
          tiendaId: c['tienda_id'] as String? ?? tiendaId,
          dispositivoId: 'backfill-codigo-interno',
          tipo: 'productUpserted',
          payload: {
            'id': loser,
            'nombre': c['nombre'],
            'codigoBarras': '',
            'precioBase': c['precio_base'],
            'unidadMedida': c['unidad_medida'],
            'rutaImagen': c['ruta_imagen'],
            'activo': false,
            'tiendaId': c['tienda_id'],
            'moduloVertical': c['modulo_vertical'],
            'categoriaId': c['categoria_id'],
            'piezasPorCaja': c['piezas_por_caja'],
            'proveedorId': c['proveedor_id'],
            'unidadesPorBulto': c['unidades_por_bulto'],
            'notas': c['notas'],
            'costoUnitario': c['costo_unitario'],
            'permiteStockNegativo':
                (c['permite_stock_negativo'] as int) != 0,
            'favoritoCaja': (c['favorito_caja'] as int) != 0,
          },
          creadoEn: DateTime.now().toUtc(),
        ),
      );
    }
  }

  print('\nGrupos duplicados: $totalGrupos');
  print('Productos a desactivar (alias): $totalDesactivados');

  // ---------------------------------------------------------------------------
  // Fase 2: backfill de código interno para el catálogo activo sin código.
  // ---------------------------------------------------------------------------
  print('\n--- Fase 2: asignando código interno idempotente ---');
  final candidatos = await conn.execute('''
    SELECT id, nombre, tienda_id, precio_base, unidad_medida, ruta_imagen,
           modulo_vertical, categoria_id, piezas_por_caja, proveedor_id,
           unidades_por_bulto, notas, costo_unitario, permite_stock_negativo,
           favorito_caja
    FROM products
    WHERE activo = 1
      AND (codigo_barras IS NULL OR codigo_barras = '')
      AND trim(nombre) <> ''
      AND trim(nombre) <> 'Producto'
      AND COALESCE(trim(notas), '') <> '__stub_fk__'
    ORDER BY tienda_id, nombre
  ''');

  // Verificación previa de colisiones: el resultado de la fase 1 debería
  // haber dejado un único activo por nombre y tienda, pero por defensa en
  // profundidad se detecta cualquier colisión que quedara y se salta el
  // producto (queda como lo estaba, sin código, para no romper la unicidad).
  final ocupadosPorTienda = <String, Set<String>>{};
  final ocupadosReal = await conn.execute('''
    SELECT tienda_id, lower(codigo_barras) AS codigo
    FROM products
    WHERE activo = 1
      AND codigo_barras IS NOT NULL
      AND codigo_barras <> ''
  ''');
  for (final r in ocupadosReal) {
    final t = r[0] as String;
    final c = r[1] as String;
    ocupadosPorTienda.putIfAbsent(t, () => <String>{}).add(c);
  }

  var totalBackfill = 0;
  var totalColisiones = 0;
  for (final row in candidatos) {
    final r = row.toColumnMap();
    final id = r['id'] as String;
    final nombre = (r['nombre'] as String? ?? '').trim();
    final tiendaId = r['tienda_id'] as String;
    final codigoInterno = generarCodigoInternoDesdeNombre(nombre);
    if (codigoInterno.isEmpty) {
      continue;
    }
    final ocupados = ocupadosPorTienda.putIfAbsent(tiendaId, () => <String>{});
    if (ocupados.contains(codigoInterno.toLowerCase())) {
      totalColisiones++;
      print('  colisión: "$nombre" en $tiendaId ya tiene ese código (id=$id)');
      continue;
    }
    ocupados.add(codigoInterno.toLowerCase());
    totalBackfill++;
    print('  $id "$nombre" (tienda $tiendaId) -> $codigoInterno');

    if (!aplicar) continue;

    await _guardarYAplicar(
      conn,
      EventoHub(
        seq: 0,
        id: 'productUpserted:backfill-cint:$id',
        tiendaId: tiendaId,
        dispositivoId: 'backfill-codigo-interno',
        tipo: 'productUpserted',
        payload: {
          'id': id,
          'nombre': nombre,
          'codigoBarras': codigoInterno,
          'precioBase': r['precio_base'],
          'unidadMedida': r['unidad_medida'],
          'rutaImagen': r['ruta_imagen'] ?? '',
          'activo': true,
          'tiendaId': tiendaId,
          'moduloVertical': r['modulo_vertical'],
          'categoriaId': r['categoria_id'],
          'piezasPorCaja': r['piezas_por_caja'],
          'proveedorId': r['proveedor_id'],
          'unidadesPorBulto': r['unidades_por_bulto'],
          'notas': r['notas'] ?? '',
          'costoUnitario': r['costo_unitario'],
          'permiteStockNegativo': (r['permite_stock_negativo'] as int) != 0,
          'favoritoCaja': (r['favorito_caja'] as int) != 0,
        },
        creadoEn: DateTime.now().toUtc(),
      ),
    );
  }

  print('\n=== Resumen ===');
  print('Fase 1 · grupos duplicados por nombre: $totalGrupos');
  print('Fase 1 · productos desactivados (alias): $totalDesactivados');
  print('Fase 2 · productos con código interno asignado: $totalBackfill');
  print('Fase 2 · colisiones saltadas (revisar manualmente): $totalColisiones');
  if (!aplicar) {
    print('\nDRY-RUN: nada se escribió. Corre con --apply para ejecutar.');
  }
  await conn.close();
}

Future<void> _guardarYAplicar(Connection conn, EventoHub evento) async {
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
