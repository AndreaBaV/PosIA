/// Contrato de lector de codigos de barras.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Provee stream de codigos escaneados desde hardware o teclado.
abstract class BarcodeScanner {
	/// Flujo continuo de codigos capturados.
	Stream<String> get codigos;

	/// Inicia escucha del dispositivo scanner.
	Future<void> iniciar();

	/// Detiene escucha del dispositivo scanner.
	Future<void> detener();
}
