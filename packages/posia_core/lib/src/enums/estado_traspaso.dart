/// Estado de traspaso entre sucursales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Flujo de solicitud y recepcion de mercancia entre tiendas.
enum EstadoTraspaso {
	/// Solicitud creada; pendiente de envio.
	solicitado,

	/// Mercancia en transito.
	enTransito,

	/// Recibido en tienda destino.
	completado,

	/// Solicitud cancelada.
	cancelado,
}
