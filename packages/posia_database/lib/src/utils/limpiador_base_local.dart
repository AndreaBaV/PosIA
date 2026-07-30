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
		'purchase_allocations',
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
		'lote_promocion_miembros',
		'lotes_promocion',
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
		IdsEjemplo.producto,
		IdsEjemplo.categoria,
		IdsEjemplo.cliente,
		IdsEjemplo.vendedor,
		IdsEjemplo.proveedor,
		IdsEjemplo.usuario,
		IdsEjemplo.tienda,
	];

	/// Quita filas guia y registros demo insertados al crear el esquema.
	static Future<bool> eliminarDatosEjemplo(Database base) async {
		var elimino = false;
		// Hijos antes que padres (FK v33 en products.tienda_id, etc.).
		final filasStock = await base.delete(
			'stock_levels',
			where: 'producto_id = ?',
			whereArgs: [IdsEjemplo.producto],
		);
		if (filasStock > 0) {
			elimino = true;
		}
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

	/// Tablas de control del sync que dejan de tener sentido tras vaciar.
	///
	/// `sync_eventos_aplicados` es el registro de "esto ya lo apliqué": si
	/// sobrevive al vaciado, el replay desde origen se salta cada venta, ajuste
	/// de stock y traspaso historico y el equipo se queda sin operaciones.
	/// `sync_eventos_cuarentena` guarda eventos del mismo historial que se va a
	/// volver a descargar entero, asi que reintentarlos solo duplica trabajo.
	static const _tablasControlSync = [
		'sync_eventos_aplicados',
		'sync_eventos_cuarentena',
	];

	/// Vacia tablas de negocio conservando la cola de envio pendiente.
	///
	/// El cursor lo reinicia quien llama (reconciliacion): esta limpieza asume
	/// que despues viene una reconstruccion completa desde el hub.
	static Future<void> vaciarDatosOperativos(Database base) async {
		await base.transaction((tx) async {
			for (final tabla in [..._tablasOperativas, ..._tablasControlSync]) {
				try {
					await tx.delete(tabla);
				} on Object {
					// Tabla puede no existir en versiones antiguas del esquema.
				}
			}
		});
	}
}
