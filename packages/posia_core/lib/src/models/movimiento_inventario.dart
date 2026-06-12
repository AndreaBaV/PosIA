/// Movimiento auditado de inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 22:00:00 (UTC-6)
library;

import '../enums/tipo_movimiento_inventario.dart';

/// Registro de entrada, salida o ajuste de stock.
class MovimientoInventario {
	/// Crea movimiento de inventario.
	const MovimientoInventario({
		required this.id,
		required this.productoId,
		required this.tiendaId,
		required this.tipo,
		required this.cantidad,
		required this.cantidadAnterior,
		required this.cantidadNueva,
		required this.motivo,
		required this.referenciaId,
		required this.proveedorId,
		required this.creadoEn,
		required this.creadoPor,
	});

	/// Identificador unico.
	final String id;

	/// Producto afectado.
	final String productoId;

	/// Tienda del movimiento.
	final String tiendaId;

	/// Tipo de movimiento.
	final TipoMovimientoInventario tipo;

	/// Cantidad del movimiento (positiva).
	final double cantidad;

	/// Existencia antes del movimiento.
	final double cantidadAnterior;

	/// Existencia despues del movimiento.
	final double cantidadNueva;

	/// Descripcion o motivo.
	final String motivo;

	/// Referencia externa (venta, traspaso, etc.).
	final String? referenciaId;

	/// Proveedor asociado en entradas de compra.
	final String? proveedorId;

	/// Marca de tiempo UTC.
	final DateTime creadoEn;

	/// Usuario o vendedor que registro el movimiento.
	final String? creadoPor;
}
