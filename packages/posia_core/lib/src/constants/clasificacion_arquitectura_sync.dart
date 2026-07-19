/// Clasificacion arquitectonica offline-first: SQLite registro, Neon proyeccion+log.
///
/// Cada tabla y cada [TipoSyncEvento] debe pertenecer a una politica explicita.
/// No debe existir zona gris (evento emitido sin proyector/aplicador).
library;

import '../enums/tipo_sync_evento.dart';
import 'mapa_tablas_sync.dart';

/// Rol de una tabla en la arquitectura de sync.
enum ClaseTablaSync {
	/// (A) Espejo obligatorio: cambia en un dispositivo y debe llegar a los demas + Neon.
	espejoObligatorio,

	/// (B) Solo dispositivo: estado efimero, derivado o infra local.
	soloLocal,

	/// (C) Solo hub: log/meta de sincronizacion.
	soloHub,
}

/// Politica de un tipo de evento en el log.
enum PoliticaEventoSync {
	/// Debe proyectarse a Neon y aplicarse en SQLite remoto.
	activo,

	/// Se acepta en el log historico pero no se emite ni se aplica (reemplazado).
	legacyIgnorado,
}

/// Entrada de clasificacion de tabla.
class TablaClasificada {
	const TablaClasificada({
		required this.sqlite,
		required this.clase,
		required this.motivo,
		this.neon,
	});

	final String sqlite;
	final String? neon;
	final ClaseTablaSync clase;
	final String motivo;

	String get nombreNeon => neon ?? sqlite;
}

/// Contrato de un [TipoSyncEvento].
class ContratoEventoSync {
	const ContratoEventoSync({
		required this.tipo,
		required this.politica,
		required this.motivo,
		this.tablasAfectadas = const [],
	});

	final TipoSyncEvento tipo;
	final PoliticaEventoSync politica;
	final String motivo;
	final List<String> tablasAfectadas;

	bool get requiereProyector => politica == PoliticaEventoSync.activo;
}

/// Decisiones de arquitectura sync (fuente de verdad).
abstract final class ClasificacionArquitecturaSync {
	ClasificacionArquitecturaSync._();

