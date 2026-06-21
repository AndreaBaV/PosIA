/// Descuento o beneficio configurado para un cliente.
library;

import '../enums/condicion_descuento_cliente.dart';
import '../enums/tipo_descuento_cliente.dart';

/// Regla de descuento persistida para un cliente.
class DescuentoCliente {
	const DescuentoCliente({
		required this.id,
		required this.clienteId,
		required this.tipo,
		required this.valor,
		required this.condicion,
		required this.activo,
		this.productoId,
		this.umbral,
		this.descripcion = '',
	});

	final String id;
	final String clienteId;
	final TipoDescuentoCliente tipo;
	final double valor;
	final CondicionDescuentoCliente condicion;
	final bool activo;
	final String? productoId;
	final double? umbral;
	final String descripcion;

	bool get esGeneral =>
		tipo == TipoDescuentoCliente.porcentajeGeneral ||
		tipo == TipoDescuentoCliente.montoFijoGeneral;

	bool get esPorProducto =>
		tipo == TipoDescuentoCliente.porcentajeProducto ||
		tipo == TipoDescuentoCliente.montoFijoProducto;

	DescuentoCliente copiarCon({
		String? id,
		String? clienteId,
		TipoDescuentoCliente? tipo,
		double? valor,
		CondicionDescuentoCliente? condicion,
		bool? activo,
		String? productoId,
		double? umbral,
		String? descripcion,
		bool limpiarProductoId = false,
		bool limpiarUmbral = false,
	}) {
		return DescuentoCliente(
			id: id ?? this.id,
			clienteId: clienteId ?? this.clienteId,
			tipo: tipo ?? this.tipo,
			valor: valor ?? this.valor,
			condicion: condicion ?? this.condicion,
			activo: activo ?? this.activo,
			productoId: limpiarProductoId ? null : (productoId ?? this.productoId),
			umbral: limpiarUmbral ? null : (umbral ?? this.umbral),
			descripcion: descripcion ?? this.descripcion,
		);
	}
}
