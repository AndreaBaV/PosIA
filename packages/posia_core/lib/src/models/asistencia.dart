/// Registro de asistencia y desafio PIN.
library;

/// Desafio PIN temporal generado en laptop admin.
class DesafioAsistencia {
	const DesafioAsistencia({
		required this.id,
		required this.tiendaId,
		required this.pinHash,
		required this.expiraEn,
		required this.creadoPor,
		this.latitud,
		this.longitud,
		this.radioMetros = 150,
		required this.activo,
	});

	final String id;
	final String tiendaId;
	final String pinHash;
	final DateTime expiraEn;
	final String creadoPor;
	final double? latitud;
	final double? longitud;
	final double radioMetros;
	final bool activo;
}

/// Entrada o salida de empleado.
class RegistroAsistencia {
	const RegistroAsistencia({
		required this.id,
		required this.usuarioId,
		required this.tiendaId,
		required this.entradaEn,
		this.salidaEn,
		required this.metodo,
		this.latitud,
		this.longitud,
		this.desafioId,
	});

	final String id;
	final String usuarioId;
	final String tiendaId;
	final DateTime entradaEn;
	final DateTime? salidaEn;
	final String metodo;
	final double? latitud;
	final double? longitud;
	final String? desafioId;

	bool get abierto => salidaEn == null;
}