	/// Inventario completo de tablas con clase A/B/C.
	static const List<TablaClasificada> tablas = [
		// --- (A) Espejo obligatorio ---
		TablaClasificada(
			sqlite: 'stores',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Catalogo de sucursales compartido',
		),
		TablaClasificada(
			sqlite: 'categories',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Catalogo de categorias',
		),
		TablaClasificada(
			sqlite: 'products',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Catalogo de productos (incluye costo, stock negativo, favorito)',
		),
		TablaClasificada(
			sqlite: 'product_variants',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Variantes de producto',
		),
		TablaClasificada(
			sqlite: 'tipos_presentacion',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Tipos de empaque personalizados deben replicarse',
		),
		TablaClasificada(
			sqlite: 'presentaciones_producto',
			neon: 'product_presentations',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Empaques por producto via productPresentationsReplaced',
		),
		TablaClasificada(
			sqlite: 'almacenes',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Centros de stock multi-dispositivo',
		),
		TablaClasificada(
			sqlite: 'stock_almacen',
			neon: 'warehouse_stock',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Existencias por almacen',
		),
		TablaClasificada(
			sqlite: 'stock_levels',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Existencias por tienda',
		),
		TablaClasificada(
			sqlite: 'customers',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Clientes y credito',
		),
		TablaClasificada(
			sqlite: 'proveedores',
			neon: 'suppliers',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Proveedores de compra',
		),
		TablaClasificada(
			sqlite: 'usuarios',
			neon: 'users',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Cuentas y PIN (hash) multi-caja',
		),
		TablaClasificada(
			sqlite: 'roles_personalizados',
			neon: 'custom_roles',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Permisos personalizados',
		),
		TablaClasificada(
			sqlite: 'sales',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Ventas como hechos de negocio',
		),
		TablaClasificada(
			sqlite: 'sale_lines',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lineas de venta (snapshot; IDs locales no viajan)',
		),
		TablaClasificada(
			sqlite: 'cash_shifts',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Turnos de caja visibles en hub y otras cajas',
		),
		TablaClasificada(
			sqlite: 'transfers',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Traspasos entre tiendas/almacenes',
		),
		TablaClasificada(
			sqlite: 'transfer_lines',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lineas de traspaso',
		),
		TablaClasificada(
			sqlite: 'quotes',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Cotizaciones',
		),
		TablaClasificada(
			sqlite: 'quote_lines',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lineas de cotizacion',
		),
		TablaClasificada(
			sqlite: 'orders',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Pedidos y asignacion',
		),
		TablaClasificada(
			sqlite: 'order_lines',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lineas de pedido',
		),
		TablaClasificada(
			sqlite: 'purchases',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Compras a proveedor',
		),
		TablaClasificada(
			sqlite: 'purchase_lines',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lineas de compra',
		),
		TablaClasificada(
			sqlite: 'wholesale_tiers',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Escalas de mayoreo',
		),
		TablaClasificada(
			sqlite: 'lotes_promocion',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lotes mix-and-match de mayoreo',
		),
		TablaClasificada(
			sqlite: 'lote_promocion_miembros',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Miembros de lote promocion',
		),
		TablaClasificada(
			sqlite: 'price_lists',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Listas de precios comerciales',
		),
		TablaClasificada(
			sqlite: 'price_list_items',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Precios por lista',
		),
		TablaClasificada(
			sqlite: 'customer_product_prices',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Precios preferenciales cliente-producto',
		),
		TablaClasificada(
			sqlite: 'customer_discounts',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Descuentos comerciales de cliente',
		),
		TablaClasificada(
			sqlite: 'desafios_asistencia',
			neon: 'attendance_challenges',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'PIN de asistencia multi-dispositivo',
		),
		TablaClasificada(
			sqlite: 'registros_asistencia',
			neon: 'attendance_records',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Checadas de empleados',
		),
		TablaClasificada(
			sqlite: 'empleado_perfil',
			neon: 'employee_profiles',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Tarifas de nomina',
		),
		TablaClasificada(
			sqlite: 'periodos_nomina',
			neon: 'payroll_periods',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Periodos cerrados de nomina',
		),
		TablaClasificada(
			sqlite: 'lineas_nomina',
			neon: 'payroll_lines',
			clase: ClaseTablaSync.espejoObligatorio,
			motivo: 'Lineas de nomina del periodo',
		),

		// --- (B) Solo local ---
		TablaClasificada(
			sqlite: 'vendedores',
			clase: ClaseTablaSync.soloLocal,
			motivo:
				'Proyeccion local de usuarios para UX de caja; la identidad canonica es usuarios/users',
		),
		TablaClasificada(
			sqlite: 'pharmacy_lots',
			clase: ClaseTablaSync.soloLocal,
			motivo:
				'Sin alta operativa multi-caja aun; saleCompleted ya lleva loteId/etiqueta como snapshot. Promover a (A) cuando exista admin de lotes',
		),
		TablaClasificada(
			sqlite: 'held_tickets',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Estado efimero de ticket en espera por caja',
		),
		TablaClasificada(
			sqlite: 'held_ticket_lines',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Lineas del ticket en espera',
		),
		TablaClasificada(
			sqlite: 'inventory_movements',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Auditoria local derivable de stockAdjusted/ventas/compras',
		),
		TablaClasificada(
			sqlite: 'sync_event_queue',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Cola de salida del dispositivo',
		),
		TablaClasificada(
			sqlite: 'sync_state',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Cursor de pull local',
		),
		TablaClasificada(
			sqlite: 'sync_eventos_aplicados',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Idempotencia de aplicacion remota',
		),
		TablaClasificada(
			sqlite: 'app_config',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Configuracion de dispositivo',
		),
		TablaClasificada(
			sqlite: 'ejemplo',
			clase: ClaseTablaSync.soloLocal,
			motivo: 'Placeholders de guia/desarrollo',
		),

		// --- (C) Solo hub ---
		TablaClasificada(
			sqlite: 'sync_events',
			neon: 'sync_events',
			clase: ClaseTablaSync.soloHub,
			motivo: 'Log append-only fuente de verdad del hub',
		),
		TablaClasificada(
			sqlite: 'schema_meta',
			neon: 'schema_meta',
			clase: ClaseTablaSync.soloHub,
			motivo: 'Flags de backfill y retencion del hub',
		),
	];

