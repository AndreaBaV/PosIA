/// Nivel de alerta por proximidad de caducidad.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

/// Clasificacion visual de riesgo de caducidad.
enum NivelAlertaCaducidad {
	/// Lote vigente sin alerta.
	normal,

	/// Caduca dentro del umbral amarillo.
	advertencia,

	/// Caduca dentro del umbral rojo o vencido.
	critico,
}
