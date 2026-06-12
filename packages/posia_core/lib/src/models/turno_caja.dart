/// Turno de corte de caja (apertura y cierre).
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import '../enums/estado_turno_caja.dart';

/// Registro de apertura y cierre de caja registradora.
class TurnoCaja {
	/// Crea turno de caja.
	const TurnoCaja({
		required this.id,
		required this.tiendaId,
		required this.cajaId,
		required this.vendedorId,
		required this.fondoInicial,
		required this.totalEfectivo,
		required this.totalTarjeta,
		required this.totalTransferencia,
		required this.totalVentas,
		required this.cantidadVentas,
		required this.abiertoEn,
		required this.cerradoEn,
		required this.estado,
	});

	/// Identificador unico del turno.
	final String id;

	/// Tienda del turno.
	final String tiendaId;

	/// Caja registradora.
	final String cajaId;

	/// Vendedor que abrio el turno.
	final String? vendedorId;

	/// Fondo inicial en efectivo.
	final double fondoInicial;

	/// Total cobrado en efectivo.
	final double totalEfectivo;

	/// Total cobrado con tarjeta.
	final double totalTarjeta;

	/// Total cobrado por transferencia.
	final double totalTransferencia;

	/// Suma de ventas del turno.
	final double totalVentas;

	/// Cantidad de tickets del turno.
	final int cantidadVentas;

	/// Marca de apertura UTC.
	final DateTime abiertoEn;

	/// Marca de cierre UTC; null si abierto.
	final DateTime? cerradoEn;

	/// Estado del turno.
	final EstadoTurnoCaja estado;

	/// Total esperado en caja (fondo + efectivo vendido).
	double calcularEfectivoEsperado() {
		return fondoInicial + totalEfectivo;
	}
}
