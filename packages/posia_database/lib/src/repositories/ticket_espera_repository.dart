/// Repositorio SQLite de tickets en espera (carritos apartados).
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste carritos apartados por tienda y caja.
class TicketEsperaRepository {
	TicketEsperaRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	Future<void> guardar(TicketEnEspera ticket) async {
		await _baseDatos.transaction((tx) async {
			await tx.insert(
				'held_tickets',
				_mapearMapa(ticket),
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
			await tx.delete(
				'held_ticket_lines',
				where: 'ticket_id = ?',
				whereArgs: [ticket.id],
			);
			for (final linea in ticket.lineas) {
				await tx.insert('held_ticket_lines', {
					'ticket_id': ticket.id,
					'producto_id': linea.productoId,
					'nombre_producto': linea.nombreProducto,
					'cantidad': linea.cantidad,
					'precio_unitario': linea.precioUnitario,
					'regla_precio': linea.reglaPrecio.name,
					'lote_id': linea.loteId,
					'etiqueta_lote': linea.etiquetaLote,
					'descuento_linea': linea.descuentoLinea,
					'codigo_barras': linea.codigoBarras,
					'unidad_medida': linea.unidadMedida.name,
					'modulo_vertical': linea.moduloVertical.name,
					'categoria_id': linea.categoriaId,
				});
			}
		});
	}

	Future<TicketEnEspera?> obtenerPorId(String ticketId) async {
		final filas = await _baseDatos.query(
			'held_tickets',
			where: 'id = ?',
			whereArgs: [ticketId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearTicket(filas.first);
	}

	Future<List<TicketEnEspera>> listarPorTiendaCaja(
		String tiendaId,
		String cajaId,
	) async {
		final filas = await _baseDatos.query(
			'held_tickets',
			where: 'tienda_id = ? AND caja_id = ?',
			whereArgs: [tiendaId, cajaId],
			orderBy: 'creado_en DESC',
		);
		final tickets = <TicketEnEspera>[];
		for (final fila in filas) {
			tickets.add(await _mapearTicket(fila));
		}
		return tickets;
	}

	Future<int> contarPorTiendaCaja(String tiendaId, String cajaId) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM held_tickets '
			'WHERE tienda_id = ? AND caja_id = ?',
			[tiendaId, cajaId],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	Future<void> eliminar(String ticketId) async {
		await _baseDatos.transaction((tx) async {
			await tx.delete(
				'held_ticket_lines',
				where: 'ticket_id = ?',
				whereArgs: [ticketId],
			);
			await tx.delete(
				'held_tickets',
				where: 'id = ?',
				whereArgs: [ticketId],
			);
		});
	}

	Future<TicketEnEspera> _mapearTicket(Map<String, Object?> fila) async {
		final ticketId = fila['id'] as String;
		final filasLineas = await _baseDatos.query(
			'held_ticket_lines',
			where: 'ticket_id = ?',
			whereArgs: [ticketId],
		);
		final lineas = filasLineas.map(_mapearLinea).toList();
		return TicketEnEspera(
			id: ticketId,
			tiendaId: fila['tienda_id'] as String,
			cajaId: fila['caja_id'] as String,
			clienteId: fila['cliente_id'] as String?,
			nombreCliente: fila['nombre_cliente'] as String?,
			vendedorId: fila['vendedor_id'] as String?,
			notas: fila['notas'] as String? ?? '',
			descuentoTicket: (fila['descuento_ticket'] as num?)?.toDouble() ?? 0.0,
			total: (fila['total'] as num).toDouble(),
			creadoEn: DateTime.parse(fila['creado_en'] as String),
			lineas: lineas,
		);
	}

	LineaTicketEspera _mapearLinea(Map<String, Object?> fila) {
		return LineaTicketEspera(
			productoId: fila['producto_id'] as String,
			nombreProducto: fila['nombre_producto'] as String,
			cantidad: (fila['cantidad'] as num).toDouble(),
			precioUnitario: (fila['precio_unitario'] as num).toDouble(),
			reglaPrecio: ReglaPrecio.values.byName(fila['regla_precio'] as String),
			loteId: fila['lote_id'] as String?,
			etiquetaLote: fila['etiqueta_lote'] as String?,
			descuentoLinea: (fila['descuento_linea'] as num?)?.toDouble() ?? 0.0,
			codigoBarras: fila['codigo_barras'] as String? ?? '',
			unidadMedida: UnidadMedida.values.byName(
				fila['unidad_medida'] as String? ?? UnidadMedida.pieza.name,
			),
			moduloVertical: ModuloVertical.values.byName(
				fila['modulo_vertical'] as String? ?? ModuloVertical.general.name,
			),
			categoriaId: fila['categoria_id'] as String?,
		);
	}

	Map<String, Object?> _mapearMapa(TicketEnEspera ticket) {
		return {
			'id': ticket.id,
			'tienda_id': ticket.tiendaId,
			'caja_id': ticket.cajaId,
			'cliente_id': ticket.clienteId,
			'nombre_cliente': ticket.nombreCliente,
			'vendedor_id': ticket.vendedorId,
			'notas': ticket.notas,
			'descuento_ticket': ticket.descuentoTicket,
			'total': ticket.total,
			'creado_en': ticket.creadoEn.toIso8601String(),
		};
	}
}
