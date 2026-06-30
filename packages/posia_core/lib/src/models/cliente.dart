/// Modelo inmutable de cliente comercial.
library;

import '../constants/posia_constants.dart';

/// Representa un cliente con posible lista de precios preferencial.
class Cliente {
	static const Object _sinCambio = Object();

	const Cliente({
		required this.id,
		required this.nombre,
		required this.listaPreciosId,
		required this.creditoHabilitado,
		required this.activo,
		this.telefono = '',
		this.email = '',
		this.rfc = '',
		this.direccion = '',
		this.notas = '',
		this.diasCredito = DIAS_CREDITO_PREDETERMINADO,
	});

	final String id;
	final String nombre;
	final String? listaPreciosId;
	final bool creditoHabilitado;
	final bool activo;
	final String telefono;
	final String email;
	final String rfc;
	final String direccion;
	final String notas;
	final int diasCredito;

	Cliente copiarCon({
		String? id,
		String? nombre,
		Object? listaPreciosId = _sinCambio,
		bool? creditoHabilitado,
		bool? activo,
		String? telefono,
		String? email,
		String? rfc,
		String? direccion,
		String? notas,
		int? diasCredito,
	}) {
		return Cliente(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			listaPreciosId: identical(listaPreciosId, _sinCambio)
				? this.listaPreciosId
				: listaPreciosId as String?,
			creditoHabilitado: creditoHabilitado ?? this.creditoHabilitado,
			activo: activo ?? this.activo,
			telefono: telefono ?? this.telefono,
			email: email ?? this.email,
			rfc: rfc ?? this.rfc,
			direccion: direccion ?? this.direccion,
			notas: notas ?? this.notas,
			diasCredito: diasCredito ?? this.diasCredito,
		);
	}
}
