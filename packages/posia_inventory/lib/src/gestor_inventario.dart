/// Logica de ajuste de inventario por ventas y movimientos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

import 'repositorio_inventario.dart';

/// Coordina descuentos de stock originados por ventas.
class GestorInventario {
	/// Crea gestor con repositorio de inventario.
	///
	/// [repositorioInventario] Persistencia de stock.
	GestorInventario({required RepositorioInventario repositorioInventario})
		: _repositorioInventario = repositorioInventario;

	final RepositorioInventario _repositorioInventario;

	/// Descuenta inventario segun lineas de una venta cerrada.
	///
	/// [venta] Venta completada con detalle de productos.
	Future<void> aplicarVenta(Venta venta) async {
		final ahora = DateTime.now().toUtc();
		for (final linea in venta.lineas) {
			await _descontarProducto(
				linea.productoId,
				venta.tiendaId,
				linea.cantidad,
				ahora,
			);
		}
	}

	/// Ajusta stock manualmente con delta positivo o negativo.
	///
	/// [productoId] Producto ajustado.
	/// [tiendaId] Tienda del ajuste.
	/// [delta] Variacion de cantidad; negativo reduce stock.
	Future<void> ajustarStock(
		String productoId,
		String tiendaId,
		double delta,
	) async {
		final ahora = DateTime.now().toUtc();
		final stockActual = await _repositorioInventario.obtenerStock(
			productoId,
			tiendaId,
		);
		final cantidadBase = stockActual?.cantidad ?? 0.0;
		final cantidadNueva = cantidadBase + delta;
		final stockActualizado = StockNivel(
			productoId: productoId,
			tiendaId: tiendaId,
			cantidad: cantidadNueva,
			actualizadoEn: ahora,
		);
		await _repositorioInventario.guardarStock(stockActualizado);
	}

	/// Obtiene cantidad disponible en tienda.
	///
	/// [productoId] Producto consultado.
	/// [tiendaId] Tienda consultada.
	/// Retorna cantidad disponible o cero si no hay registro.
	Future<double> obtenerCantidadDisponible(
		String productoId,
		String tiendaId,
	) async {
		final stock = await _repositorioInventario.obtenerStock(productoId, tiendaId);
		if (stock == null) {
			return 0.0;
		}
		return stock.cantidad;
	}

	/// Descuenta cantidad vendida del stock local.
	///
	/// [productoId] Producto vendido.
	/// [tiendaId] Tienda origen.
	/// [cantidad] Cantidad a descontar.
	/// [actualizadoEn] Marca de tiempo del movimiento.
	Future<void> _descontarProducto(
		String productoId,
		String tiendaId,
		double cantidad,
		DateTime actualizadoEn,
	) async {
		await ajustarStock(productoId, tiendaId, -cantidad);
	}
}
