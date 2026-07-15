/// Proveedor de mercancia para entradas de inventario.
library;

/// Entidad de proveedor para compras y recepciones.
class Proveedor {
	const Proveedor({
		required this.id,
		required this.nombre,
		required this.contacto,
		required this.telefono,
		required this.activo,
		this.email = '',
		this.rfc = '',
		this.direccion = '',
		this.notas = '',
		this.diasCredito = 0,
	});

	final String id;
	final String nombre;
	final String contacto;
	final String telefono;
	final bool activo;
	final String email;
	final String rfc;
	final String direccion;
	final String notas;
	final int diasCredito;

	/// Placeholder creado por integridad FK (sync fuera de orden).
	///
	/// No es un proveedor de negocio; no debe proyectarse a Neon.
	bool get esStubFk {
		if (notas.trim() == '__stub_fk__') {
			return true;
		}
		return nombre.trim() == 'Proveedor' &&
				contacto.trim().isEmpty &&
				telefono.trim().isEmpty &&
				email.trim().isEmpty &&
				rfc.trim().isEmpty;
	}

	Proveedor copiarWith({
		String? id,
		String? nombre,
		String? contacto,
		String? telefono,
		bool? activo,
		String? email,
		String? rfc,
		String? direccion,
		String? notas,
		int? diasCredito,
	}) {
		return Proveedor(
			id: id ?? this.id,
			nombre: nombre ?? this.nombre,
			contacto: contacto ?? this.contacto,
			telefono: telefono ?? this.telefono,
			activo: activo ?? this.activo,
			email: email ?? this.email,
			rfc: rfc ?? this.rfc,
			direccion: direccion ?? this.direccion,
			notas: notas ?? this.notas,
			diasCredito: diasCredito ?? this.diasCredito,
		);
	}

	Proveedor copiarCon({
		String? id,
		String? nombre,
		String? contacto,
		String? telefono,
		bool? activo,
		String? email,
		String? rfc,
		String? direccion,
		String? notas,
		int? diasCredito,
	}) => copiarWith(
		id: id,
		nombre: nombre,
		contacto: contacto,
		telefono: telefono,
		activo: activo,
		email: email,
		rfc: rfc,
		direccion: direccion,
		notas: notas,
		diasCredito: diasCredito,
	);
}
