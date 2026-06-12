/// Migraciones incrementales del esquema SQLite POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:sqflite/sqflite.dart';

/// Aplica cambios de esquema entre versiones.
class MigracionesEsquema {
	MigracionesEsquema._();

	/// Agrega piezas por caja para resolucion de comandos de voz.
	static Future<void> migrarVersion3A4(Database base) async {
		await base.execute('ALTER TABLE products ADD COLUMN piezas_por_caja INTEGER');
	}

	/// Campos extendidos v6.1: clientes, proveedores, productos.
	static Future<void> migrarVersion4A5(Database base) async {
		await _agregarColumnaSiNoExiste(base, 'customers', 'telefono', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'customers', 'email', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'customers', 'rfc', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'customers', 'direccion', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'customers', 'notas', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'proveedores', 'email', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'proveedores', 'rfc', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'proveedores', 'direccion', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'proveedores', 'notas', 'TEXT NOT NULL DEFAULT ""');
		await _agregarColumnaSiNoExiste(base, 'proveedores', 'dias_credito', 'INTEGER NOT NULL DEFAULT 0');
		await _agregarColumnaSiNoExiste(base, 'products', 'proveedor_id', 'TEXT');
		await _agregarColumnaSiNoExiste(base, 'products', 'unidades_por_bulto', 'INTEGER');
		await _agregarColumnaSiNoExiste(base, 'products', 'notas', 'TEXT NOT NULL DEFAULT ""');
	}

	static Future<void> _agregarColumnaSiNoExiste(
		Database base,
		String tabla,
		String columna,
		String definicion,
	) async {
		final info = await base.rawQuery('PRAGMA table_info($tabla)');
		for (final fila in info) {
			if (fila['name'] == columna) {
				return;
			}
		}
		await base.execute('ALTER TABLE $tabla ADD COLUMN $columna $definicion');
	}

	/// Ejecuta migracion de version 2 a version 3.
	///
	/// [base] Conexion SQLite activa.
	static Future<void> migrarVersion2A3(Database base) async {
		await crearTablasOperaciones(base);
		await base.execute('ALTER TABLE products ADD COLUMN categoria_id TEXT');
		await base.execute(
			"ALTER TABLE sales ADD COLUMN vendedor_id TEXT",
		);
		await base.execute(
			"ALTER TABLE sales ADD COLUMN estado TEXT NOT NULL DEFAULT 'completada'",
		);
		await base.execute('ALTER TABLE sales ADD COLUMN turno_caja_id TEXT');
		await base.execute(
			'ALTER TABLE stock_levels ADD COLUMN stock_minimo REAL NOT NULL DEFAULT 0',
		);
	}

	/// Crea tablas operativas de POS v3.
	///
	/// [base] Conexion SQLite activa.
	static Future<void> crearTablasOperaciones(Database base) async {
		await base.execute('''
			CREATE TABLE categories (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				icono TEXT NOT NULL DEFAULT 'shopping_basket',
				color_hex TEXT NOT NULL DEFAULT '#4CAF50',
				orden INTEGER NOT NULL DEFAULT 0,
				activa INTEGER NOT NULL DEFAULT 1
			)
		''');
		await base.execute('''
			CREATE TABLE vendedores (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL,
				activo INTEGER NOT NULL
			)
		''');
		await base.execute('''
			CREATE TABLE proveedores (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				contacto TEXT NOT NULL DEFAULT '',
				telefono TEXT NOT NULL DEFAULT '',
				activo INTEGER NOT NULL,
				email TEXT NOT NULL DEFAULT '',
				rfc TEXT NOT NULL DEFAULT '',
				direccion TEXT NOT NULL DEFAULT '',
				notas TEXT NOT NULL DEFAULT '',
				dias_credito INTEGER NOT NULL DEFAULT 0
			)
		''');
		await base.execute('''
			CREATE TABLE cash_shifts (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
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
		''');
		await base.execute('''
			CREATE TABLE inventory_movements (
				id TEXT PRIMARY KEY,
				producto_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				tipo TEXT NOT NULL,
				cantidad REAL NOT NULL,
				cantidad_anterior REAL NOT NULL,
				cantidad_nueva REAL NOT NULL,
				motivo TEXT NOT NULL,
				referencia_id TEXT,
				proveedor_id TEXT,
				creado_en TEXT NOT NULL,
				creado_por TEXT
			)
		''');
		await base.execute('''
			CREATE INDEX idx_inventory_movements_producto
			ON inventory_movements(producto_id, tienda_id, creado_en)
		''');
		await base.execute('''
			CREATE TABLE transfers (
				id TEXT PRIMARY KEY,
				tienda_origen_id TEXT NOT NULL,
				tienda_destino_id TEXT NOT NULL,
				estado TEXT NOT NULL,
				solicitado_en TEXT NOT NULL,
				completado_en TEXT,
				notas TEXT NOT NULL DEFAULT ''
			)
		''');
		await base.execute('''
			CREATE TABLE transfer_lines (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				transfer_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				cantidad_solicitada REAL NOT NULL,
				cantidad_recibida REAL
			)
		''');
		await base.execute('''
			CREATE TABLE product_variants (
				id TEXT PRIMARY KEY,
				producto_padre_id TEXT NOT NULL,
				nombre TEXT NOT NULL,
				sku TEXT NOT NULL,
				codigo_barras TEXT NOT NULL DEFAULT '',
				precio_base REAL NOT NULL,
				activo INTEGER NOT NULL
			)
		''');
	}

