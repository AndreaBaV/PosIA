/// Repositorio SQLite de pedidos.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

/// Persiste pedidos y lineas de detalle.
class PedidoRepository {
	PedidoRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	/// Cuenta pedidos asociados a un cliente.
	Future<int> contarPorCliente(String clienteId) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM orders WHERE cliente_id = ?',
			[clienteId],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	Future<void> guardar(Pedido pedido) async {
		await _padresFk.asegurarPadresDePedido(pedido);
		await _padresFk.asegurarPedido(pedido.id, tiendaId: pedido.tiendaId);
		await _baseDatos.transaction((transaccion) async {
			await transaccion.insert(
				'orders',
				_mapearMapa(pedido),
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
			await transaccion.delete(
				'order_lines',
				where: 'pedido_id = ?',
				whereArgs: [pedido.id],
			);
			for (final linea in pedido.lineas) {
				await transaccion.insert('order_lines', {
					'pedido_id': pedido.id,
					'producto_id': linea.productoId,
					'nombre_producto': linea.nombreProducto,
					'cantidad': linea.cantidad,
					'precio_unitario': linea.precioUnitario,
					'subtotal': linea.subtotal,
				});
			}
		});
	}

	Future<Pedido?> obtenerPorId(String pedidoId) async {
		final filas = await _baseDatos.query(
			'orders',
			where: 'id = ?',
			whereArgs: [pedidoId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearPedido(filas.first);
	}

	Future<List<Pedido>> listarPorTienda(
		String tiendaId, {
		EstadoPedido? estado,
		bool soloSinAsignar = false,
	}) async {
		final condiciones = <String>['tienda_id = ?'];
		final args = <Object?>[tiendaId];
		if (estado != null) {
			condiciones.add('estado = ?');
			args.add(estado.name);
		}
		if (soloSinAsignar) {
			condiciones.add("estado = 'recibido'");
			condiciones.add('asignado_a_usuario_id IS NULL');
		}
		final filas = await _baseDatos.query(
			'orders',
			where: condiciones.join(' AND '),
			whereArgs: args,
			orderBy: 'creado_en DESC',
		);
		final pedidos = <Pedido>[];
		for (final fila in filas) {
			pedidos.add(await _mapearPedido(fila));
		}
		return pedidos;
	}

	/// Pedidos entregados de una tienda dentro de un periodo (por fecha de pedido).
	Future<List<Pedido>> listarEntregadosPorTiendaEnPeriodo(
		String tiendaId, {
		required DateTime desde,
	}) async {
		final filas = await _baseDatos.query(
			'orders',
			where: 'tienda_id = ? AND estado = ? AND creado_en >= ?',
			whereArgs: [
				tiendaId,
				EstadoPedido.entregado.name,
				desde.toUtc().toIso8601String(),
			],
			orderBy: 'creado_en DESC',
		);
		final pedidos = <Pedido>[];
		for (final fila in filas) {
			pedidos.add(await _mapearPedido(fila));
		}
		return pedidos;
	}

	Future<List<Pedido>> listarPorEmpleado(String usuarioId) async {
		final filas = await _baseDatos.query(
			'orders',
			where: 'asignado_a_usuario_id = ? AND estado != ?',
			whereArgs: [usuarioId, EstadoPedido.cancelado.name],
			orderBy: 'asignado_en DESC, creado_en DESC',
		);
		final pedidos = <Pedido>[];
		for (final fila in filas) {
			pedidos.add(await _mapearPedido(fila));
		}
		return pedidos;
	}

	Future<Pedido> _mapearPedido(Map<String, Object?> fila) async {
		final pedidoId = fila['id'] as String;
		final filasLineas = await _baseDatos.query(
			'order_lines',
			where: 'pedido_id = ?',
			whereArgs: [pedidoId],
		);
		final lineas = filasLineas
			.map(
				(l) => LineaPedido(
					productoId: l['producto_id'] as String,
					nombreProducto: l['nombre_producto'] as String,
					cantidad: (l['cantidad'] as num).toDouble(),
					precioUnitario: (l['precio_unitario'] as num).toDouble(),
				),
			)
			.toList();
		final venceRaw = fila['credito_vence_en'] as String?;
		final asignadoRaw = fila['asignado_en'] as String?;
		return Pedido(
			id: pedidoId,
			tiendaId: fila['tienda_id'] as String,
			clienteId: fila['cliente_id'] as String?,
			nombreEntrega: fila['nombre_entrega'] as String,
			telefonoEntrega: fila['telefono_entrega'] as String,
			direccionEntrega: fila['direccion_entrega'] as String,
			esCredito: (fila['es_credito'] as int) == 1,
			creditoDias: fila['credito_dias'] as int?,
			creditoVenceEn: venceRaw == null ? null : DateTime.parse(venceRaw),
			metodoPago: MetodoPago.values.byName(fila['metodo_pago'] as String),
			total: (fila['total'] as num).toDouble(),
			notas: fila['notas'] as String? ?? '',
			estado: EstadoPedido.values.byName(fila['estado'] as String),
			asignadoAUsuarioId: fila['asignado_a_usuario_id'] as String?,
			asignadoAUsuarioNombre: fila['asignado_a_usuario_nombre'] as String?,
			asignadoEn: asignadoRaw == null ? null : DateTime.parse(asignadoRaw),
			creadoEn: DateTime.parse(fila['creado_en'] as String),
			creadoPorUsuarioId: fila['creado_por_usuario_id'] as String?,
			ventaId: fila['venta_id'] as String?,
			lineas: lineas,
		);
	}

	Map<String, Object?> _mapearMapa(Pedido pedido) {
		return {
			'id': pedido.id,
			'tienda_id': pedido.tiendaId,
			'cliente_id': pedido.clienteId,
			'nombre_entrega': pedido.nombreEntrega,
			'telefono_entrega': pedido.telefonoEntrega,
			'direccion_entrega': pedido.direccionEntrega,
			'es_credito': pedido.esCredito ? 1 : 0,
			'credito_dias': pedido.creditoDias,
			'credito_vence_en': pedido.creditoVenceEn?.toIso8601String(),
			'metodo_pago': pedido.metodoPago.name,
			'total': pedido.total,
			'notas': pedido.notas,
			'estado': pedido.estado.name,
			'asignado_a_usuario_id': pedido.asignadoAUsuarioId,
			'asignado_a_usuario_nombre': pedido.asignadoAUsuarioNombre,
			'asignado_en': pedido.asignadoEn?.toIso8601String(),
			'creado_en': pedido.creadoEn.toIso8601String(),
			'creado_por_usuario_id': pedido.creadoPorUsuarioId,
			'venta_id': pedido.ventaId,
		};
	}
}
