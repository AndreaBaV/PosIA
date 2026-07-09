/// Migraciones incrementales del esquema SQLite POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../seed/placeholders_ejemplo.dart';

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

	/// v6.2: multipago, descuentos, favoritos, costo, listas precios.
	static Future<void> migrarVersion5A6(Database base) async {
		await _agregarColumnaSiNoExiste(base, 'sales', 'descuento_ticket', 'REAL NOT NULL DEFAULT 0');
		await _agregarColumnaSiNoExiste(base, 'sales', 'monto_efectivo', 'REAL');
		await _agregarColumnaSiNoExiste(base, 'sales', 'monto_tarjeta', 'REAL');
		await _agregarColumnaSiNoExiste(base, 'sales', 'monto_transferencia', 'REAL');
		await _agregarColumnaSiNoExiste(base, 'sale_lines', 'descuento_linea', 'REAL NOT NULL DEFAULT 0');
		await _agregarColumnaSiNoExiste(base, 'products', 'costo_unitario', 'REAL NOT NULL DEFAULT 0');
		await _agregarColumnaSiNoExiste(base, 'products', 'favorito_caja', 'INTEGER NOT NULL DEFAULT 0');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS price_lists (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				activa INTEGER NOT NULL DEFAULT 1
			)
		''');
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

	/// v6.3: codigo unico y automatico para vendedores.
	static Future<void> migrarVersion6A7(Database base) async {
		await _normalizarCodigosVendedores(base);
		await base.execute(
			'CREATE UNIQUE INDEX IF NOT EXISTS idx_vendedores_codigo ON vendedores(codigo)',
		);
	}

	/// v6.4: cuentas de usuario con roles y alcance por tienda.
	static Future<void> migrarVersion7A8(Database base) async {
		await _agregarColumnaSiNoExiste(base, 'vendedores', 'tienda_id', 'TEXT');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS usuarios (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL,
				pin TEXT NOT NULL,
				rol TEXT NOT NULL,
				tienda_id TEXT,
				activo INTEGER NOT NULL
			)
		''');
		await base.execute(
			'CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_codigo ON usuarios(codigo)',
		);
	}

	/// v6.5: descuentos configurables por cliente.
	static Future<void> migrarVersion8A9(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS customer_discounts (
				id TEXT PRIMARY KEY,
				cliente_id TEXT NOT NULL,
				tipo TEXT NOT NULL,
				valor REAL NOT NULL,
				producto_id TEXT,
				condicion TEXT NOT NULL,
				umbral REAL,
				activo INTEGER NOT NULL DEFAULT 1,
				descripcion TEXT NOT NULL DEFAULT ''
			)
		''');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_customer_discounts_cliente ON customer_discounts(cliente_id)',
		);
	}

	/// v6.6: usuarios con PIN hasheado, codigo unico y auditoria.
	static Future<void> migrarVersion9A10(Database base) async {
		await _recrearTablaUsuariosSegura(base);
	}

	static Future<void> _recrearTablaUsuariosSegura(Database base) async {
		final info = await base.rawQuery('PRAGMA table_info(usuarios)');
		if (info.isEmpty) {
			await _crearTablaUsuariosSegura(base);
			return;
		}
		final tieneHash = info.any((fila) => fila['name'] == 'pin_hash');
		final tieneCredencial = info.any((fila) => fila['name'] == 'pin_credencial');
		if (tieneCredencial || !tieneHash) {
			return;
		}

		await base.execute('''
			CREATE TABLE usuarios_seguro (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL COLLATE NOCASE,
				pin_credencial TEXT NOT NULL,
				rol TEXT NOT NULL CHECK (rol IN ('administrador', 'supervisor', 'empleado')),
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
				creado_en TEXT NOT NULL,
				actualizado_en TEXT NOT NULL,
				UNIQUE (codigo)
			)
		''');

		final filas = await base.query('usuarios');
		final ahora = DateTime.now().toUtc().toIso8601String();
		for (final fila in filas) {
			final pinPlano = fila['pin'] as String? ?? '';
			final credencial = HasherPin.codificar(pinPlano);
			await base.insert('usuarios_seguro', {
				'id': fila['id'],
				'nombre': fila['nombre'],
				'codigo': (fila['codigo'] as String).trim(),
				'pin_credencial': credencial,
				'rol': fila['rol'],
				'tienda_id': fila['tienda_id'],
				'activo': fila['activo'],
				'creado_en': ahora,
				'actualizado_en': ahora,
			});
		}

		await base.execute('DROP TABLE usuarios');
		await base.execute('ALTER TABLE usuarios_seguro RENAME TO usuarios');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_usuarios_tienda ON usuarios(tienda_id)',
		);
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON usuarios(activo)',
		);
	}

	static Future<void> _crearTablaUsuariosSegura(Database base) async {
		await base.execute('''
			CREATE TABLE usuarios (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL COLLATE NOCASE,
				pin_credencial TEXT NOT NULL,
				rol TEXT NOT NULL CHECK (rol IN ('administrador', 'supervisor', 'empleado')),
				tienda_id TEXT,
				rol_personalizado_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
				creado_en TEXT NOT NULL,
				actualizado_en TEXT NOT NULL,
				UNIQUE (codigo)
			)
		''');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_usuarios_tienda ON usuarios(tienda_id)',
		);
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON usuarios(activo)',
		);
	}

	static Future<void> _normalizarCodigosVendedores(Database base) async {
		final filas = await base.query('vendedores', orderBy: 'nombre ASC');
		final codigosUsados = <String>{};
		var siguiente = 1;
		for (final fila in filas) {
			var codigo = fila['codigo'] as String;
			if (codigosUsados.contains(codigo)) {
				while (codigosUsados.contains(siguiente.toString().padLeft(3, '0'))) {
					siguiente = siguiente + 1;
				}
				codigo = siguiente.toString().padLeft(3, '0');
				await base.update(
					'vendedores',
					{'codigo': codigo},
					where: 'id = ?',
					whereArgs: [fila['id']],
				);
			}
			codigosUsados.add(codigo);
			final numerico = int.tryParse(codigo);
			if (numerico != null && numerico >= siguiente) {
				siguiente = numerico + 1;
			}
		}
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
				activo INTEGER NOT NULL,
				tienda_id TEXT
			)
		''');
		await base.execute(
			'CREATE UNIQUE INDEX idx_vendedores_codigo ON vendedores(codigo)',
		);
		await base.execute('''
			CREATE TABLE usuarios (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL COLLATE NOCASE,
				pin_credencial TEXT NOT NULL,
				rol TEXT NOT NULL CHECK (rol IN ('administrador', 'supervisor', 'empleado')),
				tienda_id TEXT,
				rol_personalizado_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
				creado_en TEXT NOT NULL,
				actualizado_en TEXT NOT NULL,
				UNIQUE (codigo)
			)
		''');
		await base.execute(
			'CREATE INDEX idx_usuarios_tienda ON usuarios(tienda_id)',
		);
		await base.execute(
			'CREATE INDEX idx_usuarios_activo ON usuarios(activo)',
		);
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
		await _crearTablasCompras(base);
		await _crearTablasPedidos(base);
		await _crearTablasCotizaciones(base);
		await _crearTablasTicketsEspera(base);
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

	/// Esquema minimo del dispositivo (sin datos de negocio).
	static Future<void> crearEsquemaDispositivo(Database base, int version) async {
		await base.execute('''
			CREATE TABLE app_config (
				clave TEXT PRIMARY KEY,
				valor TEXT NOT NULL
			)
		''');
		await PlaceholdersEjemplo.insertarGuiaDispositivo(base);
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
				notas TEXT NOT NULL DEFAULT '',
				costo_unitario REAL NOT NULL DEFAULT 0,
				favorito_caja INTEGER NOT NULL DEFAULT 0
			)
		''');
		await base.execute('''
			CREATE INDEX idx_products_barcode ON products(codigo_barras)
		''');
		await base.execute('''
			CREATE UNIQUE INDEX idx_products_barcode_tienda_activo
			ON products(tienda_id, codigo_barras)
			WHERE activo = 1 AND codigo_barras != ''
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
				notas TEXT NOT NULL DEFAULT '',
				dias_credito INTEGER NOT NULL DEFAULT $DIAS_CREDITO_PREDETERMINADO
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
			CREATE TABLE customer_discounts (
				id TEXT PRIMARY KEY,
				cliente_id TEXT NOT NULL,
				tipo TEXT NOT NULL,
				valor REAL NOT NULL,
				producto_id TEXT,
				condicion TEXT NOT NULL,
				umbral REAL,
				activo INTEGER NOT NULL DEFAULT 1,
				descripcion TEXT NOT NULL DEFAULT ''
			)
		''');
		await base.execute(
			'CREATE INDEX idx_customer_discounts_cliente ON customer_discounts(cliente_id)',
		);
		await base.execute('''
			CREATE TABLE price_lists (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				activa INTEGER NOT NULL DEFAULT 1
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
				turno_caja_id TEXT,
				descuento_ticket REAL NOT NULL DEFAULT 0,
				monto_efectivo REAL,
				monto_tarjeta REAL,
				monto_transferencia REAL,
				credito_dias INTEGER,
				credito_vence_en TEXT,
				credito_liquidado INTEGER NOT NULL DEFAULT 0,
				credito_liquidado_en TEXT
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
				etiqueta_lote TEXT,
				descuento_linea REAL NOT NULL DEFAULT 0
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
			CREATE TABLE sync_eventos_aplicados (
				evento_id TEXT PRIMARY KEY,
				aplicado_en TEXT NOT NULL
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
		await PlaceholdersEjemplo.insertarGuiaTenant(base);
		await migrarVersion17A18(base);
		await migrarVersion18A19(base);
		await migrarVersion19A20(base);
		await migrarVersion25A26(base);
	}

	/// Tabla guia `ejemplo` en bases ya existentes (v10 → v11).
	static Future<void> migrarVersion10A11(Database base) async {
		await PlaceholdersEjemplo.insertarGuiaTenant(base);
	}

	/// Compras a proveedor con historial (v11 → v12).
	static Future<void> migrarVersion11A12(Database base) async {
		await _crearTablasCompras(base);
	}

	/// Credito de clientes: plazo y datos en ventas (v12 → v13).
	static Future<void> migrarVersion12A13(Database base) async {
		await _agregarColumnaSiNoExiste(
			base,
			'customers',
			'dias_credito',
			'INTEGER NOT NULL DEFAULT $DIAS_CREDITO_PREDETERMINADO',
		);
		await _agregarColumnaSiNoExiste(base, 'sales', 'credito_dias', 'INTEGER');
		await _agregarColumnaSiNoExiste(base, 'sales', 'credito_vence_en', 'TEXT');
	}

	/// Pedidos con asignacion a empleados (v13 → v14).
	static Future<void> migrarVersion13A14(Database base) async {
		await _crearTablasPedidos(base);
	}

	static Future<void> _crearTablasPedidos(Database base) async {
		await base.execute('''
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
				total REAL NOT NULL,
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
		await base.execute('''
			CREATE TABLE IF NOT EXISTS order_lines (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				pedido_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad REAL NOT NULL,
				precio_unitario REAL NOT NULL,
				subtotal REAL NOT NULL
			)
		''');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_orders_tienda_estado '
			'ON orders(tienda_id, estado, creado_en DESC)',
		);
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_orders_empleado '
			'ON orders(asignado_a_usuario_id, estado)',
		);
	}

	/// Credito liquidado y cotizaciones (v14 → v15).
	static Future<void> migrarVersion14A15(Database base) async {
		await _agregarColumnaSiNoExiste(
			base,
			'sales',
			'credito_liquidado',
			'INTEGER NOT NULL DEFAULT 0',
		);
		await _agregarColumnaSiNoExiste(base, 'sales', 'credito_liquidado_en', 'TEXT');
	}

	/// Cotizaciones persistidas (v15 → v16).
	static Future<void> migrarVersion15A16(Database base) async {
		await _crearTablasCotizaciones(base);
	}

	/// Tickets en espera en caja (v16 → v17).
	static Future<void> migrarVersion16A17(Database base) async {
		await _crearTablasTicketsEspera(base);
	}

	static Future<void> _crearTablasTicketsEspera(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS held_tickets (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				caja_id TEXT NOT NULL,
				cliente_id TEXT,
				nombre_cliente TEXT,
				vendedor_id TEXT,
				notas TEXT NOT NULL DEFAULT '',
				descuento_ticket REAL NOT NULL DEFAULT 0,
				total REAL NOT NULL,
				creado_en TEXT NOT NULL
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS held_ticket_lines (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				ticket_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad REAL NOT NULL,
				precio_unitario REAL NOT NULL,
				regla_precio TEXT NOT NULL,
				lote_id TEXT,
				etiqueta_lote TEXT,
				descuento_linea REAL NOT NULL DEFAULT 0,
				codigo_barras TEXT NOT NULL DEFAULT '',
				unidad_medida TEXT NOT NULL DEFAULT 'pieza',
				modulo_vertical TEXT NOT NULL DEFAULT 'general',
				categoria_id TEXT
			)
		''');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_held_tickets_tienda_caja '
			'ON held_tickets(tienda_id, caja_id, creado_en DESC)',
		);
	}

	static Future<void> _crearTablasCotizaciones(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS quotes (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				cliente_id TEXT,
				nombre_cliente TEXT,
				total REAL NOT NULL,
				notas TEXT NOT NULL DEFAULT '',
				vigencia_dias INTEGER NOT NULL DEFAULT $VIGENCIA_COTIZACION_DIAS,
				creada_en TEXT NOT NULL,
				caja_id TEXT,
				vendedor_id TEXT
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS quote_lines (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				cotizacion_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad REAL NOT NULL,
				precio_unitario REAL NOT NULL,
				regla_precio TEXT NOT NULL DEFAULT 'precioBase',
				subtotal REAL NOT NULL
			)
		''');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_quotes_tienda_fecha '
			'ON quotes(tienda_id, creada_en DESC)',
		);
	}

	static Future<void> _crearTablasCompras(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS purchases (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				proveedor_id TEXT NOT NULL,
				fecha_compra TEXT NOT NULL,
				notas TEXT NOT NULL DEFAULT '',
				total REAL NOT NULL,
				creada_en TEXT NOT NULL,
				creado_por TEXT
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS purchase_lines (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				compra_id TEXT NOT NULL,
				producto_id TEXT NOT NULL,
				nombre_producto TEXT NOT NULL,
				cantidad REAL NOT NULL,
				costo_unitario REAL NOT NULL,
				subtotal REAL NOT NULL
			)
		''');
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_purchases_tienda_fecha '
			'ON purchases(tienda_id, fecha_compra DESC)',
		);
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

	/// Inventario extendido: stock negativo, almacenes, presentaciones (v17 → v18).
	static Future<void> migrarVersion17A18(Database base) async {
		await _agregarColumnaSiNoExiste(
			base,
			'products',
			'permite_stock_negativo',
			'INTEGER NOT NULL DEFAULT 0',
		);
		await _agregarColumnaSiNoExiste(
			base,
			'stores',
			'latitud',
			'REAL',
		);
		await _agregarColumnaSiNoExiste(
			base,
			'stores',
			'longitud',
			'REAL',
		);
		await _agregarColumnaSiNoExiste(
			base,
			'stores',
			'radio_metros_asistencia',
			'REAL DEFAULT 150',
		);
		await base.execute('''
			CREATE TABLE IF NOT EXISTS almacenes (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1,
				latitud REAL,
				longitud REAL,
				radio_metros REAL DEFAULT 150
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS stock_almacen (
				producto_id TEXT NOT NULL,
				almacen_id TEXT NOT NULL,
				cantidad REAL NOT NULL,
				actualizado_en TEXT NOT NULL,
				stock_minimo REAL NOT NULL DEFAULT 0,
				PRIMARY KEY (producto_id, almacen_id)
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS tipos_presentacion (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				unidad TEXT NOT NULL,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS presentaciones_producto (
				id TEXT PRIMARY KEY,
				producto_id TEXT NOT NULL,
				tipo_presentacion_id TEXT,
				nombre TEXT NOT NULL,
				factor_a_base REAL NOT NULL DEFAULT 1,
				es_presentacion_base INTEGER NOT NULL DEFAULT 0,
				codigo_barras TEXT NOT NULL DEFAULT '',
				precio REAL,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await base.execute('''
			INSERT OR IGNORE INTO tipos_presentacion (id, nombre, unidad, activo)
			VALUES
				('tp-caja', 'Caja', 'caja', 1),
				('tp-bulto', 'Bulto', 'pieza', 1),
				('tp-kg', 'Kilogramo', 'kilogramo', 1)
		''');
	}

	/// Asistencia de empleados (v18 → v19).
	static Future<void> migrarVersion18A19(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS desafios_asistencia (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				pin_hash TEXT NOT NULL,
				expira_en TEXT NOT NULL,
				creado_por TEXT NOT NULL,
				latitud REAL,
				longitud REAL,
				radio_metros REAL DEFAULT 150,
				activo INTEGER NOT NULL DEFAULT 1
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS registros_asistencia (
				id TEXT PRIMARY KEY,
				usuario_id TEXT NOT NULL,
				tienda_id TEXT NOT NULL,
				entrada_en TEXT NOT NULL,
				salida_en TEXT,
				metodo TEXT NOT NULL,
				latitud REAL,
				longitud REAL,
				desafio_id TEXT
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS empleado_perfil (
				usuario_id TEXT PRIMARY KEY,
				tarifa_hora REAL NOT NULL DEFAULT 0,
				tipo_pago TEXT NOT NULL DEFAULT 'por_hora',
				actualizado_en TEXT NOT NULL
			)
		''');
	}

	/// Periodos de nomina (v19 → v20).
	static Future<void> migrarVersion19A20(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS periodos_nomina (
				id TEXT PRIMARY KEY,
				tienda_id TEXT,
				inicio_en TEXT NOT NULL,
				fin_en TEXT NOT NULL,
				estado TEXT NOT NULL,
				cerrado_en TEXT,
				cerrado_por TEXT
			)
		''');
		await base.execute('''
			CREATE TABLE IF NOT EXISTS lineas_nomina (
				id TEXT PRIMARY KEY,
				periodo_id TEXT NOT NULL,
				usuario_id TEXT NOT NULL,
				horas_trabajadas REAL NOT NULL,
				tarifa_hora REAL NOT NULL,
				monto_bruto REAL NOT NULL,
				monto_neto REAL NOT NULL
			)
		''');
	}

	/// Elimina columna obsoleta tenant_id de la cola de sync (v20 → v21).
	static Future<void> migrarVersion20A21(Database base) async {
		final info = await base.rawQuery('PRAGMA table_info(sync_event_queue)');
		final tieneTenant = info.any((fila) => fila['name'] == 'tenant_id');
		if (!tieneTenant) {
			return;
		}
		await base.execute('''
			CREATE TABLE sync_event_queue_nueva (
				id TEXT PRIMARY KEY,
				tienda_id TEXT NOT NULL,
				dispositivo_id TEXT NOT NULL,
				tipo TEXT NOT NULL,
				payload TEXT NOT NULL,
				creado_en TEXT NOT NULL,
				estado TEXT NOT NULL
			)
		''');
		await base.execute('''
			INSERT INTO sync_event_queue_nueva (
				id, tienda_id, dispositivo_id, tipo, payload, creado_en, estado
			)
			SELECT id, tienda_id, dispositivo_id, tipo, payload, creado_en, estado
			FROM sync_event_queue
		''');
		await base.execute('DROP TABLE sync_event_queue');
		await base.execute(
			'ALTER TABLE sync_event_queue_nueva RENAME TO sync_event_queue',
		);
	}

	/// Recrea usuarios con pin_credencial; credenciales viejas se obtienen del hub.
	static Future<void> migrarVersion21A22(Database base) async {
		final info = await base.rawQuery('PRAGMA table_info(usuarios)');
		final tieneCredencial = info.any((fila) => fila['name'] == 'pin_credencial');
		if (tieneCredencial) {
			return;
		}
		await base.execute('DROP TABLE IF EXISTS usuarios');
		await _crearTablaUsuariosSegura(base);
	}

	/// v6.24: registro idempotente de eventos de sync ya aplicados.
	///
	/// Permite aplicar cada evento remoto exactamente una vez aunque el pull
	/// reintente una pagina (evita doble descuento/ajuste de stock).
	static Future<void> migrarVersion23A24(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS sync_eventos_aplicados (
				evento_id TEXT PRIMARY KEY,
				aplicado_en TEXT NOT NULL
			)
		''');
	}

	/// Indice de escalas mayoreo por producto (v24 → v25).
	static Future<void> migrarVersion24A25(Database base) async {
		await base.execute(
			'CREATE INDEX IF NOT EXISTS idx_wholesale_tiers_producto '
			'ON wholesale_tiers(producto_id)',
		);
	}

	/// Roles personalizados con permisos granulares (v25 → v26).
	static Future<void> migrarVersion25A26(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS roles_personalizados (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				descripcion TEXT NOT NULL DEFAULT '',
				permisos_json TEXT NOT NULL DEFAULT '[]',
				categorias_json TEXT NOT NULL DEFAULT '[]',
				activo INTEGER NOT NULL DEFAULT 1,
				tienda_id TEXT
			)
		''');
		await _agregarColumnaSiNoExiste(
			base,
			'usuarios',
			'rol_personalizado_id',
			'TEXT',
		);
	}

	/// v6.23: codigo de barras unico por tienda entre productos activos.
	static Future<void> migrarVersion22A23(Database base) async {
		await _resolverDuplicadosCodigoBarras(base);
		await base.execute('''
			CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_tienda_activo
			ON products(tienda_id, codigo_barras)
			WHERE activo = 1 AND codigo_barras != ''
		''');
	}

	static Future<void> _resolverDuplicadosCodigoBarras(Database base) async {
		final grupos = await base.rawQuery('''
			SELECT tienda_id, codigo_barras, COUNT(*) AS total
			FROM products
			WHERE activo = 1 AND codigo_barras != ''
			GROUP BY tienda_id, codigo_barras
			HAVING total > 1
		''');
		for (final grupo in grupos) {
			final tiendaId = grupo['tienda_id'] as String;
			final codigoBarras = grupo['codigo_barras'] as String;
			final productos = await base.query(
				'products',
				where: 'tienda_id = ? AND codigo_barras = ? AND activo = 1',
				whereArgs: [tiendaId, codigoBarras],
				orderBy: 'id ASC',
			);
			if (productos.length < 2) {
				continue;
			}
			var conservarId = productos.first['id'] as String;
			var maxStock = -1.0;
			for (final producto in productos) {
				final productoId = producto['id'] as String;
				final stockFilas = await base.rawQuery(
					'''
					SELECT COALESCE(SUM(cantidad), 0) AS total
					FROM stock_levels
					WHERE producto_id = ? AND tienda_id = ?
					''',
					[productoId, tiendaId],
				);
				final stock = (stockFilas.first['total'] as num?)?.toDouble() ?? 0.0;
				if (stock > maxStock ||
					(stock == maxStock && productoId.compareTo(conservarId) < 0)) {
					maxStock = stock;
					conservarId = productoId;
				}
			}
			for (final producto in productos) {
				final productoId = producto['id'] as String;
				if (productoId == conservarId) {
					continue;
				}
				final stocks = await base.query(
					'stock_levels',
					where: 'producto_id = ?',
					whereArgs: [productoId],
				);
				for (final stock in stocks) {
					final stockTiendaId = stock['tienda_id'] as String;
					final cantidad = (stock['cantidad'] as num).toDouble();
					final existente = await base.query(
						'stock_levels',
						where: 'producto_id = ? AND tienda_id = ?',
						whereArgs: [conservarId, stockTiendaId],
						limit: 1,
					);
					if (existente.isEmpty) {
						await base.insert('stock_levels', {
							'producto_id': conservarId,
							'tienda_id': stockTiendaId,
							'cantidad': cantidad,
							'actualizado_en': stock['actualizado_en'],
							'stock_minimo': stock['stock_minimo'] ?? 0,
						});
					} else {
						final actual = (existente.first['cantidad'] as num).toDouble();
						await base.update(
							'stock_levels',
							{'cantidad': actual + cantidad},
							where: 'producto_id = ? AND tienda_id = ?',
							whereArgs: [conservarId, stockTiendaId],
						);
					}
				}
				await base.delete(
					'stock_levels',
					where: 'producto_id = ?',
					whereArgs: [productoId],
				);
				await base.update(
					'products',
					{'activo': 0},
					where: 'id = ?',
					whereArgs: [productoId],
				);
			}
		}
	}
}
