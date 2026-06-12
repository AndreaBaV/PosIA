/// Contrato de impresora de tickets.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Imprime ticket de venta en impresora termica o PDF.
abstract class ReceiptPrinter {
	/// Imprime contenido de ticket en texto plano ESC/POS o PDF.
	///
	/// [contenido] Texto del ticket a imprimir.
	Future<void> imprimirTicket(String contenido);
}
