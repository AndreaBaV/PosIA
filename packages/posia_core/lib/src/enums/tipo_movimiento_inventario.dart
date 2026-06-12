/// Tipo de movimiento en ledger de inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

/// Clasificacion de entradas, salidas y ajustes de stock.
enum TipoMovimientoInventario {
	/// Entrada por compra o recepcion.
	entrada,

	/// Salida por venta, merma o uso interno.
	salida,

	/// Correccion manual de existencias.
	ajuste,

	/// Traspaso enviado a otra sucursal.
	traspasoSalida,

	/// Traspaso recibido de otra sucursal.
	traspasoEntrada,

	/// Reversion por cancelacion de venta.
	reversionVenta,
}
