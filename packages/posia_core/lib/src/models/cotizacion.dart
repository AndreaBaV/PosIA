/// Cotizacion persistida generada desde caja.
library;

import '../constants/posia_constants.dart';
import '../utils/moneda_util.dart';
import 'linea_cotizacion.dart';

/// Documento de cotizacion con lineas y vigencia.
class Cotizacion {
	const Cotizacion({
		required this.id,
		required this.tiendaId,
		required this.total,
		required this.creadaEn,
		required this.lineas,
		this.clienteId,
		this.nombreCliente,
		this.notas = '',
		this.vigenciaDias = VIGENCIA_COTIZACION_DIAS,
		this.cajaId,
		this.vendedorId,
	});

	final String id;
	final String tiendaId;
	final String? clienteId;
	final String? nombreCliente;
	final double total;
	final String notas;
	final int vigenciaDias;
	final DateTime creadaEn;
	final String? cajaId;
	final String? vendedorId;
	final List<LineaCotizacion> lineas;

	static double calcularTotalDesdeLineas(List<LineaCotizacion> lineas) {
		var acumulado = 0.0;
		for (final linea in lineas) {
			acumulado = acumulado + linea.subtotal;
		}
		return redondearMonto(acumulado);
	}
}
