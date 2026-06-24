/// Perfil de empleado y nomina.
library;

/// Tarifa y tipo de pago del empleado.
class EmpleadoPerfil {
	const EmpleadoPerfil({
		required this.usuarioId,
		required this.tarifaHora,
		required this.tipoPago,
		required this.actualizadoEn,
	});

	final String usuarioId;
	final double tarifaHora;
	final String tipoPago;
	final DateTime actualizadoEn;
}

/// Periodo de calculo de nomina.
class PeriodoNomina {
	const PeriodoNomina({
		required this.id,
		this.tiendaId,
		required this.inicioEn,
		required this.finEn,
		required this.estado,
		this.cerradoEn,
		this.cerradoPor,
	});

	final String id;
	final String? tiendaId;
	final DateTime inicioEn;
	final DateTime finEn;
	final String estado;
	final DateTime? cerradoEn;
	final String? cerradoPor;

	bool get cerrado => estado == 'cerrado';
}

/// Linea de nomina por empleado.
class LineaNomina {
	const LineaNomina({
		required this.id,
		required this.periodoId,
		required this.usuarioId,
		required this.horasTrabajadas,
		required this.tarifaHora,
		required this.montoBruto,
		required this.montoNeto,
	});

	final String id;
	final String periodoId;
	final String usuarioId;
	final double horasTrabajadas;
	final double tarifaHora;
	final double montoBruto;
	final double montoNeto;
}
