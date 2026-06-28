/// Contrato de acceso a lotes farmaceuticos persistidos.
library;

import '../models/lote_farmacia.dart';

/// Operaciones de lectura y ajuste de lotes farmacia.
abstract class RepositorioLoteFarmacia {
	Future<List<LoteFarmacia>> listarDisponiblesPorProducto(
		String productoId,
		String tiendaId,
	);

	Future<LoteFarmacia?> obtenerPorId(String loteId);

	Future<void> descontarCantidad(String loteId, double cantidad);

	Future<List<LoteFarmacia>> listarPorTienda(String tiendaId);

	Future<void> guardar(LoteFarmacia lote);
}
