/// Esquema PostgreSQL espejo del POS local (SQLite v32).
library;

import 'package:posia_core/posia_core.dart';
import 'package:postgres/postgres.dart';

/// DDL del modelo operativo POSIA en Postgres (Neon / on-premise).
///
/// Una base Neon por despliegue: sin tablas huérfanas ni multi-tenant en stores.
class EsquemaPosPostgres {
	EsquemaPosPostgres._();

	/// Crea tablas operativas y log de sync si no existen.
	static Future<void> crearEsquemaCompleto(Session conexion) async {
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
			CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_tienda_activo
			ON products(tienda_id, codigo_barras)
			WHERE activo = 1 AND codigo_barras <> ''
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
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL,
				rol TEXT NOT NULL,
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1,
				pin_credencial TEXT NOT NULL,
				creado_en TEXT NOT NULL,
				actualizado_en TEXT NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_users_codigo ON users(codigo)
		''');
		await conexion.execute('''
			ALTER TABLE users ADD COLUMN IF NOT EXISTS rol_personalizado_id TEXT
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS custom_roles (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				descripcion TEXT NOT NULL DEFAULT '',
				permisos_json JSONB NOT NULL DEFAULT '[]',
				categorias_json JSONB NOT NULL DEFAULT '[]',
				activo INTEGER NOT NULL DEFAULT 1,
				tienda_id TEXT
			)
		''');
		await conexion.execute('''
			ALTER TABLE products ADD COLUMN IF NOT EXISTS permite_stock_negativo INTEGER NOT NULL DEFAULT 1
		''');
		await conexion.execute('''
			ALTER TABLE products ADD COLUMN IF NOT EXISTS costo_unitario DOUBLE PRECISION NOT NULL DEFAULT 0
		''');
		await conexion.execute('''
			ALTER TABLE products ADD COLUMN IF NOT EXISTS favorito_caja INTEGER NOT NULL DEFAULT 0
		''');
		await conexion.execute('''
			ALTER TABLE customers ADD COLUMN IF NOT EXISTS dias_credito INTEGER NOT NULL DEFAULT $DIAS_CREDITO_PREDETERMINADO
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS descuento_ticket DOUBLE PRECISION NOT NULL DEFAULT 0
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS monto_efectivo DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS monto_tarjeta DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS monto_transferencia DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS credito_dias INTEGER
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS credito_vence_en TEXT
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS credito_liquidado INTEGER NOT NULL DEFAULT 0
		''');
		await conexion.execute('''
			ALTER TABLE sales ADD COLUMN IF NOT EXISTS credito_liquidado_en TEXT
		''');
		await conexion.execute('''
			ALTER TABLE sale_lines ADD COLUMN IF NOT EXISTS descuento_linea DOUBLE PRECISION NOT NULL DEFAULT 0
		''');
		await conexion.execute('''
			ALTER TABLE stores ADD COLUMN IF NOT EXISTS latitud DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE stores ADD COLUMN IF NOT EXISTS longitud DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE stores ADD COLUMN IF NOT EXISTS radio_metros DOUBLE PRECISION DEFAULT 150
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS wholesale_tiers (
				id SERIAL PRIMARY KEY,
				producto_id TEXT NOT NULL,
				cantidad_minima DOUBLE PRECISION NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_wholesale_tiers_producto
			ON wholesale_tiers(producto_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS lotes_promocion (
				id TEXT PRIMARY KEY,
				codigo_externo TEXT NOT NULL,
				nombre TEXT NOT NULL DEFAULT '',
				cantidad_minima DOUBLE PRECISION NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE UNIQUE INDEX IF NOT EXISTS idx_lotes_promocion_codigo
			ON lotes_promocion(codigo_externo)
			WHERE activo = 1
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS lote_promocion_miembros (
				lote_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				PRIMARY KEY (lote_id, producto_id)
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_lote_promocion_miembros_producto
			ON lote_promocion_miembros(producto_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS combos (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL DEFAULT '',
				precio_combo DOUBLE PRECISION NOT NULL,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS combo_miembros (
				combo_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				cantidad_requerida DOUBLE PRECISION NOT NULL DEFAULT 1,
				PRIMARY KEY (combo_id, producto_id)
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_combo_miembros_producto
			ON combo_miembros(producto_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS price_lists (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				activa INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS price_list_items (
				lista_precios_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL,
				PRIMARY KEY (lista_precios_id, producto_id)
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_price_list_items_producto
			ON price_list_items(producto_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS customer_product_prices (
				cliente_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL,
				PRIMARY KEY (cliente_id, producto_id)
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_customer_product_prices_producto
			ON customer_product_prices(producto_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS customer_discounts (
				id TEXT PRIMARY KEY,
				cliente_id TEXT NOT NULL,
				tipo TEXT NOT NULL,
				valor DOUBLE PRECISION NOT NULL,
				producto_id TEXT,
				condicion TEXT NOT NULL,
				umbral DOUBLE PRECISION,
				activo INTEGER NOT NULL DEFAULT 1,
				descripcion TEXT NOT NULL DEFAULT ''
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_customer_discounts_cliente
			ON customer_discounts(cliente_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS tipos_presentacion (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				unidad TEXT NOT NULL,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			INSERT INTO tipos_presentacion (id, nombre, unidad, activo)
			VALUES
				('tp-caja', 'Caja', 'caja', 1),
				('tp-bulto', 'Bulto', 'pieza', 1),
				('tp-kg', 'Kilogramo', 'kilogramo', 1)
			ON CONFLICT (id) DO NOTHING
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS product_presentations (
				id TEXT PRIMARY KEY,
				producto_id TEXT NOT NULL,
				tipo_presentacion_id TEXT,
				nombre TEXT NOT NULL,
				factor_a_base DOUBLE PRECISION NOT NULL DEFAULT 1,
				es_presentacion_base INTEGER NOT NULL DEFAULT 0,
				codigo_barras TEXT NOT NULL DEFAULT '',
				precio DOUBLE PRECISION,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_product_presentations_producto
			ON product_presentations(producto_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS quotes (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				nombre TEXT NOT NULL DEFAULT '',
				cliente_id TEXT,
				nombre_cliente TEXT,
				total DOUBLE PRECISION NOT NULL,
				notas TEXT NOT NULL DEFAULT '',
				vigencia_dias INTEGER NOT NULL DEFAULT $VIGENCIA_COTIZACION_DIAS,
				creada_en TEXT NOT NULL,
				caja_id TEXT,
				vendedor_id TEXT
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_quotes_tienda_fecha
			ON quotes(tienda_id, creada_en DESC)
		''');
		await conexion.execute('''
			ALTER TABLE quotes ADD COLUMN IF NOT EXISTS nombre TEXT NOT NULL DEFAULT ''
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS quote_lines (
				id SERIAL PRIMARY KEY,
				cotizacion_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL,
				regla_precio TEXT NOT NULL DEFAULT 'precioBase',
				subtotal DOUBLE PRECISION NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_quote_lines_cotizacion
			ON quote_lines(cotizacion_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS orders (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				cliente_id TEXT,
				nombre_entrega TEXT NOT NULL,
				telefono_entrega TEXT NOT NULL,
				direccion_entrega TEXT NOT NULL,
				es_credito INTEGER NOT NULL DEFAULT 0,
				credito_dias INTEGER,
				credito_vence_en TEXT,
				metodo_pago TEXT NOT NULL,
				total DOUBLE PRECISION NOT NULL,
				notas TEXT NOT NULL DEFAULT '',
				estado TEXT NOT NULL DEFAULT 'recibido',
				asignado_a_usuario_id TEXT,
				asignado_a_usuario_nombre TEXT,
				asignado_en TEXT,
				creado_en TEXT NOT NULL,
				creado_por_usuario_id TEXT,
				venta_id TEXT
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_orders_tienda_estado
			ON orders(tienda_id, estado, creado_en DESC)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS order_lines (
				id SERIAL PRIMARY KEY,
				pedido_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL,
				precio_unitario DOUBLE PRECISION NOT NULL,
				subtotal DOUBLE PRECISION NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_order_lines_pedido
			ON order_lines(pedido_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS attendance_challenges (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				pin_hash TEXT NOT NULL,
				expira_en TEXT NOT NULL,
				creado_por TEXT NOT NULL,
				latitud DOUBLE PRECISION,
				longitud DOUBLE PRECISION,
				radio_metros DOUBLE PRECISION DEFAULT 150,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS attendance_records (
				id TEXT PRIMARY KEY,
				usuario_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				entrada_en TEXT NOT NULL,
				salida_en TEXT,
				metodo TEXT NOT NULL,
				latitud DOUBLE PRECISION,
				longitud DOUBLE PRECISION,
				desafio_id TEXT
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_attendance_records_tienda
			ON attendance_records(tienda_id, entrada_en DESC)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS almacenes (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1,
				latitud DOUBLE PRECISION,
				longitud DOUBLE PRECISION,
				radio_metros DOUBLE PRECISION DEFAULT 150
			)
		''');
		await conexion.execute('''
			ALTER TABLE almacenes ADD COLUMN IF NOT EXISTS latitud DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE almacenes ADD COLUMN IF NOT EXISTS longitud DOUBLE PRECISION
		''');
		await conexion.execute('''
			ALTER TABLE almacenes ADD COLUMN IF NOT EXISTS radio_metros DOUBLE PRECISION DEFAULT 150
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
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS suppliers (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				contacto TEXT NOT NULL DEFAULT '',
				telefono TEXT NOT NULL DEFAULT '',
				activo INTEGER NOT NULL DEFAULT 1,
				email TEXT NOT NULL DEFAULT '',
				rfc TEXT NOT NULL DEFAULT '',
				direccion TEXT NOT NULL DEFAULT '',
				notas TEXT NOT NULL DEFAULT '',
				dias_credito INTEGER NOT NULL DEFAULT 0
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS purchases (
				id TEXT PRIMARY KEY,
				tienda_id TEXT,
				proveedor_id TEXT NOT NULL,
				fecha_compra TEXT NOT NULL,
				notas TEXT NOT NULL DEFAULT '',
				total DOUBLE PRECISION NOT NULL,
				creada_en TEXT NOT NULL,
				creado_por TEXT
			)
		''');
		await conexion.execute('''
			ALTER TABLE purchases ALTER COLUMN tienda_id DROP NOT NULL
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS purchase_lines (
				id SERIAL PRIMARY KEY,
				compra_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL,
				costo_unitario DOUBLE PRECISION NOT NULL,
				subtotal DOUBLE PRECISION NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS purchase_allocations (
				id TEXT PRIMARY KEY,
				compra_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				destino_tipo TEXT NOT NULL,
				destino_id TEXT NOT NULL,
				cantidad DOUBLE PRECISION NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_purchases_tienda_fecha
			ON purchases(tienda_id, fecha_compra DESC)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_purchases_fecha
			ON purchases(fecha_compra DESC)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_purchase_lines_compra
			ON purchase_lines(compra_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_purchase_allocations_compra
			ON purchase_allocations(compra_id)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS cash_shifts (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				caja_id TEXT NOT NULL,
				vendedor_id TEXT,
				fondo_inicial DOUBLE PRECISION NOT NULL,
				total_efectivo DOUBLE PRECISION NOT NULL DEFAULT 0,
				total_tarjeta DOUBLE PRECISION NOT NULL DEFAULT 0,
				total_transferencia DOUBLE PRECISION NOT NULL DEFAULT 0,
				total_ventas DOUBLE PRECISION NOT NULL DEFAULT 0,
				cantidad_ventas INTEGER NOT NULL DEFAULT 0,
				abierto_en TEXT NOT NULL,
				cerrado_en TEXT,
				estado TEXT NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_cash_shifts_tienda_abierto
			ON cash_shifts(tienda_id, abierto_en DESC)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS employee_profiles (
				usuario_id TEXT PRIMARY KEY,
				tarifa_hora DOUBLE PRECISION NOT NULL DEFAULT 0,
				tipo_pago TEXT NOT NULL DEFAULT 'por_hora',
				actualizado_en TEXT NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS payroll_periods (
				id TEXT PRIMARY KEY,
				tienda_id TEXT,
				inicio_en TEXT NOT NULL,
				fin_en TEXT NOT NULL,
				estado TEXT NOT NULL,
				cerrado_en TEXT,
				cerrado_por TEXT
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_payroll_periods_tienda
			ON payroll_periods(tienda_id, inicio_en DESC)
		''');
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS payroll_lines (
				id TEXT PRIMARY KEY,
				periodo_id TEXT NOT NULL,
				usuario_id TEXT NOT NULL,
				horas_trabajadas DOUBLE PRECISION NOT NULL,
				tarifa_hora DOUBLE PRECISION NOT NULL,
				monto_bruto DOUBLE PRECISION NOT NULL,
				monto_neto DOUBLE PRECISION NOT NULL
			)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_payroll_lines_periodo
			ON payroll_lines(periodo_id)
		''');
		await _asegurarIndices(conexion);
		await _asegurarClavesForaneas(conexion);
		await _asegurarTiposTemporales(conexion);
		await _asegurarRetencionSyncEvents(conexion);
	}

	static Future<void> _asegurarIndices(Session conexion) async {
		await conexion.execute('''
			CREATE UNIQUE INDEX IF NOT EXISTS idx_users_codigo_unico ON users(codigo)
		''');
		await conexion.execute('''
			CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_tienda_activo
			ON products(tienda_id, codigo_barras)
			WHERE activo = 1 AND codigo_barras <> ''
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_products_tienda ON products(tienda_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_products_categoria ON products(categoria_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sales_tienda_fecha ON sales(tienda_id, creada_en DESC)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sales_turno ON sales(turno_caja_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sales_cliente ON sales(cliente_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_transfer_lines_transfer
			ON transfer_lines(transfer_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_warehouse_stock_almacen
			ON warehouse_stock(almacen_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_almacenes_tienda ON almacenes(tienda_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_orders_empleado
			ON orders(asignado_a_usuario_id, estado)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_product_variants_padre
			ON product_variants(producto_padre_id)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sync_events_store_seq
			ON sync_events(store_id, seq)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sync_events_store_created
			ON sync_events(store_id, created_at DESC)
		''');
		await conexion.execute('''
			CREATE INDEX IF NOT EXISTS idx_sync_events_created
			ON sync_events(created_at)
		''');
	}

	/// FKs DEFERRABLE: permiten proyectar lotes multi-fila y validar al COMMIT.
	static Future<void> _asegurarClavesForaneas(Session conexion) async {
		const fks = <(String tabla, String nombre, String definicion)>[
			(
				'products',
				'fk_products_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'product_variants',
				'fk_variants_producto',
				'FOREIGN KEY (producto_padre_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'stock_levels',
				'fk_stock_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'stock_levels',
				'fk_stock_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'almacenes',
				'fk_almacenes_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'warehouse_stock',
				'fk_warehouse_stock_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'warehouse_stock',
				'fk_warehouse_stock_almacen',
				'FOREIGN KEY (almacen_id) REFERENCES almacenes(id) ON DELETE CASCADE',
			),
			(
				'sales',
				'fk_sales_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'sale_lines',
				'fk_sale_lines_venta',
				'FOREIGN KEY (venta_id) REFERENCES sales(id) ON DELETE CASCADE',
			),
			(
				'cash_shifts',
				'fk_cash_shifts_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'transfer_lines',
				'fk_transfer_lines_transfer',
				'FOREIGN KEY (transfer_id) REFERENCES transfers(id) ON DELETE CASCADE',
			),
			(
				'wholesale_tiers',
				'fk_wholesale_tiers_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'lote_promocion_miembros',
				'fk_lote_miembros_lote',
				'FOREIGN KEY (lote_id) REFERENCES lotes_promocion(id) ON DELETE CASCADE',
			),
			(
				'lote_promocion_miembros',
				'fk_lote_miembros_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'combo_miembros',
				'fk_combo_miembros_combo',
				'FOREIGN KEY (combo_id) REFERENCES combos(id) ON DELETE CASCADE',
			),
			(
				'combo_miembros',
				'fk_combo_miembros_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'price_list_items',
				'fk_price_list_items_lista',
				'FOREIGN KEY (lista_precios_id) REFERENCES price_lists(id) ON DELETE CASCADE',
			),
			(
				'price_list_items',
				'fk_price_list_items_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'customer_product_prices',
				'fk_cpp_cliente',
				'FOREIGN KEY (cliente_id) REFERENCES customers(id) ON DELETE CASCADE',
			),
			(
				'customer_product_prices',
				'fk_cpp_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'customer_discounts',
				'fk_customer_discounts_cliente',
				'FOREIGN KEY (cliente_id) REFERENCES customers(id) ON DELETE CASCADE',
			),
			(
				'product_presentations',
				'fk_presentations_producto',
				'FOREIGN KEY (producto_id) REFERENCES products(id) ON DELETE CASCADE',
			),
			(
				'quote_lines',
				'fk_quote_lines_cotizacion',
				'FOREIGN KEY (cotizacion_id) REFERENCES quotes(id) ON DELETE CASCADE',
			),
			(
				'order_lines',
				'fk_order_lines_pedido',
				'FOREIGN KEY (pedido_id) REFERENCES orders(id) ON DELETE CASCADE',
			),
			(
				'purchase_lines',
				'fk_purchase_lines_compra',
				'FOREIGN KEY (compra_id) REFERENCES purchases(id) ON DELETE CASCADE',
			),
			(
				'purchase_allocations',
				'fk_purchase_allocations_compra',
				'FOREIGN KEY (compra_id) REFERENCES purchases(id) ON DELETE CASCADE',
			),
			(
				'purchases',
				'fk_purchases_proveedor',
				'FOREIGN KEY (proveedor_id) REFERENCES suppliers(id)',
			),
			(
				'purchases',
				'fk_purchases_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'users',
				'fk_users_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'attendance_challenges',
				'fk_attendance_challenges_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'attendance_records',
				'fk_attendance_records_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'payroll_periods',
				'fk_payroll_periods_tienda',
				'FOREIGN KEY (tienda_id) REFERENCES stores(id)',
			),
			(
				'payroll_lines',
				'fk_payroll_lines_periodo',
				'FOREIGN KEY (periodo_id) REFERENCES payroll_periods(id) ON DELETE CASCADE',
			),
		];
		for (final fk in fks) {
			final (tabla, nombre, definicion) = fk;
			try {
				await conexion.execute(
					'ALTER TABLE $tabla DROP CONSTRAINT IF EXISTS $nombre',
				);
				await conexion.execute('''
					ALTER TABLE $tabla
					ADD CONSTRAINT $nombre
					$definicion
					DEFERRABLE INITIALLY DEFERRED
				''');
			} on Object {
				// Orfandad previa u otro conflicto: no bloquear arranque.
			}
		}
	}

	/// Convierte timestamps de negocio TEXT ISO → TIMESTAMPTZ (idempotente).
	static Future<void> _asegurarTiposTemporales(Session conexion) async {
		const columnas = <(String tabla, String columna, bool nullable)>[
			('sales', 'creada_en', false),
			('sales', 'credito_vence_en', true),
			('sales', 'credito_liquidado_en', true),
			('stock_levels', 'actualizado_en', false),
			('warehouse_stock', 'actualizado_en', false),
			('transfers', 'solicitado_en', false),
			('transfers', 'completado_en', true),
			('quotes', 'creada_en', false),
			('orders', 'creado_en', false),
			('orders', 'asignado_en', true),
			('orders', 'credito_vence_en', true),
			('purchases', 'fecha_compra', false),
			('purchases', 'creada_en', false),
			('cash_shifts', 'abierto_en', false),
			('cash_shifts', 'cerrado_en', true),
			('attendance_challenges', 'expira_en', false),
			('attendance_records', 'entrada_en', false),
			('attendance_records', 'salida_en', true),
			('users', 'creado_en', false),
			('users', 'actualizado_en', false),
			('employee_profiles', 'actualizado_en', false),
			('payroll_periods', 'inicio_en', false),
			('payroll_periods', 'fin_en', false),
			('payroll_periods', 'cerrado_en', true),
		];
		for (final col in columnas) {
			await _convertirColumnaATimestamptz(
				conexion,
				tabla: col.$1,
				columna: col.$2,
				nullable: col.$3,
			);
		}
	}

	static Future<void> _convertirColumnaATimestamptz(
		Session conexion, {
		required String tabla,
		required String columna,
		required bool nullable,
	}) async {
		try {
			final tipo = await conexion.execute(
				Sql.named('''
					SELECT data_type
					FROM information_schema.columns
					WHERE table_schema = 'public'
						AND table_name = @tabla
						AND column_name = @columna
				'''),
				parameters: {'tabla': tabla, 'columna': columna},
			);
			if (tipo.isEmpty) {
				return;
			}
			final dataType = (tipo.first[0] as String?) ?? '';
			if (dataType.contains('timestamp')) {
				return;
			}
			if (nullable) {
				await conexion.execute('''
					ALTER TABLE $tabla
					ALTER COLUMN $columna TYPE TIMESTAMPTZ
					USING CASE
						WHEN $columna IS NULL OR btrim($columna::text) = '' THEN NULL
						ELSE $columna::timestamptz
					END
				''');
			} else {
				await conexion.execute('''
					ALTER TABLE $tabla
					ALTER COLUMN $columna TYPE TIMESTAMPTZ
					USING CASE
						WHEN $columna IS NULL OR btrim($columna::text) = '' THEN now()
						ELSE $columna::timestamptz
					END
				''');
			}
		} on Object {
			// Datos no parseables u otro error: conservar TEXT.
		}
	}

	/// Indice + meta de retencion del log de sync.
	static Future<void> _asegurarRetencionSyncEvents(Session conexion) async {
		await conexion.execute('''
			CREATE TABLE IF NOT EXISTS schema_meta (
				clave TEXT PRIMARY KEY,
				valor TEXT NOT NULL
			)
		''');
		await conexion.execute(
			Sql.named('''
				INSERT INTO schema_meta (clave, valor)
				VALUES ('sync_events_retention_days', @dias)
				ON CONFLICT (clave) DO UPDATE SET valor = EXCLUDED.valor
			'''),
			parameters: {'dias': '$DIAS_RETENCION_SYNC_EVENTS'},
		);
	}

	/// Purga eventos del hub mas antiguos que la ventana de retencion.
	static Future<int> purgarEventosAntiguos(Session conexion) async {
		final resultado = await conexion.execute(
			Sql.named('''
				DELETE FROM sync_events
				WHERE created_at < now() - make_interval(days => @dias)
			'''),
			parameters: {'dias': DIAS_RETENCION_SYNC_EVENTS},
		);
		return resultado.affectedRows;
	}
}