	/// Ejecuta migracion de version 1 a version 2.
	///
	/// [base] Conexion SQLite activa.
	static Future<void> migrarVersion1A2(Database base) async {
		await base.execute(
			"ALTER TABLE products ADD COLUMN modulo_vertical TEXT NOT NULL DEFAULT 'general'",
		);
		await base.execute('''
			CREATE TABLE pharmacy_lots (
				id TEXT PRIMARY KEY,
				producto_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				numero_lote TEXT NOT NULL,
				caduca_en TEXT NOT NULL,
				cantidad REAL NOT NULL,
				activo INTEGER NOT NULL
			)
		''');
		await base.execute('''
			CREATE INDEX idx_pharmacy_lots_producto ON pharmacy_lots(producto_id, tienda_id)
		''');
		await base.execute('ALTER TABLE sale_lines ADD COLUMN lote_id TEXT');
		await base.execute('ALTER TABLE sale_lines ADD COLUMN etiqueta_lote TEXT');
	}

	/// Crea esquema completo para instalacion nueva en la version actual.
	///
	/// [base] Conexion SQLite activa.
	static Future<void> crearEsquemaCompleto(Database base) async {
		await base.execute('''
			CREATE TABLE app_config (
				clave TEXT PRIMARY KEY,
				valor TEXT NOT NULL
			)
		''');
		await base.execute('''
			CREATE TABLE products (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo_barras TEXT NOT NULL,
				precio_base REAL NOT NULL,
				unidad_medida TEXT NOT NULL,
				ruta_imagen TEXT NOT NULL,
				activo INTEGER NOT NULL,
				tienda_id TEXT NOT NULL,
				modulo_vertical TEXT NOT NULL DEFAULT 'general',
				categoria_id TEXT,
				piezas_por_caja INTEGER,
				proveedor_id TEXT,
				unidades_por_bulto INTEGER,
				notas TEXT NOT NULL DEFAULT ''
			)
		''');
		await base.execute('''
			CREATE INDEX idx_products_barcode ON products(codigo_barras)
		''');
		await base.execute('''
			CREATE TABLE customers (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				lista_precios_id TEXT,
				credito_habilitado INTEGER NOT NULL,
				activo INTEGER NOT NULL,
				telefono TEXT NOT NULL DEFAULT '',
				email TEXT NOT NULL DEFAULT '',
				rfc TEXT NOT NULL DEFAULT '',
				direccion TEXT NOT NULL DEFAULT '',
				notas TEXT NOT NULL DEFAULT ''
			)
		''');
		await base.execute('''
			CREATE TABLE wholesale_tiers (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				producto_id TEXT NOT NULL,
				cantidad_minima REAL NOT NULL,
				precio_unitario REAL NOT NULL
			)
		''');
		await base.execute('''
			CREATE TABLE customer_product_prices (
				cliente_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				precio_unitario REAL NOT NULL,
				PRIMARY KEY (cliente_id, producto_id)
			)
		''');
		await base.execute('''
			CREATE TABLE price_list_items (
				lista_precios_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				precio_unitario REAL NOT NULL,
				PRIMARY KEY (lista_precios_id, producto_id)
			)
		''');
		await base.execute('''
			CREATE TABLE sales (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				caja_id TEXT NOT NULL,
				cliente_id TEXT,
				metodo_pago TEXT NOT NULL,
				total REAL NOT NULL,
				creada_en TEXT NOT NULL,
				vendedor_id TEXT,
				estado TEXT NOT NULL DEFAULT 'completada',
				turno_caja_id TEXT
			)
		''');
		await base.execute('''
			CREATE TABLE sale_lines (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				venta_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad REAL NOT NULL,
				precio_unitario REAL NOT NULL,
				regla_precio TEXT NOT NULL,
				lote_id TEXT,
				etiqueta_lote TEXT
			)
		''');
		await base.execute('''
			CREATE TABLE stock_levels (
				producto_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				cantidad REAL NOT NULL,
				actualizado_en TEXT NOT NULL,
				stock_minimo REAL NOT NULL DEFAULT 0,
				PRIMARY KEY (producto_id, tienda_id)
			)
		''');
		await base.execute('''
			CREATE TABLE sync_event_queue (
				id TEXT PRIMARY KEY,
				tenant_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				dispositivo_id TEXT NOT NULL,
				tipo TEXT NOT NULL,
				payload TEXT NOT NULL,
				creado_en TEXT NOT NULL,
				estado TEXT NOT NULL
			)
		''');
		await base.execute('''
			CREATE TABLE sync_state (
				clave TEXT PRIMARY KEY,
				valor TEXT NOT NULL
			)
		''');
		await base.execute('''
			CREATE TABLE stores (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				direccion TEXT NOT NULL,
				activa INTEGER NOT NULL
			)
		''');
		await crearTablasVerticales(base);
		await crearTablasOperaciones(base);
	}

	/// Crea tablas verticales en instalacion nueva version 2.
	///
	/// [base] Conexion SQLite activa.
	static Future<void> crearTablasVerticales(Database base) async {
		await base.execute('''
			CREATE TABLE pharmacy_lots (
				id TEXT PRIMARY KEY,
				producto_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				numero_lote TEXT NOT NULL,
				caduca_en TEXT NOT NULL,
				cantidad REAL NOT NULL,
				activo INTEGER NOT NULL
			)
		''');
		await base.execute('''
			CREATE INDEX idx_pharmacy_lots_producto ON pharmacy_lots(producto_id, tienda_id)
		''');
	}
}
