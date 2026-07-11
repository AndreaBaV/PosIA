/// Migracion v32→v33: reconstruye tablas SQLite con FOREIGN KEY (1FN/2FN/3FN).
///
/// Requisitos:
/// 1. Cola de sync vacia (todo proyectado en Neon).
/// 2. Limpieza de huerfanos antes de activar FKs.
/// 3. Snapshots historicos (`nombre_producto`, etc.) se conservan sin FK.
library;

import 'package:sqflite/sqflite.dart';

import 'migracion_requiere_sync_hub.dart';

/// Reconstruye el esquema operativo con integridad referencial real.
abstract final class MigracionIntegridadReferencial {
	MigracionIntegridadReferencial._();

	/// Aplica v33. Lanza [MigracionRequiereSyncHubException] si hay pendientes.
	static Future<void> aplicar(Database base) async {
		await _exigirSyncHubLimpio(base);
		await base.execute('PRAGMA foreign_keys = OFF');
		try {
			await _limpiarHuerfanos(base);
			await _reconstruirTablasConFk(base);
			await base.execute('PRAGMA foreign_keys = ON');
			final violaciones = await base.rawQuery('PRAGMA foreign_key_check');
			if (violaciones.isNotEmpty) {
				throw StateError(
					'Integridad referencial fallida tras rebuild: '
					'${violaciones.length} violacion(es). Ejemplo: ${violaciones.first}',
				);
			}
		} catch (e) {
			await base.execute('PRAGMA foreign_keys = ON');
			rethrow;
		}
		await _asegurarIndicesPostRebuild(base);
	}

	/// True si ya hay FKs en tablas hijas (instalacion fresca con REFERENCES).
	static Future<bool> yaAplicada(Database base) async {
		final fks = await base.rawQuery('PRAGMA foreign_key_list(sale_lines)');
		final aVenta = fks.any((f) => f['table'] == 'sales');
		final aProducto = fks.any((f) => f['table'] == 'products');
		return aVenta && aProducto;
	}

	static Future<void> _exigirSyncHubLimpio(Database base) async {
		final filas = await base.rawQuery('''
			SELECT COUNT(*) AS c
			FROM sync_event_queue
			WHERE estado IN ('pendiente', 'error')
		''');
		final count = (filas.first['c'] as int?) ?? 0;
		if (count > 0) {
			throw MigracionRequiereSyncHubException(count);
		}
	}

