/// Pedido recibido para surtir y entregar.
library;

import '../enums/estado_pedido.dart';
import '../enums/metodo_pago.dart';
import '../utils/moneda_util.dart';
import 'linea_pedido.dart';

/// Pedido con datos de entrega y asignacion a empleado.
class Pedido {
	const Pedido({
		required this.id,
		required this.tiendaId,
		required this.nombreEntrega,
		required this.telefonoEntrega,
		required this.direccionEntrega,
		required this.esCredito,
		required this.metodoPago,
		required this.total,
		required this.estado,
		required this.creadoEn,
		required this.lineas,
		this.clienteId,
		this.creditoDias,
		this.creditoVenceEn,
		this.notas = '',
		this.asignadoAUsuarioId,
		this.asignadoAUsuarioNombre,
		this.asignadoEn,
		this.creadoPorUsuarioId,
		this.ventaId,
	});

	final String id;
	final String tiendaId;
	final String? clienteId;
	final String nombreEntrega;
	final String telefonoEntrega;
	final String direccionEntrega;
	final bool esCredito;
	final int? creditoDias;
	final DateTime? creditoVenceEn;
	final MetodoPago metodoPago;
	final double total;
	final String notas;
	final EstadoPedido estado;
	final String? asignadoAUsuarioId;
	final String? asignadoAUsuarioNombre;
	final DateTime? asignadoEn;
	final DateTime creadoEn;
	final String? creadoPorUsuarioId;
	final String? ventaId;
	final List<LineaPedido> lineas;

	bool get pendienteAsignacion =>
		estado == EstadoPedido.recibido && asignadoAUsuarioId == null;

	bool get puedeAsignarse =>
		estado == EstadoPedido.recibido || estado == EstadoPedido.asignado;

	bool get puedeMarcarseEntregado =>
		estado == EstadoPedido.asignado && asignadoAUsuarioId != null;

	Pedido copiarCon({
		String? id,
		String? tiendaId,
		String? clienteId,
		String? nombreEntrega,
		String? telefonoEntrega,
		String? direccionEntrega,
		bool? esCredito,
		int? creditoDias,
		DateTime? creditoVenceEn,
		MetodoPago? metodoPago,
		double? total,
		String? notas,
		EstadoPedido? estado,
		String? asignadoAUsuarioId,
		String? asignadoAUsuarioNombre,
		DateTime? asignadoEn,
		DateTime? creadoEn,
		String? creadoPorUsuarioId,
		String? ventaId,
		List<LineaPedido>? lineas,
	}) {
		return Pedido(
			id: id ?? this.id,
			tiendaId: tiendaId ?? this.tiendaId,
			clienteId: clienteId ?? this.clienteId,
			nombreEntrega: nombreEntrega ?? this.nombreEntrega,
			telefonoEntrega: telefonoEntrega ?? this.telefonoEntrega,
			direccionEntrega: direccionEntrega ?? this.direccionEntrega,
			esCredito: esCredito ?? this.esCredito,
			creditoDias: creditoDias ?? this.creditoDias,
			creditoVenceEn: creditoVenceEn ?? this.creditoVenceEn,
			metodoPago: metodoPago ?? this.metodoPago,
			total: total ?? this.total,
			notas: notas ?? this.notas,
			estado: estado ?? this.estado,
			asignadoAUsuarioId: asignadoAUsuarioId ?? this.asignadoAUsuarioId,
			asignadoAUsuarioNombre:
				asignadoAUsuarioNombre ?? this.asignadoAUsuarioNombre,
			asignadoEn: asignadoEn ?? this.asignadoEn,
			creadoEn: creadoEn ?? this.creadoEn,
			creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
			ventaId: ventaId ?? this.ventaId,
			lineas: lineas ?? this.lineas,
		);
	}

	static double calcularTotalDesdeLineas(List<LineaPedido> lineas) {
		var acumulado = 0.0;
		for (final linea in lineas) {
			acumulado = acumulado + linea.subtotal;
		}
		return redondearMonto(acumulado);
	}
}
