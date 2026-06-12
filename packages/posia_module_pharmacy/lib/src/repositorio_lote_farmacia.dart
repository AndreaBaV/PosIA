/// Contrato de acceso a lotes farmaceuticos persistidos.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 20:15:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'lote_farmacia.dart';

/// Provee operaciones de lectura y ajuste de lotes farmacia.
abstract class RepositorioLoteFarmacia {
	/// Lista lotes con existencia para un producto en tienda.
	///
	/// [productoId] Producto consultado.
	/// [tiendaId] Tienda consultada.
	/// Retorna lotes ordenados FEFO por caducidad.
	Future<List<LoteFarmacia>> listarDisponiblesPorProducto(
		String productoId,
		String tiendaId,
	);

	/// Obtiene lote por identificador.
	///
	/// [loteId] Identificador del lote.
	/// Retorna lote o null si no existe.
	Future<LoteFarmacia?> obtenerPorId(String loteId);

	/// Descuenta cantidad vendida del lote.
	///
	/// [loteId] Lote a ajustar.
	/// [cantidad] Unidades vendidas.
	Future<void> descontarCantidad(String loteId, double cantidad);

	/// Lista todos los lotes activos de una tienda.
	///
	/// [tiendaId] Tienda consultada.
	/// Retorna lotes ordenados por caducidad.
	Future<List<LoteFarmacia>> listarPorTienda(String tiendaId);

	/// Persiste o actualiza lote farmaceutico.
	///
	/// [lote] Lote a guardar.
	Future<void> guardar(LoteFarmacia lote);
}
