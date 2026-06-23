/// Venta cerrada persistida en base local.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import '../enums/estado_venta.dart';
import '../enums/metodo_pago.dart';
import '../utils/moneda_util.dart';
import 'linea_venta.dart';

/// Representa una transaccion de venta completada.
class Venta {
	/// Crea una venta persistida.
	///
	/// [id] Identificador unico de la venta.
	/// [tiendaId] Tienda donde se realizo la venta.
	/// [cajaId] Identificador de la caja registradora.
	/// [clienteId] Cliente opcional asociado.
	/// [lineas] Detalle de productos vendidos.
	/// [metodoPago] Forma de pago utilizada.
	/// [total] Total de la venta en MXN.
	/// [creadaEn] Marca de tiempo UTC de creacion.
	/// [vendedorId] Vendedor que registro la venta.
	/// [estado] Estado de la transaccion.
	/// [turnoCajaId] Turno de corte de caja asociado.
	const Venta({
		required this.id,
		required this.tiendaId,
		required this.cajaId,
		required this.clienteId,
		required this.lineas,
		required this.metodoPago,
		required this.total,
		required this.creadaEn,
		this.vendedorId,
		this.estado = EstadoVenta.completada,
		this.turnoCajaId,
		this.descuentoTicket = 0.0,
		this.montoEfectivo,
		this.montoTarjeta,
		this.montoTransferencia,
		this.creditoDias,
		this.creditoVenceEn,
		this.creditoLiquidado = false,
		this.creditoLiquidadoEn,
	});

	/// Identificador unico de venta.
	final String id;

	/// Tienda origen de la venta.
	final String tiendaId;

	/// Caja que registro la venta.
	final String cajaId;

	/// Cliente asociado opcional.
	final String? clienteId;

	/// Lineas de detalle vendidas.
	final List<LineaVenta> lineas;

	/// Metodo de pago aplicado.
	final MetodoPago metodoPago;

	/// Total de la venta redondeado.
	final double total;

	/// Fecha y hora de creacion en UTC.
	final DateTime creadaEn;

	/// Vendedor que registro la venta.
	final String? vendedorId;

	/// Estado actual de la transaccion.
	final EstadoVenta estado;

	/// Turno de caja donde se cobro.
	final String? turnoCajaId;

	/// Descuento global aplicado al ticket (MXN).
	final double descuentoTicket;

	/// Monto cobrado en efectivo (mixto o desglose).
	final double? montoEfectivo;

	/// Monto cobrado con tarjeta.
	final double? montoTarjeta;

	/// Monto cobrado por transferencia.
	final double? montoTransferencia;

	/// Plazo acordado en dias (solo ventas a credito).
	final int? creditoDias;

	/// Fecha limite de pago acordada (solo ventas a credito).
	final DateTime? creditoVenceEn;

	/// Indica si el credito ya fue liquidado en una sola exhibicion.
	final bool creditoLiquidado;

	/// Fecha en que se liquido el credito.
	final DateTime? creditoLiquidadoEn;

	/// Indica si la venta puede anularse.
	bool puedeAnularse() {
		return estado == EstadoVenta.completada;
	}

	/// Indica si admite devolucion parcial de lineas.
	bool puedeDevolverseParcial() {
		return estado == EstadoVenta.completada && lineas.isNotEmpty;
	}

	/// Genera copia con campos opcionales reemplazados.
	Venta copiarCon({
		String? id,
		String? tiendaId,
		String? cajaId,
		String? clienteId,
		List<LineaVenta>? lineas,
		MetodoPago? metodoPago,
		double? total,
		DateTime? creadaEn,
		String? vendedorId,
		EstadoVenta? estado,
		String? turnoCajaId,
		double? descuentoTicket,
		double? montoEfectivo,
		double? montoTarjeta,
		double? montoTransferencia,
		int? creditoDias,
		DateTime? creditoVenceEn,
		bool? creditoLiquidado,
		DateTime? creditoLiquidadoEn,
	}) {
		return Venta(
			id: id ?? this.id,
			tiendaId: tiendaId ?? this.tiendaId,
			cajaId: cajaId ?? this.cajaId,
			clienteId: clienteId ?? this.clienteId,
			lineas: lineas ?? this.lineas,
			metodoPago: metodoPago ?? this.metodoPago,
			total: total ?? this.total,
			creadaEn: creadaEn ?? this.creadaEn,
			vendedorId: vendedorId ?? this.vendedorId,
			estado: estado ?? this.estado,
			turnoCajaId: turnoCajaId ?? this.turnoCajaId,
			descuentoTicket: descuentoTicket ?? this.descuentoTicket,
			montoEfectivo: montoEfectivo ?? this.montoEfectivo,
			montoTarjeta: montoTarjeta ?? this.montoTarjeta,
			montoTransferencia: montoTransferencia ?? this.montoTransferencia,
			creditoDias: creditoDias ?? this.creditoDias,
			creditoVenceEn: creditoVenceEn ?? this.creditoVenceEn,
			creditoLiquidado: creditoLiquidado ?? this.creditoLiquidado,
			creditoLiquidadoEn: creditoLiquidadoEn ?? this.creditoLiquidadoEn,
		);
	}

	/// Calcula total a partir de lineas si no fue provisto externamente.
	///
	/// [lineas] Coleccion de lineas de venta.
	/// [descuentoTicket] Descuento global opcional.
	/// Retorna suma redondeada de subtotales menos descuento ticket.
	static double calcularTotalDesdeLineas(
		List<LineaVenta> lineas, {
		double descuentoTicket = 0.0,
	}) {
		var acumulado = 0.0;
		for (final linea in lineas) {
			acumulado = acumulado + linea.calcularSubtotal();
		}
		final neto = acumulado - descuentoTicket;
		return redondearMonto(neto < 0.0 ? 0.0 : neto);
	}
}
