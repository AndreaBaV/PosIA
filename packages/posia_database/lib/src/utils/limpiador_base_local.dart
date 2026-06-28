/// Limpieza de datos operativos y placeholders en SQLite local.
library;

import 'package:sqflite/sqflite.dart';

import '../seed/placeholders_ejemplo.dart';

/// Elimina registros de ejemplo y vacia tablas operativas del tenant.
class LimpiadorBaseLocal {
	const LimpiadorBaseLocal._();

	static const _tablasOperativas = [
		'sale_lines',
		'sales',
		'order_lines',
		'orders',
		'quote_lines',
		'quotes',
		'purchase_lines',
		'purchases',
		'transfer_lines',
		'transfers',
		'held_ticket_lines',
		'held_tickets',
		'lineas_nomina',
		'periodos_nomina',
		'registros_asistencia',
		'desafios_asistencia',
		'empleado_perfil',
		'inventory_movements',
		'cash_shifts',
		'stock_almacen',
		'stock_levels',
		'pharmacy_lots',
		'presentaciones_producto',
		'product_variants',
		'price_list_items',
		'price_lists',
		'customer_product_prices',
		'wholesale_tiers',
		'customer_discounts',
		'products',
		'categories',
		'customers',
		'vendedores',
		'proveedores',
		'usuarios',
		'stores',
		'almacenes',
		'tipos_presentacion',
		'ejemplo',
	];

	static const _idsEjemplo = [
		IdsEjemplo.tienda,
		IdsEjemplo.categoria,
		IdsEjemplo.producto,
		IdsEjemplo.cliente,
		IdsEjemplo.vendedor,
		IdsEjemplo.proveedor,
		IdsEjemplo.usuario,
	];

	/// Quita filas guia y registros demo insertados al crear el esquema.
	static Future<bool> eliminarDatosEjemplo(Database base) async {
		var elimino = false;
		for (final id in _idsEjemplo) {
			for (final tabla in _tablasPorIdEjemplo(id)) {
				final filas = await base.delete(
					tabla,
					where: 'id = ?',
					whereArgs: [id],
				);
				if (filas > 0) {
					elimino = true;
				}
			}
		}
		await base.delete(
			'stock_levels',
			where: 'producto_id = ?',
			whereArgs: [IdsEjemplo.producto],
		);
		await base.delete(
			'vendedores',
			where: "codigo = 'ejemplo'",
		);
		final guia = await base.delete('ejemplo');
		if (guia > 0) {
			elimino = true;
		}
		return elimino;
	}

	static List<String> _tablasPorIdEjemplo(String id) {
		switch (id) {
			case IdsEjemplo.tienda:
				return ['stores'];
			case IdsEjemplo.categoria:
				return ['categories'];
			case IdsEjemplo.producto:
				return ['products'];
			case IdsEjemplo.cliente:
				return ['customers'];
			case IdsEjemplo.vendedor:
				return ['vendedores'];
			case IdsEjemplo.proveedor:
				return ['proveedores'];
			case IdsEjemplo.usuario:
				return ['usuarios'];
			default:
				return [];
		}
	}

	/// Vacia tablas de negocio conservando cola y cursor de sync.
	static Future<void> vaciarDatosOperativos(Database base) async {
		await base.transaction((tx) async {
			for (final tabla in _tablasOperativas) {
				try {
					await tx.delete(tabla);
				} on Object {
					// Tabla puede no existir en versiones antiguas del esquema.
				}
			}
		});
	}
}