	/// Contratos de todos los [TipoSyncEvento] (sin zona gris).
	static const List<ContratoEventoSync> eventos = [
		ContratoEventoSync(
			tipo: TipoSyncEvento.saleCompleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Hecho de venta',
			tablasAfectadas: ['sales', 'sale_lines', 'stock_levels'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.productUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Catalogo producto',
			tablasAfectadas: ['products'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.stockAdjusted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Ajuste de inventario',
			tablasAfectadas: ['stock_levels', 'stock_almacen'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.transferRequested,
			politica: PoliticaEventoSync.activo,
			motivo: 'Traspaso solicitado',
			tablasAfectadas: ['transfers', 'transfer_lines'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.transferCompleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Traspaso completado',
			tablasAfectadas: ['transfers', 'transfer_lines', 'stock_levels'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.customerUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Cliente',
			tablasAfectadas: ['customers'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.saleVoided,
			politica: PoliticaEventoSync.activo,
			motivo: 'Anulacion de venta',
			tablasAfectadas: ['sales', 'stock_levels'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.categoryUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Categoria',
			tablasAfectadas: ['categories'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.variantUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Variante',
			tablasAfectadas: ['product_variants'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.salePartialReturn,
			politica: PoliticaEventoSync.activo,
			motivo: 'Devolucion parcial',
			tablasAfectadas: ['sales', 'sale_lines', 'stock_levels'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.storeUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Tienda',
			tablasAfectadas: ['stores'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.warehouseUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Almacen',
			tablasAfectadas: ['almacenes'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.presentationTypeUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Tipo de presentacion personalizado',
			tablasAfectadas: ['tipos_presentacion'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.productPresentationUpserted,
			politica: PoliticaEventoSync.legacyIgnorado,
			motivo:
				'Reemplazado por productPresentationsReplaced; se ignora en pull/proyeccion',
			tablasAfectadas: ['presentaciones_producto'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.attendanceChallengeCreated,
			politica: PoliticaEventoSync.activo,
			motivo: 'Desafio asistencia',
			tablasAfectadas: ['desafios_asistencia'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.attendanceCheckedIn,
			politica: PoliticaEventoSync.activo,
			motivo: 'Entrada',
			tablasAfectadas: ['registros_asistencia'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.attendanceCheckedOut,
			politica: PoliticaEventoSync.activo,
			motivo: 'Salida',
			tablasAfectadas: ['registros_asistencia'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.employeeProfileUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Perfil nomina',
			tablasAfectadas: ['empleado_perfil'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.payrollPeriodClosed,
			politica: PoliticaEventoSync.activo,
			motivo: 'Cierre nomina',
			tablasAfectadas: ['periodos_nomina', 'lineas_nomina'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.userUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Usuario',
			tablasAfectadas: ['usuarios'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.cashShiftUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Turno de caja',
			tablasAfectadas: ['cash_shifts'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.quoteUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Cotizacion',
			tablasAfectadas: ['quotes', 'quote_lines'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.quoteDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado cotizacion',
			tablasAfectadas: ['quotes', 'quote_lines'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.orderUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Pedido',
			tablasAfectadas: ['orders', 'order_lines'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.wholesaleTiersReplaced,
			politica: PoliticaEventoSync.activo,
			motivo: 'Escalas mayoreo',
			tablasAfectadas: ['wholesale_tiers'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.lotePromocionReplaced,
			politica: PoliticaEventoSync.activo,
			motivo: 'Lote promocion',
			tablasAfectadas: ['lotes_promocion', 'lote_promocion_miembros'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.comboReplaced,
			politica: PoliticaEventoSync.activo,
			motivo: 'Combo de precio fijo',
			tablasAfectadas: ['combos', 'combo_miembros'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.productPresentationsReplaced,
			politica: PoliticaEventoSync.activo,
			motivo: 'Reemplazo atomico de empaques',
			tablasAfectadas: ['presentaciones_producto'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.customRoleUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Rol personalizado',
			tablasAfectadas: ['roles_personalizados'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.priceListUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Lista precios',
			tablasAfectadas: ['price_lists'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.priceListDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado lista',
			tablasAfectadas: ['price_lists', 'price_list_items'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.priceListItemUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Item lista',
			tablasAfectadas: ['price_list_items'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.priceListItemDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado item lista',
			tablasAfectadas: ['price_list_items'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.customerProductPriceUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Precio cliente-producto',
			tablasAfectadas: ['customer_product_prices'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.customerProductPriceDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado precio cliente',
			tablasAfectadas: ['customer_product_prices'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.supplierUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Proveedor',
			tablasAfectadas: ['proveedores'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.supplierDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado proveedor',
			tablasAfectadas: ['proveedores'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.purchaseCompleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Compra',
			tablasAfectadas: ['purchases', 'purchase_lines', 'stock_levels'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.customerDiscountUpserted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Descuento cliente',
			tablasAfectadas: ['customer_discounts'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.customerDiscountDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado descuento',
			tablasAfectadas: ['customer_discounts'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.productDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado manual de producto: lapida, gana sobre cualquier '
				'productUpserted posterior',
			tablasAfectadas: ['entidades_eliminadas', 'products'],
		),
		ContratoEventoSync(
			tipo: TipoSyncEvento.categoryDeleted,
			politica: PoliticaEventoSync.activo,
			motivo: 'Borrado manual de categoria: lapida, gana sobre cualquier '
				'categoryUpserted posterior',
			tablasAfectadas: ['entidades_eliminadas', 'categories'],
		),
	];

	static ContratoEventoSync contratoDe(TipoSyncEvento tipo) {
		return eventos.firstWhere((c) => c.tipo == tipo);
	}

	static List<TablaClasificada> tablasDeClase(ClaseTablaSync clase) {
		return tablas.where((t) => t.clase == clase).toList();
	}

	/// Verifica que todo [TipoSyncEvento] tenga contrato (falla en tests).
	static List<TipoSyncEvento> eventosSinContrato() {
		final cubiertos = eventos.map((c) => c.tipo).toSet();
		return TipoSyncEvento.values
			.where((t) => !cubiertos.contains(t))
			.toList();
	}

	/// Sincroniza listas derivadas de [MapaTablasSync] con esta clasificacion.
	static void alinearMapaDerivado() {
		// Documental: MapaTablasSync.* debe coincidir con tablasDeClase.
		// La verificacion ejecutable vive en test.
	}

	static List<String> inconsistenciasConMapa() {
		final errores = <String>[];
		final porSqlite = {for (final t in tablas) t.sqlite: t};

		for (final nombre in MapaTablasSync.soloLocal) {
			final t = porSqlite[nombre];
			if (t == null) {
				errores.add('Mapa soloLocal "$nombre" ausente en clasificacion');
			} else if (t.clase != ClaseTablaSync.soloLocal) {
				errores.add('Mapa soloLocal "$nombre" clasificado como ${t.clase}');
			}
		}
		for (final nombre in MapaTablasSync.soloHub) {
			final t = porSqlite[nombre];
			if (t == null) {
				errores.add('Mapa soloHub "$nombre" ausente en clasificacion');
			} else if (t.clase != ClaseTablaSync.soloHub) {
				errores.add('Mapa soloHub "$nombre" clasificado como ${t.clase}');
			}
		}
		for (final faltante in eventosSinContrato()) {
			errores.add('Evento sin contrato: ${faltante.name}');
		}
		return errores;
	}
}
