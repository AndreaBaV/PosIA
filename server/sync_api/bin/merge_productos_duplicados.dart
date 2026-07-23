/// Fusiona productos ACTIVOS con el mismo nombre normalizado (por tienda) en un
/// único canónico, para que el catálogo no muestre duplicados — sin perder nada:
///
///  - Canónico = el que tiene más presentaciones (mejor señal del "real");
///    empate -> más stock -> id menor (determinista: converge igual en todos
///    los dispositivos).
///  - Las presentaciones de los perdedores se MUEVEN al canónico (unión, vía
///    productPresentationsReplaced, que ya es aditivo).
///  - Los perdedores se DESACTIVAN (activo=0) y quedan como alias, para no
///    romper la llave foránea de ventas/stock que ya los referencian.
///  - Todo se aplica vía ProyectorEventosPostgres con id determinista, así se
///    propaga por pull a los dispositivos. Re-ejecutable sin duplicar nada.
///
/// URL: usa MERGE_DB_URL si está, si no la DATABASE_URL del .env.
/// DRY-RUN por defecto. Pasar --apply para escribir.
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

  // Grupos de productos activos con el mismo nombre normalizado, por tienda.
  final grupos = await conn.execute('''
    SELECT lower(trim(nombre)) AS clave, array_agg(id) AS ids
    FROM products
    WHERE activo = 1
    GROUP BY lower(trim(nombre))
    HAVING COUNT(*) > 1
    ORDER BY clave
  ''');

  if (grupos.isEmpty) {
    print('\nNo hay productos duplicados por nombre. Nada que fusionar.');
    await conn.close();
    return;
  }

  var totalGrupos = 0;
  var totalDesactivados = 0;
  var totalPresMovidas = 0;

  for (final fila in grupos) {
    final clave = fila[0] as String;
    final ids = (fila[1] as List).cast<String>();

    // Métricas por producto para elegir canónico determinista.
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
        if (mb.$1 != ma.$1) return mb.$1.compareTo(ma.$1); // más presentaciones
        if (mb.$2 != ma.$2) return mb.$2.compareTo(ma.$2); // más stock
        return a.compareTo(b); // id menor
      });
    final canonico = ordenados.first;
    final perdedores = ordenados.skip(1).toList();
    totalGrupos++;
    // Catálogo unificado: los duplicados pueden venir de distintas tiendas
    // (p. ej. la misma lista de granel importada por separado para cada una).
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
    print('\n"$clave"');
    print('  canónico=$canonico (tienda $tiendaId)  pres=${metricas[canonico]!.$1}');

    // Unión de presentaciones (canónico + perdedores) para reasignar al canónico.
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

    for (final loser in perdedores) {
      print('  perdedor=$loser  pres=${metricas[loser]!.$1}  -> desactivar (alias)');
    }
    totalDesactivados += perdedores.length;
    totalPresMovidas += presentaciones.where((p) {
      // cuenta las que hoy no están en el canónico
      return true;
    }).length;

    if (!aplicar) continue;

    // 0) Reafirmar el alta del canónico. Sin esto, un dispositivo que nunca
    // haya recibido el productUpserted original de este id (p. ej. porque el
    // pull normal excluye los eventos propios de su creador, o porque su
    // copia local se perdió) lo crea como stub genérico "Producto" al aplicar
    // el evento de presentaciones de abajo — tapando el nombre real.
    await _guardarYAplicar(
      conn,
      EventoHub(
        seq: 0,
        id: 'productUpserted:merge-reafirma:$canonico',
        tiendaId: tiendaId,
        dispositivoId: 'merge-neon',
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
          'permiteStockNegativo': (datosCanonico['permite_stock_negativo'] as int) != 0,
          'favoritoCaja': (datosCanonico['favorito_caja'] as int) != 0,
        },
        creadoEn: DateTime.now().toUtc(),
      ),
    );

    // 1) Mover/unir presentaciones al canónico (aditivo).
    if (presentaciones.isNotEmpty) {
      await _guardarYAplicar(
        conn,
        EventoHub(
          seq: 0,
          id: 'productPresentationsReplaced:merge:$canonico',
          tiendaId: tiendaId,
          dispositivoId: 'merge-neon',
          tipo: 'productPresentationsReplaced',
          payload: {'productoId': canonico, 'presentaciones': presentaciones},
          creadoEn: DateTime.now().toUtc(),
        ),
      );
    }

    // 2) Desactivar cada perdedor (queda como alias inactivo; FK a salvo).
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
          dispositivoId: 'merge-neon',
          tipo: 'productUpserted',
          payload: {
            'id': loser,
            'nombre': c['nombre'],
            'codigoBarras': '', // vacío: no reactiva el índice único
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
            'permiteStockNegativo': (c['permite_stock_negativo'] as int) != 0,
            'favoritoCaja': (c['favorito_caja'] as int) != 0,
          },
          creadoEn: DateTime.now().toUtc(),
        ),
      );
    }
  }

  print('\n=== Resumen ===');
  print('Grupos duplicados: $totalGrupos');
  print('Productos a desactivar (alias): $totalDesactivados');
  if (aplicar) {
    print('Presentaciones reunidas en canónicos: $totalPresMovidas');
  } else {
    print('DRY-RUN: nada se escribió. Corre con --apply para ejecutar.');
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
