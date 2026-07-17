/// Equivalente en el hub de `autoSanarCatalogoLocal()` (cliente): corrige
/// en Neon lo que un dispositivo desactualizado haya podido re-inyectar
/// antes de recibir el fix — tiendas placeholder (`esStubFk`: nombre
/// "Tienda" y direccion vacia) y categorias duplicadas por nombre.
///
/// Cada cambio se aplica via `ProyectorEventosPostgres` (misma ruta que un
/// evento normal) con id determinístico, para que se propague por pull a
/// los 18 dispositivos y el script sea re-ejecutable sin duplicar nada.
///
/// Por defecto corre en modo DRY-RUN. Pasar `--apply` para ejecutar.
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../lib/src/evento_hub.dart';
import '../lib/src/proyector_eventos_postgres.dart';

Future<void> main(List<String> args) async {
	final aplicar = args.contains('--apply');

	final envPath = File('.env');
	if (!envPath.existsSync()) {
		stderr.writeln('Falta .env con DATABASE_URL');
		exit(1);
	}
	final line = envPath
		.readAsLinesSync()
		.firstWhere((l) => l.startsWith('DATABASE_URL='));
	final uri = Uri.parse(line.substring('DATABASE_URL='.length).trim());
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

	print(aplicar ? '=== MODO APLICAR (escribe en Neon) ===' : '=== MODO DRY-RUN (no escribe nada) ===');

	// --- 1. Tiendas placeholder (esStubFk: nombre='Tienda' y direccion vacia) ---
	print('\n--- Tiendas placeholder ---');
	final stubs = await conn.execute('''
		SELECT id, nombre FROM stores
		WHERE activa = 1 AND nombre = 'Tienda' AND trim(coalesce(direccion, '')) = ''
	''');
	if (stubs.isEmpty) {
		print('  ninguna activa.');
	}
	for (final fila in stubs) {
		final id = fila[0] as String;
		print('  desactivar tienda: $id');
		if (aplicar) {
			final evento = EventoHub(
				seq: 0,
				id: 'storeUpserted:heal:$id',
				tiendaId: id,
				dispositivoId: 'heal-neon',
				tipo: 'storeUpserted',
				payload: {'id': id, 'nombre': 'Tienda', 'direccion': '', 'activa': false},
				creadoEn: DateTime.now().toUtc(),
			);
			await _guardarYAplicar(conn, evento);
		}
	}

	// --- 2. Categorias duplicadas por nombre normalizado ---
	print('\n--- Categorias duplicadas ---');
	final grupos = await conn.execute('''
		SELECT lower(trim(nombre)) AS clave, array_agg(id ORDER BY (id LIKE 'cat-%') DESC, id) AS ids
		FROM categories
		WHERE activa = 1
		GROUP BY lower(trim(nombre))
		HAVING COUNT(*) > 1
		ORDER BY clave
	''');
	if (grupos.isEmpty) {
		print('  ninguna duplicada.');
	}
	var totalProductosReasignados = 0;
	var totalCategoriasDesactivadas = 0;
	for (final fila in grupos) {
		final clave = fila[0] as String;
		final ids = (fila[1] as List).cast<String>();
		final canonico = ids.first;
		final duplicados = ids.skip(1).toList();
		print('  "$clave": canónico=$canonico, duplicados=$duplicados');

		final filaCanonica = await conn.execute(
			Sql.named('SELECT nombre, icono, color_hex, orden FROM categories WHERE id = @id'),
			parameters: {'id': canonico},
		);
		final canonicaCols = filaCanonica.first.toColumnMap();

		for (final dupId in duplicados) {
			final productos = await conn.execute(
				Sql.named('''
					SELECT id, nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
						activo, tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
						proveedor_id, unidades_por_bulto, notas, costo_unitario,
						permite_stock_negativo, favorito_caja
					FROM products WHERE categoria_id = @dupId
				'''),
				parameters: {'dupId': dupId},
			);
			print('    $dupId: ${productos.length} productos a reasignar');

			if (aplicar) {
				for (final p in productos) {
					final c = p.toColumnMap();
					final payload = <String, Object?>{
						'id': c['id'],
						'nombre': c['nombre'],
						'codigoBarras': c['codigo_barras'],
						'precioBase': c['precio_base'],
						'unidadMedida': c['unidad_medida'],
						'rutaImagen': c['ruta_imagen'],
						'activo': (c['activo'] as int) != 0,
						'tiendaId': c['tienda_id'],
						'moduloVertical': c['modulo_vertical'],
						'categoriaId': canonico,
						'piezasPorCaja': c['piezas_por_caja'],
						'proveedorId': c['proveedor_id'],
						'unidadesPorBulto': c['unidades_por_bulto'],
						'notas': c['notas'],
						'costoUnitario': c['costo_unitario'],
						'permiteStockNegativo': (c['permite_stock_negativo'] as int) != 0,
						'favoritoCaja': (c['favorito_caja'] as int) != 0,
					};
					final evento = EventoHub(
						seq: 0,
						id: 'productUpserted:${c['id']}',
						tiendaId: c['tienda_id'] as String? ?? '',
						dispositivoId: 'heal-neon',
						tipo: 'productUpserted',
						payload: payload,
						creadoEn: DateTime.now().toUtc(),
					);
					await _guardarYAplicar(conn, evento);
				}
				totalProductosReasignados += productos.length;

				final eventoCat = EventoHub(
					seq: 0,
					id: 'categoryUpserted:$dupId',
					tiendaId: '',
					dispositivoId: 'heal-neon',
					tipo: 'categoryUpserted',
					payload: {
						'id': dupId,
						'nombre': canonicaCols['nombre'],
						'icono': canonicaCols['icono'],
						'colorHex': canonicaCols['color_hex'],
						'orden': canonicaCols['orden'],
						'activa': false,
					},
					creadoEn: DateTime.now().toUtc(),
				);
				await _guardarYAplicar(conn, eventoCat);
				totalCategoriasDesactivadas++;
			}
		}
	}

	print('\n=== Resumen ===');
	print('Tiendas placeholder: ${stubs.length}');
	print('Grupos de categorías duplicadas: ${grupos.length}');
	if (aplicar) {
		print('Productos reasignados: $totalProductosReasignados');
		print('Categorías desactivadas: $totalCategoriasDesactivadas');
	} else {
		print('DRY-RUN: nada se escribió. Vuelve a correr con --apply para ejecutar.');
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
