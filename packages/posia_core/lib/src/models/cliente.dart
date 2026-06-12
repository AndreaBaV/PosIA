/// Modelo inmutable de cliente comercial.
library;

/// Representa un cliente con posible lista de precios preferencial.
class Cliente {
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

	Cliente copiarCon({
		String? id,
		String? nombre,
		String? listaPreciosId,
		bool? creditoHabilitado,
		bool? activo,
		String? telefono,
		String? email,
		String? rfc,
		String? direccion,
		String? notas,
	}) {
		return Cliente(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			listaPreciosId: listaPreciosId ?? this.listaPreciosId,
			creditoHabilitado: creditoHabilitado ?? this.creditoHabilitado,
			activo: activo ?? this.activo,
			telefono: telefono ?? this.telefono,
			email: email ?? this.email,
			rfc: rfc ?? this.rfc,
			direccion: direccion ?? this.direccion,
			notas: notas ?? this.notas,
		);
	}
}
