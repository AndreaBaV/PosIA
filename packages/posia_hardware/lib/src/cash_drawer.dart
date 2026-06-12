/// Contrato de cajon de dinero.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Envia pulso de apertura al cajon de efectivo.
abstract class CashDrawer {
	/// Abre cajon conectado a impresora o relay.
	Future<void> abrir();
}
