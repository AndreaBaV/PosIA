/// Contrato de display orientado al cliente.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Muestra total de venta en pantalla secundaria del cliente.
abstract class CustomerDisplay {
	/// Actualiza monto visible para el cliente.
	///
	/// [total] Monto total en MXN a mostrar.
	Future<void> mostrarTotal(double total);
}
