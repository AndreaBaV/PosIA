/// Metodos de pago aceptados en caja.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Representa la forma de cobro de una venta.
enum MetodoPago {
	/// Pago en efectivo.
	efectivo,

	/// Pago con tarjeta de debito o credito.
	tarjeta,

	/// Pago mixto efectivo mas tarjeta.
	mixto,

	/// Venta registrada a credito o fiado.
	credito,

	/// Pago por transferencia bancaria.
	transferencia,
}
