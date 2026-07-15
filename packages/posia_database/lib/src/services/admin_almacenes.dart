/// Dominio de almacenes: catálogo, inventario y ajustes de stock.
///
/// Extraído de `ServicioAdmin`. Los traspasos con origen en almacén
/// (`traspasarAlmacenA*`) se quedaron en `ServicioAdmin` porque dependen de
/// `TraspasoRepository` y del emisor de eventos de traspaso — cruzan hacia
/// el dominio de Traspasos, que aún no se ha extraído.
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../models/stock_por_almacen.dart';
import '../repositories/almacen_repository.dart';
import '../repositories/producto_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Catálogo de almacenes e inventario por almacén.
class AdminAlmacenes {
	AdminAlmacenes({
		required ProductoRepository productoRepository,
		required AdminEmisorEventosSync emisorEventos,
		AlmacenRepository? almacenRepository,
	}) : _productoRepository = productoRepository,
	     _emisorEventos = emisorEventos,
	     _almacenRepository = almacenRepository;

	final ProductoRepository _productoRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final AlmacenRepository? _almacenRepository;
	final Uuid _generadorId = const Uuid();

	Future<List<Almacen>> listarAlmacenes() async {
		final repo = _almacenRepository;
		if (repo == null) {
			return [];
		}
		final lista = await repo.listarTodos();
		if (lista.isEmpty) {
			await _sembrarAlmacenesIniciales();
			return repo.listarTodos();
		}
		return lista;
	}

	Future<void> _sembrarAlmacenesIniciales() async {
		final repo = _almacenRepository;
		if (repo == null) {
			return;
		}
		final nombres = ['Almacén Central', 'Almacén Norte', 'Almacén Sur'];
		for (var i = 0; i < nombres.length; i++) {
			await repo.guardar(
				Almacen(id: 'alm-${i + 1}', nombre: nombres[i], activo: true),
			);
		}
	}

	Future<Almacen> registrarAlmacen(String nombre, {String? tiendaId}) async {
		final repo = _almacenRepository;
		if (repo == null) {
			throw StateError('Almacenes no disponibles');
		}
		final almacen = Almacen(
			id: _generadorId.v4(),
			nombre: nombre.trim(),
			tiendaId: tiendaId,
			activo: true,
		);
		await repo.guardar(almacen);
		await _emisorEventos.almacen(almacen);
		return almacen;
	}

	/// Resumen de existencias por almacén activo.
	Future<List<ResumenStockAlmacen>> obtenerResumenAlmacenes() async {
		final almacenRepo = _almacenRepository;
		if (almacenRepo == null) {
			return [];
		}
		final almacenes = await almacenRepo.listarActivos();
		final resumenes = <ResumenStockAlmacen>[];
		for (final almacen in almacenes) {
			final stocks = await almacenRepo.listarStockPorAlmacen(almacen.id);
			var productos = 0;
			var unidades = 0.0;
			for (final stock in stocks) {
				if (stock.cantidad <= 0) {
					continue;
				}
				productos++;
				unidades += stock.cantidad;
			}
			resumenes.add(
				ResumenStockAlmacen(
					almacenId: almacen.id,
					nombreAlmacen: almacen.nombre,
					productosConStock: productos,
					totalUnidades: redondearMonto(unidades),
				),
			);
		}
		return resumenes;
	}

	/// Inventario detallado de un almacén (productos con cantidad).
	Future<List<StockPorAlmacen>> obtenerInventarioAlmacen(
		String almacenId,
	) async {
		final almacenRepo = _almacenRepository;
		if (almacenRepo == null) {
			return [];
		}
		final almacen = await almacenRepo.obtenerPorId(almacenId);
		if (almacen == null) {
			throw StateError('Almacén no encontrado');
		}
		final stocks = await almacenRepo.listarStockPorAlmacen(almacenId);
		final resultado = <StockPorAlmacen>[];
		for (final stock in stocks) {
			if (stock.cantidad <= 0) {
				continue;
			}
			final producto = await _productoRepository.obtenerPorId(stock.productoId);
			if (producto == null || !producto.activo) {
				continue;
			}
			resultado.add(
				StockPorAlmacen(
					productoId: stock.productoId,
					nombreProducto: producto.nombre,
					almacenId: almacenId,
					nombreAlmacen: almacen.nombre,
					cantidad: stock.cantidad,
					actualizadoEn: stock.actualizadoEn,
					stockMinimo: stock.stockMinimo,
				),
			);
		}
		resultado.sort((a, b) => a.nombreProducto.compareTo(b.nombreProducto));
		return resultado;
	}

	/// Ajusta existencias en almacén (entrada, salida o ajuste a cantidad fija).
	Future<void> ajustarStockAlmacen({
		required String productoId,
		required String almacenId,
		required TipoMovimientoInventario tipo,
		required double cantidad,
	}) async {
		final almacenRepo = _almacenRepository;
		if (almacenRepo == null) {
			throw StateError('Almacenes no disponibles');
		}
		final almacen = await almacenRepo.obtenerPorId(almacenId);
		if (almacen == null) {
			throw StateError('Almacén no encontrado');
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			throw StateError('Producto no encontrado');
		}
		if (cantidad < 0) {
			throw StateError('La cantidad no puede ser negativa');
		}
		final stockActual = await almacenRepo.obtenerStock(productoId, almacenId);
		final anterior = stockActual?.cantidad ?? 0.0;
		late double nuevo;
		if (tipo == TipoMovimientoInventario.ajuste) {
			nuevo = cantidad;
		} else if (tipo == TipoMovimientoInventario.salida) {
			if (anterior < cantidad) {
				throw StateError('Stock insuficiente en almacén');
			}
			nuevo = anterior - cantidad;
		} else {
			nuevo = anterior + cantidad;
		}
		final ahora = DateTime.now().toUtc();
		await almacenRepo.guardarStock(
			StockAlmacen(
				productoId: productoId,
				almacenId: almacenId,
				cantidad: nuevo,
				actualizadoEn: ahora,
				stockMinimo: stockActual?.stockMinimo ?? 0,
			),
		);
	}

	/// Productos con existencia en un almacen.
	Future<List<({Producto producto, double cantidad})>>
	listarProductosConStockAlmacen(String almacenId) async {
		final almacenRepo = _almacenRepository;
		if (almacenRepo == null) {
			return [];
		}
		final stocks = await almacenRepo.listarStockPorAlmacen(almacenId);
		final resultado = <({Producto producto, double cantidad})>[];
		for (final stock in stocks) {
			if (stock.cantidad <= 0) {
				continue;
			}
			final producto = await _productoRepository.obtenerPorId(stock.productoId);
			if (producto != null && producto.activo) {
				resultado.add((producto: producto, cantidad: stock.cantidad));
			}
		}
		resultado.sort((a, b) => a.producto.nombre.compareTo(b.producto.nombre));
		return resultado;
	}
}
