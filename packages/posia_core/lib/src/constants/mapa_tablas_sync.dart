/// Mapa canónico de tablas SQLite local ↔ espejo Neon/Postgres.
///
/// La clasificacion A/B/C vive en [ClasificacionArquitecturaSync].
/// Este mapa mantiene renombres y listas derivadas para auditorias.
library;

/// Par de nombres entre el POS local y el hub.
class ParTablaSync {
	const ParTablaSync({
		required this.sqlite,
		required this.neon,
		this.notas = '',
	});

	/// Nombre en SQLite (`posia_operativa.db`).
	final String sqlite;

	/// Nombre en Neon/Postgres.
	final String neon;

	/// Nota operativa (local-only, hub-only, etc.).
	final String notas;

	bool get mismoNombre => sqlite == neon;
}

/// Inventario de correspondencia entre esquemas.
abstract final class MapaTablasSync {
	MapaTablasSync._();

	/// Renombres explícitos SQLite → Neon.
	static const List<ParTablaSync> renombres = [
		ParTablaSync(sqlite: 'usuarios', neon: 'users'),
		ParTablaSync(sqlite: 'roles_personalizados', neon: 'custom_roles'),
		ParTablaSync(sqlite: 'proveedores', neon: 'suppliers'),
		ParTablaSync(
			sqlite: 'presentaciones_producto',
			neon: 'product_presentations',
		),
		ParTablaSync(sqlite: 'stock_almacen', neon: 'warehouse_stock'),
		ParTablaSync(
			sqlite: 'desafios_asistencia',
			neon: 'attendance_challenges',
		),
		ParTablaSync(
			sqlite: 'registros_asistencia',
			neon: 'attendance_records',
		),
		ParTablaSync(sqlite: 'empleado_perfil', neon: 'employee_profiles'),
		ParTablaSync(sqlite: 'periodos_nomina', neon: 'payroll_periods'),
		ParTablaSync(sqlite: 'lineas_nomina', neon: 'payroll_lines'),
	];

	/// Columnas con nombre distinto pero mismo significado.
	static const List<ParTablaSync> columnasRenombradas = [
		ParTablaSync(
			sqlite: 'stores.radio_metros',
			neon: 'stores.radio_metros',
			notas: 'Antes local: radio_metros_asistencia; payload: radioMetros',
		),
	];

	/// Tablas espejo con el mismo nombre en ambos motores.
	static const List<String> compartidasMismoNombre = [
		'stores',
		'categories',
		'products',
		'customers',
		'sales',
		'sale_lines',
		'stock_levels',
		'product_variants',
		'transfers',
		'transfer_lines',
		'wholesale_tiers',
		'lotes_promocion',
		'lote_promocion_miembros',
		'price_lists',
		'price_list_items',
		'customer_product_prices',
		'customer_discounts',
		'tipos_presentacion',
		'quotes',
		'quote_lines',
		'orders',
		'order_lines',
		'almacenes',
		'purchases',
		'purchase_lines',
		'cash_shifts',
	];

	/// Solo SQLite (no se proyectan a Neon).
	static const List<String> soloLocal = [
		'vendedores',
		'pharmacy_lots',
		'held_tickets',
		'held_ticket_lines',
		'inventory_movements',
		'sync_event_queue',
		'sync_state',
		'sync_eventos_aplicados',
		'app_config',
		'ejemplo',
	];

	/// Solo hub / infraestructura Neon.
	static const List<String> soloHub = [
		'sync_events',
		'schema_meta',
	];

	/// Resuelve el nombre Neon a partir del nombre SQLite.
	static String neonDesdeSqlite(String tablaSqlite) {
		for (final par in renombres) {
			if (par.sqlite == tablaSqlite) {
				return par.neon;
			}
		}
		return tablaSqlite;
	}

	/// Resuelve el nombre SQLite a partir del nombre Neon.
	static String sqliteDesdeNeon(String tablaNeon) {
		for (final par in renombres) {
			if (par.neon == tablaNeon) {
				return par.sqlite;
			}
		}
		return tablaNeon;
	}

	/// Tablas clave a inspeccionar en auditorías Neon (nombres reales del hub).
	static const List<String> tablasClaveAuditoriaNeon = [
		'products',
		'sales',
		'sale_lines',
		'customers',
		'quotes',
		'orders',
		'wholesale_tiers',
		'product_presentations',
		'tipos_presentacion',
		'attendance_records',
		'users',
		'suppliers',
		'warehouse_stock',
		'cash_shifts',
		'customer_discounts',
		'employee_profiles',
		'payroll_periods',
	];
}
