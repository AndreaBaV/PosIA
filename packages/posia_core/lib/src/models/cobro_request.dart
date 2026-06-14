/// Parametros de cobro en caja (multipago y descuentos).
library;

import '../enums/metodo_pago.dart';

/// Solicitud de cierre de venta con forma de pago detallada.
class CobroRequest {
	const CobroRequest({
		required this.metodoPago,
		this.descuentoTicket = 0.0,
		this.montoEfectivo,
		this.montoTarjeta,
		this.montoTransferencia,
		this.montoRecibido,
	});

	final MetodoPago metodoPago;
	final double descuentoTicket;
	final double? montoEfectivo;
	final double? montoTarjeta;
	final double? montoTransferencia;

	/// Efectivo entregado por cliente (solo informativo para cambio).
	final double? montoRecibido;
}
