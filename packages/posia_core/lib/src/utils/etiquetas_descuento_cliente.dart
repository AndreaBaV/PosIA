/// Etiquetas legibles para descuentos de cliente.
library;

import '../enums/condicion_descuento_cliente.dart';
import '../enums/tipo_descuento_cliente.dart';
import '../models/descuento_cliente.dart';
import 'moneda_util.dart';

/// Texto del tipo de descuento.
String etiquetaTipoDescuentoCliente(TipoDescuentoCliente tipo) {
	switch (tipo) {
		case TipoDescuentoCliente.porcentajeGeneral:
			return 'Porcentaje general';
		case TipoDescuentoCliente.montoFijoGeneral:
			return 'Monto fijo general';
		case TipoDescuentoCliente.porcentajeProducto:
			return 'Porcentaje en producto';
		case TipoDescuentoCliente.montoFijoProducto:
			return 'Monto fijo en producto';
	}
}

/// Texto de la condicion del descuento.
String etiquetaCondicionDescuentoCliente(CondicionDescuentoCliente condicion) {
	switch (condicion) {
		case CondicionDescuentoCliente.siempre:
			return 'Siempre';
		case CondicionDescuentoCliente.cantidadMinima:
			return 'Cantidad minima';
		case CondicionDescuentoCliente.montoTicketMinimo:
			return 'Monto minimo de ticket';
	}
}

/// Resumen corto del descuento para listas.
String resumenDescuentoCliente(DescuentoCliente descuento, {String? nombreProducto}) {
	final valorTexto = switch (descuento.tipo) {
		TipoDescuentoCliente.porcentajeGeneral ||
		TipoDescuentoCliente.porcentajeProducto => '${descuento.valor.toStringAsFixed(0)}%',
		TipoDescuentoCliente.montoFijoGeneral ||
		TipoDescuentoCliente.montoFijoProducto => formatearMoneda(descuento.valor),
	};
	final partes = <String>[etiquetaTipoDescuentoCliente(descuento.tipo), valorTexto];
	if (descuento.esPorProducto && nombreProducto != null) {
		partes.add(nombreProducto);
	}
	if (descuento.condicion != CondicionDescuentoCliente.siempre && descuento.umbral != null) {
		final umbral = descuento.condicion == CondicionDescuentoCliente.montoTicketMinimo
			? formatearMoneda(descuento.umbral!)
			: descuento.umbral!.toStringAsFixed(0);
		partes.add('si >= $umbral');
	}
	return partes.join(' · ');
}
