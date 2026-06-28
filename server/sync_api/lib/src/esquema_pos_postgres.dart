/// Esquema PostgreSQL espejo del POS local (SQLite v5).
library;

import 'package:postgres/postgres.dart';

/// DDL del modelo operativo POSIA en Postgres (Neon / on-premise).
///
/// Una base Neon por despliegue: sin tablas huérfanas ni multi-tenant en stores.
class EsquemaPosPostgres {
	EsquemaPosPostgres._();

	/// Crea tablas operativas y log de sync si no existen.
	static Future<void> crearEsquemaCompleto(Connection conexion) async {
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS stores (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				direccion TEXT NOT NULL,
				activa INTEGER NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS categories (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				icono TEXT NOT NULL DEFAULT 'shopping_basket',
				color_hex TEXT NOT NULL DEFAULT '#4CAF50',
				orden INTEGER NOT NULL DEFAULT 0,
				activa INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS products (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo_barras TEXT NOT NULL,
				precio_base DOUBLE PRECISION NOT NULL,
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
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(codigo_barras)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS customers (
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
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS sales (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				caja_id TEXT NOT NULL,
				cliente_id TEXT,
				metodo_pago TEXT NOT NULL,
				total DOUBLE PRECISION NOT NULL,
				creada_en TEXT NOT NULL,
				vendedor_id TEXT,
				estado TEXT NOT NULL DEFAULT 'completada',
				turno_caja_id TEXT
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS sale_lines (
				id SERIAL PRIMARY KEY,
				venta_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL,
				regla_precio TEXT NOT NULL,
				lote_id TEXT,
				etiqueta_lote TEXT
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sale_lines_venta ON sale_lines(venta_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS stock_levels (
				producto_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL,
				actualizado_en TEXT NOT NULL,
				stock_minimo DOUBLE PRECISION NOT NULL DEFAULT 0,
				PRIMARY KEY (producto_id, tienda_id)
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS product_variants (
				id TEXT PRIMARY KEY,
				producto_padre_id TEXT NOT NULL,
				nombre TEXT NOT NULL,
				sku TEXT NOT NULL,
				codigo_barras TEXT NOT NULL DEFAULT '',
				precio_base DOUBLE PRECISION NOT NULL,
				activo INTEGER NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS transfers (
				id TEXT PRIMARY KEY,
				tienda_origen_id TEXT NOT NULL,
				tienda_destino_id TEXT NOT NULL,
				estado TEXT NOT NULL,
				solicitado_en TEXT NOT NULL,
				completado_en TEXT,
				notas TEXT NOT NULL DEFAULT ''
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS transfer_lines (
				id SERIAL PRIMARY KEY,
				transfer_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				cantidad_solicitada DOUBLE PRECISION NOT NULL,
				cantidad_recibida DOUBLE PRECISION
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS sync_events (
				seq BIGSERIAL PRIMARY KEY,
				id TEXT UNIQUE NOT NULL,
				tenant_id TEXT NOT NULL DEFAULT '',
				store_id TEXT NOT NULL,
				device_id TEXT NOT NULL,
				type TEXT NOT NULL,
				payload JSONB NOT NULL,
				created_at TIMESTAMPTZ NOT NULL,
				received_at TIMESTAMPTZ NOT NULL DEFAULT now()
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sync_events_seq ON sync_events (seq)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS users (
				id TEXT PRIMARY KEY,
				tenant_id TEXT NOT NULL DEFAULT '',
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL,
				rol TEXT NOT NULL,
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1,
				pin_hash TEXT NOT NULL,
				pin_salt TEXT NOT NULL,
				creado_en TEXT NOT NULL,
				actualizado_en TEXT NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_users_codigo ON users(codigo)
		''');
		await conexion.execute('''
			ALTER TABLE products ADD COLUMN IF NOT EXISTS permite_stock_negativo INTEGER NOT NULL DEFAULT 0
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS almacenes (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS warehouse_stock (
				producto_id TEXT NOT NULL,
				almacen_id TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL,
				actualizado_en TEXT NOT NULL,
				stock_minimo DOUBLE PRECISION NOT NULL DEFAULT 0,
				PRIMARY KEY (producto_id, almacen_id)
			)
		''');
		await _migrarLegacy(conexion);
	}

	/// Elimina tablas/columnas de despliegues multi-tenant anteriores.
	static Future<void> _migrarLegacy(Connection conexion) async {
		for (final tabla in [
			'vendedores',
			'proveedores',
			'pharmacy_lots',
			'tipos_presentacion',
		]) {
			await conexion.execute('DROP TABLE IF EXISTS $tabla');
		}
		await conexion.execute('DROP INDEX IF EXISTS idx_stores_tenant');
		await conexion.execute('DROP INDEX IF EXISTS idx_users_tenant_codigo');
		await conexion.execute('DROP INDEX IF EXISTS idx_sync_events_tenant_seq');
		await conexion.execute('ALTER TABLE stores DROP COLUMN IF EXISTS tenant_id');
		await conexion.execute('''
			CREATE UNIQUE INDEX IF NOT EXISTS idx_users_codigo_unico ON users(codigo)
		''');
	}
}