	/// Nullifica o borra referencias rotas (3FN: solo ids; snapshots intactos).
	static Future<void> _limpiarHuerfanos(Database base) async {
		Future<void> sql(String tabla, String sentencia) async {
			if (!await _existeTabla(base, tabla)) {
				return;
			}
			await base.execute(sentencia);
		}

		Future<void> sqlConPadre(
			String tabla,
			String padre,
			String sentencia,
		) async {
			if (!await _existeTabla(base, tabla) ||
				!await _existeTabla(base, padre)) {
				return;
			}
			await base.execute(sentencia);
		}

		// products → padres opcionales
		await sqlConPadre('products', 'categories', '''
			UPDATE products SET categoria_id = NULL
			WHERE categoria_id IS NOT NULL
				AND categoria_id NOT IN (SELECT id FROM categories)
		''');
		await sqlConPadre('products', 'proveedores', '''
			UPDATE products SET proveedor_id = NULL
			WHERE proveedor_id IS NOT NULL
				AND proveedor_id NOT IN (SELECT id FROM proveedores)
		''');
		await sqlConPadre('products', 'stores', '''
			DELETE FROM products
			WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');

		await sqlConPadre('customers', 'price_lists', '''
			UPDATE customers SET lista_precios_id = NULL
			WHERE lista_precios_id IS NOT NULL
				AND lista_precios_id NOT IN (SELECT id FROM price_lists)
		''');

		await sqlConPadre('usuarios', 'stores', '''
			UPDATE usuarios SET tienda_id = NULL
			WHERE tienda_id IS NOT NULL AND tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sqlConPadre('usuarios', 'roles_personalizados', '''
			UPDATE usuarios SET rol_personalizado_id = NULL
			WHERE rol_personalizado_id IS NOT NULL
				AND rol_personalizado_id NOT IN (SELECT id FROM roles_personalizados)
		''');
		await sqlConPadre('vendedores', 'stores', '''
			UPDATE vendedores SET tienda_id = NULL
			WHERE tienda_id IS NOT NULL AND tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sqlConPadre('roles_personalizados', 'stores', '''
			UPDATE roles_personalizados SET tienda_id = NULL
			WHERE tienda_id IS NOT NULL AND tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sqlConPadre('almacenes', 'stores', '''
			UPDATE almacenes SET tienda_id = NULL
			WHERE tienda_id IS NOT NULL AND tienda_id NOT IN (SELECT id FROM stores)
		''');

		// Documentos → padres
		await sqlConPadre('sales', 'customers', '''
			UPDATE sales SET cliente_id = NULL
			WHERE cliente_id IS NOT NULL AND cliente_id NOT IN (SELECT id FROM customers)
		''');
		await sqlConPadre('sales', 'vendedores', '''
			UPDATE sales SET vendedor_id = NULL
			WHERE vendedor_id IS NOT NULL AND vendedor_id NOT IN (SELECT id FROM vendedores)
		''');
		await sqlConPadre('sales', 'cash_shifts', '''
			UPDATE sales SET turno_caja_id = NULL
			WHERE turno_caja_id IS NOT NULL AND turno_caja_id NOT IN (SELECT id FROM cash_shifts)
		''');
		await sqlConPadre('sales', 'stores', '''
			DELETE FROM sales WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');

		await sqlConPadre('sale_lines', 'sales', '''
			DELETE FROM sale_lines WHERE venta_id NOT IN (SELECT id FROM sales)
		''');
		await sqlConPadre('sale_lines', 'products', '''
			DELETE FROM sale_lines WHERE producto_id NOT IN (SELECT id FROM products)
		''');
		await sqlConPadre('sale_lines', 'pharmacy_lots', '''
			UPDATE sale_lines SET lote_id = NULL
			WHERE lote_id IS NOT NULL AND lote_id NOT IN (SELECT id FROM pharmacy_lots)
		''');

		await _borrarHuerfanosLineas(
			base,
			tabla: 'order_lines',
			fkPadre: 'pedido_id',
			tablaPadre: 'orders',
		);
		await _borrarHuerfanosLineas(
			base,
			tabla: 'quote_lines',
			fkPadre: 'cotizacion_id',
			tablaPadre: 'quotes',
		);
		await _borrarHuerfanosLineas(
			base,
			tabla: 'purchase_lines',
			fkPadre: 'compra_id',
			tablaPadre: 'purchases',
		);
		await _borrarHuerfanosLineas(
			base,
			tabla: 'transfer_lines',
			fkPadre: 'transfer_id',
			tablaPadre: 'transfers',
		);
		await _borrarHuerfanosLineas(
			base,
			tabla: 'held_ticket_lines',
			fkPadre: 'ticket_id',
			tablaPadre: 'held_tickets',
		);

		await sql('stock_levels', '''
			DELETE FROM stock_levels
			WHERE producto_id NOT IN (SELECT id FROM products)
				OR tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('stock_almacen', '''
			DELETE FROM stock_almacen
			WHERE producto_id NOT IN (SELECT id FROM products)
				OR almacen_id NOT IN (SELECT id FROM almacenes)
		''');
		await sql('wholesale_tiers', '''
			DELETE FROM wholesale_tiers
			WHERE producto_id NOT IN (SELECT id FROM products)
		''');
		await sql('product_variants', '''
			DELETE FROM product_variants
			WHERE producto_padre_id NOT IN (SELECT id FROM products)
		''');
		await sql('presentaciones_producto', '''
			DELETE FROM presentaciones_producto
			WHERE producto_id NOT IN (SELECT id FROM products)
		''');
		await sql('presentaciones_producto', '''
			UPDATE presentaciones_producto SET tipo_presentacion_id = NULL
			WHERE tipo_presentacion_id IS NOT NULL
				AND tipo_presentacion_id NOT IN (SELECT id FROM tipos_presentacion)
		''');
		await sql('price_list_items', '''
			DELETE FROM price_list_items
			WHERE lista_precios_id NOT IN (SELECT id FROM price_lists)
				OR producto_id NOT IN (SELECT id FROM products)
		''');
		await sql('customer_product_prices', '''
			DELETE FROM customer_product_prices
			WHERE cliente_id NOT IN (SELECT id FROM customers)
				OR producto_id NOT IN (SELECT id FROM products)
		''');
		await sql('customer_discounts', '''
			DELETE FROM customer_discounts
			WHERE cliente_id NOT IN (SELECT id FROM customers)
		''');
		await sql('customer_discounts', '''
			UPDATE customer_discounts SET producto_id = NULL
			WHERE producto_id IS NOT NULL
				AND producto_id NOT IN (SELECT id FROM products)
		''');
		await sql('lote_promocion_miembros', '''
			DELETE FROM lote_promocion_miembros
			WHERE lote_id NOT IN (SELECT id FROM lotes_promocion)
				OR producto_id NOT IN (SELECT id FROM products)
		''');
		await sql('pharmacy_lots', '''
			DELETE FROM pharmacy_lots
			WHERE producto_id NOT IN (SELECT id FROM products)
				OR tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('inventory_movements', '''
			DELETE FROM inventory_movements
			WHERE producto_id NOT IN (SELECT id FROM products)
				OR tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('inventory_movements', '''
			UPDATE inventory_movements SET proveedor_id = NULL
			WHERE proveedor_id IS NOT NULL
				AND proveedor_id NOT IN (SELECT id FROM proveedores)
		''');

		await sql('cash_shifts', '''
			DELETE FROM cash_shifts WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('transfers', '''
			DELETE FROM transfers
			WHERE tienda_origen_id NOT IN (SELECT id FROM stores)
				OR tienda_destino_id NOT IN (SELECT id FROM stores)
		''');
		await sql('purchases', '''
			DELETE FROM purchases
			WHERE tienda_id NOT IN (SELECT id FROM stores)
				OR proveedor_id NOT IN (SELECT id FROM proveedores)
		''');
		await sql('orders', '''
			DELETE FROM orders WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('orders', '''
			UPDATE orders SET cliente_id = NULL
			WHERE cliente_id IS NOT NULL AND cliente_id NOT IN (SELECT id FROM customers)
		''');
		await sql('orders', '''
			UPDATE orders SET venta_id = NULL
			WHERE venta_id IS NOT NULL AND venta_id NOT IN (SELECT id FROM sales)
		''');
		await sql('orders', '''
			UPDATE orders SET asignado_a_usuario_id = NULL
			WHERE asignado_a_usuario_id IS NOT NULL
				AND asignado_a_usuario_id NOT IN (SELECT id FROM usuarios)
		''');
		await sql('orders', '''
			UPDATE orders SET creado_por_usuario_id = NULL
			WHERE creado_por_usuario_id IS NOT NULL
				AND creado_por_usuario_id NOT IN (SELECT id FROM usuarios)
		''');
		await sql('quotes', '''
			DELETE FROM quotes WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('quotes', '''
			UPDATE quotes SET cliente_id = NULL
			WHERE cliente_id IS NOT NULL AND cliente_id NOT IN (SELECT id FROM customers)
		''');
		await sql('quotes', '''
			UPDATE quotes SET vendedor_id = NULL
			WHERE vendedor_id IS NOT NULL AND vendedor_id NOT IN (SELECT id FROM vendedores)
		''');
		await sql('held_tickets', '''
			DELETE FROM held_tickets WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('held_tickets', '''
			UPDATE held_tickets SET cliente_id = NULL
			WHERE cliente_id IS NOT NULL AND cliente_id NOT IN (SELECT id FROM customers)
		''');
		await sql('held_tickets', '''
			UPDATE held_tickets SET vendedor_id = NULL
			WHERE vendedor_id IS NOT NULL AND vendedor_id NOT IN (SELECT id FROM vendedores)
		''');
		await sql('held_ticket_lines', '''
			UPDATE held_ticket_lines SET lote_id = NULL
			WHERE lote_id IS NOT NULL AND lote_id NOT IN (SELECT id FROM pharmacy_lots)
		''');
		await sql('held_ticket_lines', '''
			DELETE FROM held_ticket_lines
			WHERE producto_id NOT IN (SELECT id FROM products)
		''');

		await sql('desafios_asistencia', '''
			DELETE FROM desafios_asistencia
			WHERE tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('registros_asistencia', '''
			DELETE FROM registros_asistencia
			WHERE tienda_id NOT IN (SELECT id FROM stores)
				OR usuario_id NOT IN (SELECT id FROM usuarios)
		''');
		await sql('registros_asistencia', '''
			UPDATE registros_asistencia SET desafio_id = NULL
			WHERE desafio_id IS NOT NULL
				AND desafio_id NOT IN (SELECT id FROM desafios_asistencia)
		''');
		await sql('empleado_perfil', '''
			DELETE FROM empleado_perfil
			WHERE usuario_id NOT IN (SELECT id FROM usuarios)
		''');
		await sql('periodos_nomina', '''
			DELETE FROM periodos_nomina
			WHERE tienda_id IS NOT NULL AND tienda_id NOT IN (SELECT id FROM stores)
		''');
		await sql('lineas_nomina', '''
			DELETE FROM lineas_nomina
			WHERE periodo_id NOT IN (SELECT id FROM periodos_nomina)
				OR usuario_id NOT IN (SELECT id FROM usuarios)
		''');
	}

	static Future<bool> _existeTabla(Database base, String tabla) async {
		final filas = await base.rawQuery(
			"SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
			[tabla],
		);
		return filas.isNotEmpty;
	}

	static Future<void> _borrarHuerfanosLineas(
		Database base, {
		required String tabla,
		required String fkPadre,
		required String tablaPadre,
	}) async {
		if (!await _existeTabla(base, tabla)) {
			return;
		}
		await base.execute('''
			DELETE FROM $tabla WHERE $fkPadre NOT IN (SELECT id FROM $tablaPadre)
		''');
		await base.execute('''
			DELETE FROM $tabla WHERE producto_id NOT IN (SELECT id FROM products)
		''');
	}

	static Future<void> _reconstruirTablasConFk(Database base) async {
		// Orden: padres antes que hijos al CREATE; al DROP usamos OFF.
		await _rebuild(
			base,
			tabla: 'products',
			ddl: '''
				CREATE TABLE products_fk (
					id TEXT PRIMARY KEY,
					nombre TEXT NOT NULL,
					codigo_barras TEXT NOT NULL,
					precio_base REAL NOT NULL,
					unidad_medida TEXT NOT NULL,
					ruta_imagen TEXT NOT NULL,
					activo INTEGER NOT NULL,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					modulo_vertical TEXT NOT NULL DEFAULT 'general',
					categoria_id TEXT REFERENCES categories(id),
					piezas_por_caja INTEGER,
					proveedor_id TEXT REFERENCES proveedores(id),
					unidades_por_bulto INTEGER,
					notas TEXT NOT NULL DEFAULT '',
					costo_unitario REAL NOT NULL DEFAULT 0,
					favorito_caja INTEGER NOT NULL DEFAULT 0,
					permite_stock_negativo INTEGER NOT NULL DEFAULT 1
				)
			''',
			columnas: '''
				id, nombre, codigo_barras, precio_base, unidad_medida, ruta_imagen,
				activo, tienda_id, modulo_vertical, categoria_id, piezas_por_caja,
				proveedor_id, unidades_por_bulto, notas, costo_unitario,
				favorito_caja, permite_stock_negativo
			''',
		);

		await _rebuild(
			base,
			tabla: 'customers',
			ddl: '''
				CREATE TABLE customers_fk (
					id TEXT PRIMARY KEY,
					nombre TEXT NOT NULL,
					lista_precios_id TEXT REFERENCES price_lists(id),
					credito_habilitado INTEGER NOT NULL,
					activo INTEGER NOT NULL,
					telefono TEXT NOT NULL DEFAULT '',
					email TEXT NOT NULL DEFAULT '',
					rfc TEXT NOT NULL DEFAULT '',
					direccion TEXT NOT NULL DEFAULT '',
					notas TEXT NOT NULL DEFAULT '',
					dias_credito INTEGER NOT NULL DEFAULT 0
				)
			''',
			columnas: '''
				id, nombre, lista_precios_id, credito_habilitado, activo,
				telefono, email, rfc, direccion, notas, dias_credito
			''',
		);

		// roles antes que usuarios (FK rol_personalizado_id).
		await _rebuild(
			base,
			tabla: 'roles_personalizados',
			ddl: '''
				CREATE TABLE roles_personalizados_fk (
					id TEXT PRIMARY KEY,
					nombre TEXT NOT NULL,
					descripcion TEXT NOT NULL DEFAULT '',
					permisos_json TEXT NOT NULL DEFAULT '[]',
					categorias_json TEXT NOT NULL DEFAULT '[]',
					activo INTEGER NOT NULL DEFAULT 1,
					tienda_id TEXT REFERENCES stores(id)
				)
			''',
			columnas: '''
				id, nombre, descripcion, permisos_json, categorias_json, activo, tienda_id
			''',
		);

		await _rebuild(
			base,
			tabla: 'usuarios',
			ddl: '''
				CREATE TABLE usuarios_fk (
					id TEXT PRIMARY KEY,
					nombre TEXT NOT NULL,
					codigo TEXT NOT NULL COLLATE NOCASE,
					pin_credencial TEXT NOT NULL,
					rol TEXT NOT NULL CHECK (rol IN ('administrador', 'supervisor', 'empleado')),
					tienda_id TEXT REFERENCES stores(id),
					rol_personalizado_id TEXT REFERENCES roles_personalizados(id),
					activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
					creado_en TEXT NOT NULL,
					actualizado_en TEXT NOT NULL,
					UNIQUE (codigo)
				)
			''',
			columnas: '''
				id, nombre, codigo, pin_credencial, rol, tienda_id,
				rol_personalizado_id, activo, creado_en, actualizado_en
			''',
		);

		await _rebuild(
			base,
			tabla: 'vendedores',
			ddl: '''
				CREATE TABLE vendedores_fk (
					id TEXT PRIMARY KEY,
					nombre TEXT NOT NULL,
					codigo TEXT NOT NULL,
					activo INTEGER NOT NULL,
					tienda_id TEXT REFERENCES stores(id)
				)
			''',
			columnas: 'id, nombre, codigo, activo, tienda_id',
		);

		await _rebuild(
			base,
			tabla: 'almacenes',
			ddl: '''
				CREATE TABLE almacenes_fk (
					id TEXT PRIMARY KEY,
					nombre TEXT NOT NULL,
					tienda_id TEXT REFERENCES stores(id),
					activo INTEGER NOT NULL DEFAULT 1,
					latitud REAL,
					longitud REAL,
					radio_metros REAL DEFAULT 150
				)
			''',
			columnas: 'id, nombre, tienda_id, activo, latitud, longitud, radio_metros',
		);

		await _rebuild(
			base,
			tabla: 'cash_shifts',
			ddl: '''
				CREATE TABLE cash_shifts_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					caja_id TEXT NOT NULL,
					vendedor_id TEXT,
					fondo_inicial REAL NOT NULL,
					total_efectivo REAL NOT NULL DEFAULT 0,
					total_tarjeta REAL NOT NULL DEFAULT 0,
					total_transferencia REAL NOT NULL DEFAULT 0,
					total_ventas REAL NOT NULL DEFAULT 0,
					cantidad_ventas INTEGER NOT NULL DEFAULT 0,
					abierto_en TEXT NOT NULL,
					cerrado_en TEXT,
					estado TEXT NOT NULL
				)
			''',
			columnas: '''
				id, tienda_id, caja_id, vendedor_id, fondo_inicial,
				total_efectivo, total_tarjeta, total_transferencia,
				total_ventas, cantidad_ventas, abierto_en, cerrado_en, estado
			''',
		);

		await _rebuild(
			base,
			tabla: 'sales',
			ddl: '''
				CREATE TABLE sales_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					caja_id TEXT NOT NULL,
					cliente_id TEXT REFERENCES customers(id),
					metodo_pago TEXT NOT NULL,
					total REAL NOT NULL,
					creada_en TEXT NOT NULL,
					vendedor_id TEXT REFERENCES vendedores(id),
					estado TEXT NOT NULL DEFAULT 'completada',
					turno_caja_id TEXT REFERENCES cash_shifts(id),
					descuento_ticket REAL NOT NULL DEFAULT 0,
					monto_efectivo REAL,
					monto_tarjeta REAL,
					monto_transferencia REAL,
					credito_dias INTEGER,
					credito_vence_en TEXT,
					credito_liquidado INTEGER NOT NULL DEFAULT 0,
					credito_liquidado_en TEXT
				)
			''',
			columnas: '''
				id, tienda_id, caja_id, cliente_id, metodo_pago, total, creada_en,
				vendedor_id, estado, turno_caja_id, descuento_ticket,
				monto_efectivo, monto_tarjeta, monto_transferencia,
				credito_dias, credito_vence_en, credito_liquidado, credito_liquidado_en
			''',
		);

		// Lotes antes que sale_lines / held_ticket_lines (FK lote_id).
		await _rebuild(
			base,
			tabla: 'pharmacy_lots',
			ddl: '''
				CREATE TABLE pharmacy_lots_fk (
					id TEXT PRIMARY KEY,
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					numero_lote TEXT NOT NULL,
					caduca_en TEXT NOT NULL,
					cantidad REAL NOT NULL,
					activo INTEGER NOT NULL
				)
			''',
			columnas: '''
				id, producto_id, tienda_id, numero_lote, caduca_en, cantidad, activo
			''',
		);

		await _rebuild(
			base,
			tabla: 'sale_lines',
			ddl: '''
				CREATE TABLE sale_lines_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					venta_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id),
					nombre_producto TEXT NOT NULL,
					cantidad REAL NOT NULL,
					precio_unitario REAL NOT NULL,
					regla_precio TEXT NOT NULL,
					lote_id TEXT REFERENCES pharmacy_lots(id),
					etiqueta_lote TEXT,
					descuento_linea REAL NOT NULL DEFAULT 0
				)
			''',
			columnas: '''
				id, venta_id, producto_id, nombre_producto, cantidad, precio_unitario,
				regla_precio, lote_id, etiqueta_lote, descuento_linea
			''',
		);

		await _rebuild(
			base,
			tabla: 'stock_levels',
			ddl: '''
				CREATE TABLE stock_levels_fk (
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					cantidad REAL NOT NULL,
					actualizado_en TEXT NOT NULL,
					stock_minimo REAL NOT NULL DEFAULT 0,
					PRIMARY KEY (producto_id, tienda_id)
				)
			''',
			columnas: 'producto_id, tienda_id, cantidad, actualizado_en, stock_minimo',
		);

		await _rebuild(
			base,
			tabla: 'stock_almacen',
			ddl: '''
				CREATE TABLE stock_almacen_fk (
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					almacen_id TEXT NOT NULL REFERENCES almacenes(id) ON DELETE CASCADE,
					cantidad REAL NOT NULL,
					actualizado_en TEXT NOT NULL,
					stock_minimo REAL NOT NULL DEFAULT 0,
					PRIMARY KEY (producto_id, almacen_id)
				)
			''',
			columnas: 'producto_id, almacen_id, cantidad, actualizado_en, stock_minimo',
		);

		await _rebuild(
			base,
			tabla: 'wholesale_tiers',
			ddl: '''
				CREATE TABLE wholesale_tiers_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					cantidad_minima REAL NOT NULL,
					precio_unitario REAL NOT NULL
				)
			''',
			columnas: 'id, producto_id, cantidad_minima, precio_unitario',
		);

		await _rebuild(
			base,
			tabla: 'product_variants',
			ddl: '''
				CREATE TABLE product_variants_fk (
					id TEXT PRIMARY KEY,
					producto_padre_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					nombre TEXT NOT NULL,
					sku TEXT NOT NULL,
					codigo_barras TEXT NOT NULL DEFAULT '',
					precio_base REAL NOT NULL,
					activo INTEGER NOT NULL
				)
			''',
			columnas: '''
				id, producto_padre_id, nombre, sku, codigo_barras, precio_base, activo
			''',
		);

		await _rebuild(
			base,
			tabla: 'presentaciones_producto',
			ddl: '''
				CREATE TABLE presentaciones_producto_fk (
					id TEXT PRIMARY KEY,
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					tipo_presentacion_id TEXT REFERENCES tipos_presentacion(id),
					nombre TEXT NOT NULL,
					factor_a_base REAL NOT NULL DEFAULT 1,
					es_presentacion_base INTEGER NOT NULL DEFAULT 0,
					codigo_barras TEXT NOT NULL DEFAULT '',
					precio REAL,
					activo INTEGER NOT NULL DEFAULT 1
				)
			''',
			columnas: '''
				id, producto_id, tipo_presentacion_id, nombre, factor_a_base,
				es_presentacion_base, codigo_barras, precio, activo
			''',
		);

		await _rebuild(
			base,
			tabla: 'price_list_items',
			ddl: '''
				CREATE TABLE price_list_items_fk (
					lista_precios_id TEXT NOT NULL REFERENCES price_lists(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					precio_unitario REAL NOT NULL,
					PRIMARY KEY (lista_precios_id, producto_id)
				)
			''',
			columnas: 'lista_precios_id, producto_id, precio_unitario',
		);

		await _rebuild(
			base,
			tabla: 'customer_product_prices',
			ddl: '''
				CREATE TABLE customer_product_prices_fk (
					cliente_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					precio_unitario REAL NOT NULL,
					PRIMARY KEY (cliente_id, producto_id)
				)
			''',
			columnas: 'cliente_id, producto_id, precio_unitario',
		);

		await _rebuild(
			base,
			tabla: 'customer_discounts',
			ddl: '''
				CREATE TABLE customer_discounts_fk (
					id TEXT PRIMARY KEY,
					cliente_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
					tipo TEXT NOT NULL,
					valor REAL NOT NULL,
					producto_id TEXT REFERENCES products(id),
					condicion TEXT NOT NULL,
					umbral REAL,
					activo INTEGER NOT NULL DEFAULT 1,
					descripcion TEXT NOT NULL DEFAULT ''
				)
			''',
			columnas: '''
				id, cliente_id, tipo, valor, producto_id, condicion, umbral, activo, descripcion
			''',
		);

		await _rebuild(
			base,
			tabla: 'lote_promocion_miembros',
			ddl: '''
				CREATE TABLE lote_promocion_miembros_fk (
					lote_id TEXT NOT NULL REFERENCES lotes_promocion(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
					PRIMARY KEY (lote_id, producto_id)
				)
			''',
			columnas: 'lote_id, producto_id',
		);

		await _rebuild(
			base,
			tabla: 'transfers',
			ddl: '''
				CREATE TABLE transfers_fk (
					id TEXT PRIMARY KEY,
					tienda_origen_id TEXT NOT NULL REFERENCES stores(id),
					tienda_destino_id TEXT NOT NULL REFERENCES stores(id),
					estado TEXT NOT NULL,
					solicitado_en TEXT NOT NULL,
					completado_en TEXT,
					notas TEXT NOT NULL DEFAULT ''
				)
			''',
			columnas: '''
				id, tienda_origen_id, tienda_destino_id, estado,
				solicitado_en, completado_en, notas
			''',
		);

		await _rebuild(
			base,
			tabla: 'transfer_lines',
			ddl: '''
				CREATE TABLE transfer_lines_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					transfer_id TEXT NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id),
					cantidad_solicitada REAL NOT NULL,
					cantidad_recibida REAL
				)
			''',
			columnas: '''
				id, transfer_id, producto_id, cantidad_solicitada, cantidad_recibida
			''',
		);

		await _rebuild(
			base,
			tabla: 'purchases',
			ddl: '''
				CREATE TABLE purchases_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					proveedor_id TEXT NOT NULL REFERENCES proveedores(id),
					fecha_compra TEXT NOT NULL,
					notas TEXT NOT NULL DEFAULT '',
					total REAL NOT NULL,
					creada_en TEXT NOT NULL,
					creado_por TEXT
				)
			''',
			columnas: '''
				id, tienda_id, proveedor_id, fecha_compra, notas, total, creada_en, creado_por
			''',
		);

		await _rebuild(
			base,
			tabla: 'purchase_lines',
			ddl: '''
				CREATE TABLE purchase_lines_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					compra_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id),
					nombre_producto TEXT NOT NULL,
					cantidad REAL NOT NULL,
					costo_unitario REAL NOT NULL,
					subtotal REAL NOT NULL
				)
			''',
			columnas: '''
				id, compra_id, producto_id, nombre_producto, cantidad, costo_unitario, subtotal
			''',
		);

		await _rebuild(
			base,
			tabla: 'orders',
			ddl: '''
				CREATE TABLE orders_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					cliente_id TEXT REFERENCES customers(id),
					nombre_entrega TEXT NOT NULL,
					telefono_entrega TEXT NOT NULL,
					direccion_entrega TEXT NOT NULL,
					es_credito INTEGER NOT NULL DEFAULT 0,
					credito_dias INTEGER,
					credito_vence_en TEXT,
					metodo_pago TEXT NOT NULL,
					total REAL NOT NULL,
					notas TEXT NOT NULL DEFAULT '',
					estado TEXT NOT NULL DEFAULT 'recibido',
					asignado_a_usuario_id TEXT REFERENCES usuarios(id),
					asignado_a_usuario_nombre TEXT,
					asignado_en TEXT,
					creado_en TEXT NOT NULL,
					creado_por_usuario_id TEXT REFERENCES usuarios(id),
					venta_id TEXT REFERENCES sales(id)
				)
			''',
			columnas: '''
				id, tienda_id, cliente_id, nombre_entrega, telefono_entrega, direccion_entrega,
				es_credito, credito_dias, credito_vence_en, metodo_pago, total, notas, estado,
				asignado_a_usuario_id, asignado_a_usuario_nombre, asignado_en,
				creado_en, creado_por_usuario_id, venta_id
			''',
		);

		await _rebuild(
			base,
			tabla: 'order_lines',
			ddl: '''
				CREATE TABLE order_lines_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					pedido_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id),
					nombre_producto TEXT NOT NULL,
					cantidad REAL NOT NULL,
					precio_unitario REAL NOT NULL,
					subtotal REAL NOT NULL
				)
			''',
			columnas: '''
				id, pedido_id, producto_id, nombre_producto, cantidad, precio_unitario, subtotal
			''',
		);

		await _rebuild(
			base,
			tabla: 'quotes',
			ddl: '''
				CREATE TABLE quotes_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					nombre TEXT NOT NULL DEFAULT '',
					cliente_id TEXT REFERENCES customers(id),
					nombre_cliente TEXT,
					total REAL NOT NULL,
					notas TEXT NOT NULL DEFAULT '',
					vigencia_dias INTEGER NOT NULL DEFAULT 15,
					creada_en TEXT NOT NULL,
					caja_id TEXT,
					vendedor_id TEXT REFERENCES vendedores(id)
				)
			''',
			columnas: '''
				id, tienda_id, nombre, cliente_id, nombre_cliente, total, notas,
				vigencia_dias, creada_en, caja_id, vendedor_id
			''',
		);

		await _rebuild(
			base,
			tabla: 'quote_lines',
			ddl: '''
				CREATE TABLE quote_lines_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					cotizacion_id TEXT NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id),
					nombre_producto TEXT NOT NULL,
					cantidad REAL NOT NULL,
					precio_unitario REAL NOT NULL,
					regla_precio TEXT NOT NULL DEFAULT 'precioBase',
					subtotal REAL NOT NULL
				)
			''',
			columnas: '''
				id, cotizacion_id, producto_id, nombre_producto, cantidad,
				precio_unitario, regla_precio, subtotal
			''',
		);

		await _rebuild(
			base,
			tabla: 'held_tickets',
			ddl: '''
				CREATE TABLE held_tickets_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					caja_id TEXT NOT NULL,
					cliente_id TEXT REFERENCES customers(id),
					nombre_cliente TEXT,
					vendedor_id TEXT REFERENCES vendedores(id),
					notas TEXT NOT NULL DEFAULT '',
					descuento_ticket REAL NOT NULL DEFAULT 0,
					total REAL NOT NULL,
					creado_en TEXT NOT NULL
				)
			''',
			columnas: '''
				id, tienda_id, caja_id, cliente_id, nombre_cliente, vendedor_id,
				notas, descuento_ticket, total, creado_en
			''',
		);

		await _rebuild(
			base,
			tabla: 'held_ticket_lines',
			ddl: '''
				CREATE TABLE held_ticket_lines_fk (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					ticket_id TEXT NOT NULL REFERENCES held_tickets(id) ON DELETE CASCADE,
					producto_id TEXT NOT NULL REFERENCES products(id),
					nombre_producto TEXT NOT NULL,
					cantidad REAL NOT NULL,
					precio_unitario REAL NOT NULL,
					regla_precio TEXT NOT NULL,
					lote_id TEXT REFERENCES pharmacy_lots(id),
					etiqueta_lote TEXT,
					descuento_linea REAL NOT NULL DEFAULT 0,
					codigo_barras TEXT NOT NULL DEFAULT '',
					unidad_medida TEXT NOT NULL DEFAULT 'pieza',
					modulo_vertical TEXT NOT NULL DEFAULT 'general',
					categoria_id TEXT
				)
			''',
			columnas: '''
				id, ticket_id, producto_id, nombre_producto, cantidad, precio_unitario,
				regla_precio, lote_id, etiqueta_lote, descuento_linea, codigo_barras,
				unidad_medida, modulo_vertical, categoria_id
			''',
		);

		await _rebuild(
			base,
			tabla: 'inventory_movements',
			ddl: '''
				CREATE TABLE inventory_movements_fk (
					id TEXT PRIMARY KEY,
					producto_id TEXT NOT NULL REFERENCES products(id),
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					tipo TEXT NOT NULL,
					cantidad REAL NOT NULL,
					cantidad_anterior REAL NOT NULL,
					cantidad_nueva REAL NOT NULL,
					motivo TEXT NOT NULL,
					referencia_id TEXT,
					proveedor_id TEXT REFERENCES proveedores(id),
					creado_en TEXT NOT NULL,
					creado_por TEXT
				)
			''',
			columnas: '''
				id, producto_id, tienda_id, tipo, cantidad, cantidad_anterior,
				cantidad_nueva, motivo, referencia_id, proveedor_id, creado_en, creado_por
			''',
		);

		await _rebuild(
			base,
			tabla: 'desafios_asistencia',
			ddl: '''
				CREATE TABLE desafios_asistencia_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					pin_hash TEXT NOT NULL,
					expira_en TEXT NOT NULL,
					creado_por TEXT NOT NULL,
					latitud REAL,
					longitud REAL,
					radio_metros REAL DEFAULT 150,
					activo INTEGER NOT NULL DEFAULT 1
				)
			''',
			columnas: '''
				id, tienda_id, pin_hash, expira_en, creado_por,
				latitud, longitud, radio_metros, activo
			''',
		);

		await _rebuild(
			base,
			tabla: 'registros_asistencia',
			ddl: '''
				CREATE TABLE registros_asistencia_fk (
					id TEXT PRIMARY KEY,
					usuario_id TEXT NOT NULL REFERENCES usuarios(id),
					tienda_id TEXT NOT NULL REFERENCES stores(id),
					entrada_en TEXT NOT NULL,
					salida_en TEXT,
					metodo TEXT NOT NULL,
					latitud REAL,
					longitud REAL,
					desafio_id TEXT REFERENCES desafios_asistencia(id)
				)
			''',
			columnas: '''
				id, usuario_id, tienda_id, entrada_en, salida_en, metodo,
				latitud, longitud, desafio_id
			''',
		);

		await _rebuild(
			base,
			tabla: 'empleado_perfil',
			ddl: '''
				CREATE TABLE empleado_perfil_fk (
					usuario_id TEXT PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
					tarifa_hora REAL NOT NULL DEFAULT 0,
					tipo_pago TEXT NOT NULL DEFAULT 'por_hora',
					actualizado_en TEXT NOT NULL
				)
			''',
			columnas: 'usuario_id, tarifa_hora, tipo_pago, actualizado_en',
		);

		await _rebuild(
			base,
			tabla: 'periodos_nomina',
			ddl: '''
				CREATE TABLE periodos_nomina_fk (
					id TEXT PRIMARY KEY,
					tienda_id TEXT REFERENCES stores(id),
					inicio_en TEXT NOT NULL,
					fin_en TEXT NOT NULL,
					estado TEXT NOT NULL,
					cerrado_en TEXT,
					cerrado_por TEXT
				)
			''',
			columnas: 'id, tienda_id, inicio_en, fin_en, estado, cerrado_en, cerrado_por',
		);

		await _rebuild(
			base,
			tabla: 'lineas_nomina',
			ddl: '''
				CREATE TABLE lineas_nomina_fk (
					id TEXT PRIMARY KEY,
					periodo_id TEXT NOT NULL REFERENCES periodos_nomina(id) ON DELETE CASCADE,
					usuario_id TEXT NOT NULL REFERENCES usuarios(id),
					horas_trabajadas REAL NOT NULL,
					tarifa_hora REAL NOT NULL,
					monto_bruto REAL NOT NULL,
					monto_neto REAL NOT NULL
				)
			''',
			columnas: '''
				id, periodo_id, usuario_id, horas_trabajadas, tarifa_hora, monto_bruto, monto_neto
			''',
		);
	}

	static Future<void> _rebuild(
		Database base, {
		required String tabla,
		required String ddl,
		required String columnas,
	}) async {
		final existe = await base.rawQuery(
			"SELECT name FROM sqlite_master WHERE type='table' AND name=?",
			[tabla],
		);
		if (existe.isEmpty) {
			return;
		}
		final temp = '${tabla}_fk';
		await base.execute('DROP TABLE IF EXISTS $temp');
		await base.execute(ddl);
		await base.execute('''
			INSERT INTO $temp ($columnas)
			SELECT $columnas FROM $tabla
		''');
		await base.execute('DROP TABLE $tabla');
		await base.execute('ALTER TABLE $temp RENAME TO $tabla');
	}

	static Future<void> _asegurarIndicesPostRebuild(Database base) async {
		Future<void> indice(String tabla, String sql) async {
			if (!await _existeTabla(base, tabla)) {
				return;
			}
			await base.execute(sql);
		}

		await indice(
			'products',
			'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(codigo_barras)',
		);
		await indice(
			'products',
			'''CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_tienda_activo
				ON products(tienda_id, codigo_barras)
				WHERE activo = 1 AND codigo_barras != '' ''',
		);
		await indice(
			'vendedores',
			'CREATE UNIQUE INDEX IF NOT EXISTS idx_vendedores_codigo ON vendedores(codigo)',
		);
		await indice(
			'usuarios',
			'CREATE INDEX IF NOT EXISTS idx_usuarios_tienda ON usuarios(tienda_id)',
		);
		await indice(
			'usuarios',
			'CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON usuarios(activo)',
		);
		await indice(
			'sale_lines',
			'CREATE INDEX IF NOT EXISTS idx_sale_lines_venta ON sale_lines(venta_id)',
		);
		await indice(
			'sale_lines',
			'CREATE INDEX IF NOT EXISTS idx_sale_lines_producto ON sale_lines(producto_id)',
		);
		await indice(
			'sales',
			'CREATE INDEX IF NOT EXISTS idx_sales_tienda_fecha ON sales(tienda_id, creada_en)',
		);
		await indice(
			'purchase_lines',
			'CREATE INDEX IF NOT EXISTS idx_purchase_lines_compra ON purchase_lines(compra_id)',
		);
		await indice(
			'order_lines',
			'CREATE INDEX IF NOT EXISTS idx_order_lines_pedido ON order_lines(pedido_id)',
		);
		await indice(
			'quote_lines',
			'CREATE INDEX IF NOT EXISTS idx_quote_lines_cotizacion ON quote_lines(cotizacion_id)',
		);
		await indice(
			'transfer_lines',
			'CREATE INDEX IF NOT EXISTS idx_transfer_lines_transfer ON transfer_lines(transfer_id)',
		);
		await indice(
			'wholesale_tiers',
			'CREATE INDEX IF NOT EXISTS idx_wholesale_tiers_producto ON wholesale_tiers(producto_id)',
		);
		await indice(
			'price_list_items',
			'CREATE INDEX IF NOT EXISTS idx_price_list_items_producto ON price_list_items(producto_id)',
		);
		await indice(
			'customer_discounts',
			'CREATE INDEX IF NOT EXISTS idx_customer_discounts_cliente ON customer_discounts(cliente_id)',
		);
		await indice(
			'pharmacy_lots',
			'CREATE INDEX IF NOT EXISTS idx_pharmacy_lots_producto ON pharmacy_lots(producto_id, tienda_id)',
		);
		await indice(
			'inventory_movements',
			'CREATE INDEX IF NOT EXISTS idx_inventory_movements_producto ON inventory_movements(producto_id, tienda_id, creado_en)',
		);
		await indice(
			'orders',
			'CREATE INDEX IF NOT EXISTS idx_orders_tienda_estado ON orders(tienda_id, estado, creado_en DESC)',
		);
		await indice(
			'orders',
			'CREATE INDEX IF NOT EXISTS idx_orders_empleado ON orders(asignado_a_usuario_id, estado)',
		);
		await indice(
			'held_tickets',
			'CREATE INDEX IF NOT EXISTS idx_held_tickets_tienda_caja ON held_tickets(tienda_id, caja_id, creado_en DESC)',
		);
	}
}
