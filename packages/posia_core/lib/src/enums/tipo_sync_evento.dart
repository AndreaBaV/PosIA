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

	/// Tienda o sucursal creada o actualizada.
	storeUpserted,

	/// Almacen creado o actualizado.
	warehouseUpserted,

	/// Tipo de presentacion creado o actualizado (activo).
	presentationTypeUpserted,

	/// Legacy: presentacion individual. Usar [productPresentationsReplaced].
	/// Se acepta en el log historico pero no se emite ni se aplica.
	productPresentationUpserted,

	/// Desafio PIN de asistencia creado.
	attendanceChallengeCreated,

	/// Entrada de empleado registrada.
	attendanceCheckedIn,

	/// Salida de empleado registrada.
	attendanceCheckedOut,

	/// Perfil de empleado (tarifa) actualizado.
	employeeProfileUpserted,

	/// Periodo de nomina cerrado.
	payrollPeriodClosed,

	/// Cuenta de usuario creada o actualizada (PIN solo como hash).
	userUpserted,

	/// Turno de caja abierto, actualizado o cerrado.
	cashShiftUpserted,

	/// Cotizacion creada o actualizada.
	quoteUpserted,

	/// Cotizacion eliminada.
	quoteDeleted,

	/// Pedido creado o actualizado.
	orderUpserted,

	/// Escalas de mayoreo reemplazadas para un producto.
	wholesaleTiersReplaced,

	/// Lote de promocion mayoreo creado o reemplazado (miembros incluidos).
	lotePromocionReplaced,

	/// Presentaciones de empaque reemplazadas para un producto.
	productPresentationsReplaced,

	/// Rol personalizado creado o actualizado.
	customRoleUpserted,

	/// Lista de precios creada o actualizada.
	priceListUpserted,

	/// Lista de precios eliminada.
	priceListDeleted,

	/// Precio de producto en lista comercial creado o actualizado.
	priceListItemUpserted,

	/// Precio de producto eliminado de una lista comercial.
	priceListItemDeleted,

	/// Precio preferencial cliente-producto creado o actualizado.
	customerProductPriceUpserted,

	/// Precio preferencial cliente-producto eliminado.
	customerProductPriceDeleted,

	/// Proveedor creado o actualizado.
	supplierUpserted,

	/// Proveedor eliminado.
	supplierDeleted,

	/// Producto eliminado por un administrador (lapida).
	///
	/// El borrado manual es absoluto: gana sobre cualquier `productUpserted`
	/// posterior, sin importar el orden de llegada, y evita que un evento hijo
	/// atrasado resucite el producto como stub FK.
	productDeleted,

	/// Categoria eliminada por un administrador (lapida).
	categoryDeleted,

	/// Compra a proveedor registrada (incluye lineas y efecto en stock).
	purchaseCompleted,

	/// Descuento comercial de cliente creado o actualizado.
	customerDiscountUpserted,

	/// Descuento comercial de cliente eliminado.
	customerDiscountDeleted,

	/// Combo de precio fijo creado o reemplazado (miembros incluidos).
	comboReplaced,
}
