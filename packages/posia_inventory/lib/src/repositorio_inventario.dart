/// Contrato de persistencia de inventario.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Acceso a niveles de stock por tienda.
abstract class RepositorioInventario {
	/// Obtiene stock de un producto en tienda.
	///
	/// [productoId] Producto consultado.
	/// [tiendaId] Tienda consultada.
	/// Retorna nivel de stock o null si no existe registro.
	Future<StockNivel?> obtenerStock(String productoId, String tiendaId);

	/// Persiste nivel de stock actualizado.
	///
	/// [stock] Registro de inventario a guardar.
	Future<void> guardarStock(StockNivel stock);

	/// Lista stock de una tienda completa.
	///
	/// [tiendaId] Tienda origen.
	/// Retorna coleccion de niveles de stock.
	Future<List<StockNivel>> listarStockPorTienda(String tiendaId);
}
