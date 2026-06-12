/// Tipos de eventos intercambiados en sincronizacion.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Clasificacion de eventos del log de sincronizacion.
enum TipoSyncEvento {
	/// Venta completada en caja.
	saleCompleted,

	/// Producto creado o actualizado.
	productUpserted,

	/// Ajuste manual de inventario.
	stockAdjusted,

	/// Solicitud de transferencia entre tiendas.
	transferRequested,

	/// Transferencia recibida y confirmada.
	transferCompleted,

	/// Cliente creado o actualizado.
	customerUpserted,

	/// Venta anulada en caja.
	saleVoided,

	/// Categoria creada o actualizada.
	categoryUpserted,

	/// Presentacion de producto creada o actualizada.
	variantUpserted,

	/// Devolucion parcial de lineas de una venta.
	salePartialReturn,
}
