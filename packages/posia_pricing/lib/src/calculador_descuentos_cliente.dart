/// Calculo de descuentos automaticos por cliente en caja.
library;

import 'package:posia_core/posia_core.dart';

/// Resultado del calculo de descuentos sobre un carrito.
class ResultadoDescuentosCliente {
	const ResultadoDescuentosCliente({
		required this.descuentosPorLinea,
		required this.descuentoTicket,
	});

	final List<double> descuentosPorLinea;
	final double descuentoTicket;
}

/// Aplica reglas de descuento del cliente al carrito activo.
class CalculadorDescuentosCliente {
	const CalculadorDescuentosCliente._();

	static ResultadoDescuentosCliente calcular({
		required List<DescuentoCliente> descuentos,
		required List<LineaCarrito> lineas,
	}) {
		final porLinea = List<double>.filled(lineas.length, 0.0);
		if (lineas.isEmpty || descuentos.isEmpty) {
			return ResultadoDescuentosCliente(
				descuentosPorLinea: porLinea,
				descuentoTicket: 0.0,
			);
		}

		final subtotalBruto = _subtotalBruto(lineas);

		for (final descuento in descuentos) {
			if (!descuento.activo) {
				continue;
			}
			if (descuento.esPorProducto) {
				_aplicarDescuentoProducto(descuento, lineas, porLinea);
				continue;
			}
			if (!_cumpleCondicionGeneral(descuento, lineas, subtotalBruto)) {
				continue;
			}
		}

		var descuentoTicket = 0.0;
		for (final descuento in descuentos) {
			if (!descuento.activo || !descuento.esGeneral) {
				continue;
			}
			if (!_cumpleCondicionGeneral(descuento, lineas, subtotalBruto)) {
				continue;
			}
			final base = subtotalBruto - porLinea.fold(0.0, (s, v) => s + v);
			if (base <= 0) {
				continue;
			}
			if (descuento.tipo == TipoDescuentoCliente.porcentajeGeneral) {
				descuentoTicket = descuentoTicket + base * (descuento.valor / 100.0);
			} else {
				descuentoTicket = descuentoTicket + descuento.valor;
			}
		}

		final ticketRedondeado = redondearMonto(
			descuentoTicket.clamp(0.0, subtotalBruto),
		);
		final lineasRedondeadas = porLinea.map(redondearMonto).toList();
		return ResultadoDescuentosCliente(
			descuentosPorLinea: lineasRedondeadas,
			descuentoTicket: ticketRedondeado,
		);
	}

	static double _subtotalBruto(List<LineaCarrito> lineas) {
		var total = 0.0;
		for (final linea in lineas) {
			total = total + (linea.cantidad * linea.precioUnitario);
		}
		return total;
	}

	static void _aplicarDescuentoProducto(
		DescuentoCliente descuento,
		List<LineaCarrito> lineas,
		List<double> porLinea,
	) {
		final productoId = descuento.productoId;
		if (productoId == null) {
			return;
		}
		for (var i = 0; i < lineas.length; i++) {
			final linea = lineas[i];
			if (linea.producto.id != productoId) {
				continue;
			}
			if (!_cumpleCondicionProducto(descuento, linea)) {
				continue;
			}
			final bruto = linea.cantidad * linea.precioUnitario;
			final agregado = switch (descuento.tipo) {
				TipoDescuentoCliente.porcentajeProducto => bruto * (descuento.valor / 100.0),
				TipoDescuentoCliente.montoFijoProducto => descuento.valor,
				_ => 0.0,
			};
			porLinea[i] = (porLinea[i] + agregado).clamp(0.0, bruto);
		}
	}

	static bool _cumpleCondicionProducto(DescuentoCliente descuento, LineaCarrito linea) {
		switch (descuento.condicion) {
			case CondicionDescuentoCliente.siempre:
				return true;
			case CondicionDescuentoCliente.cantidadMinima:
				return linea.cantidad >= (descuento.umbral ?? 0.0);
			case CondicionDescuentoCliente.montoTicketMinimo:
				return true;
		}
	}

	static bool _cumpleCondicionGeneral(
		DescuentoCliente descuento,
		List<LineaCarrito> lineas,
		double subtotalBruto,
	) {
		switch (descuento.condicion) {
			case CondicionDescuentoCliente.siempre:
				return true;
			case CondicionDescuentoCliente.montoTicketMinimo:
				return subtotalBruto >= (descuento.umbral ?? 0.0);
			case CondicionDescuentoCliente.cantidadMinima:
				return lineas.any((l) => l.cantidad >= (descuento.umbral ?? 0.0));
		}
	}
}
