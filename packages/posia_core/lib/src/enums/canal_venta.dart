/// Canales de venta soportados por el motor de precios.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Define el contexto comercial de una cotizacion.
enum CanalVenta {
	/// Venta al publico en mostrador.
	mostrador,

	/// Venta al mayoreo por escala de cantidad.
	mayoreo,

	/// Venta con lista de precios especial del cliente.
	preferencial,
}
