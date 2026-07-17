/// Dominio de inventario a nivel tienda: movimientos manuales (ajuste,
/// salida — las entradas se registran vía Compras), stock mínimo y
/// alertas de faltante.
///
/// Extraído de `ServicioAdmin`.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/alerta_faltante.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/tienda_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Movimientos manuales de inventario, stock mínimo y alertas de faltante.
class AdminInventarioMovimientos {
	AdminInventarioMovimientos({
		required InventarioRepository inventarioRepository,
		required ProductoRepository productoRepository,
		required TiendaRepository tiendaRepository,
		required AdminEmisorEventosSync emisorEventos,
		required Database baseDatos,
		required String tiendaActivaId,
		MovimientoInventarioRepository? movimientoRepository,
	}) : _inventarioRepository = inventarioRepository,
	     _productoRepository = productoRepository,
	     _tiendaRepository = tiendaRepository,
	     _emisorEventos = emisorEventos,
	     _baseDatos = baseDatos,
	     _tiendaActivaId = tiendaActivaId,
	     _movimientoRepository = movimientoRepository;

	final InventarioRepository _inventarioRepository;
	final ProductoRepository _productoRepository;
	final TiendaRepository _tiendaRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final Database _baseDatos;
	final String _tiendaActivaId;
	final MovimientoInventarioRepository? _movimientoRepository;
	final Uuid _generadorId = const Uuid();

	Future<T> _enTransaccion<T>(Future<T> Function(Transaction tx) accion) {
		return _baseDatos.transaction(accion);
	}

	void _validarPermisoTienda(Usuario? operador, String tiendaId) {
		if (operador != null &&
			!PermisosUsuario.puedeGestionarTienda(operador, tiendaId)) {
			throw StateError('Sin permiso para gestionar esta tienda');
		}
	}

	Future<void> registrarMovimientoInventario({
		required String productoId,
		required TipoMovimientoInventario tipo,
		required double cantidad,
		required String motivo,
		String? proveedorId,
		String? tiendaId,
		Usuario? operador,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			throw StateError('Repositorio de movimientos no configurado');
		}
		final tiendaDestino = tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, tiendaDestino);
		if (tipo == TipoMovimientoInventario.entrada) {
			throw StateError('Registre las entradas en la seccion Compras');
		}
		final motivoLimpio = motivo.trim();
		if (!esMotivoInventarioValido(tipo, motivoLimpio)) {
			throw StateError('Seleccione un motivo válido del catálogo');
		}
		final stockActual = await _inventarioRepository.obtenerStock(
			productoId,
			tiendaDestino,
		);
		final anterior = stockActual?.cantidad ?? 0.0;
		double nuevo;
		double delta;
		if (tipo == TipoMovimientoInventario.ajuste) {
			nuevo = cantidad;
			delta = nuevo - anterior;
		} else if (tipo == TipoMovimientoInventario.salida) {
			if (anterior < cantidad) {
				throw StateError('Stock insuficiente');
			}
			nuevo = anterior - cantidad;
			delta = -cantidad;
		} else {
			nuevo = anterior + cantidad;
			delta = cantidad;
		}
		final ahora = DateTime.now().toUtc();
		await _enTransaccion((tx) async {
			final stockEnTx = await _inventarioRepository.obtenerStock(
				productoId,
				tiendaDestino,
				db: tx,
			);
			final baseAnterior = stockEnTx?.cantidad ?? anterior;
			final cantidadFinal = tipo == TipoMovimientoInventario.ajuste
				? cantidad
				: baseAnterior + delta;
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: productoId,
					tiendaId: tiendaDestino,
					cantidad: cantidadFinal,
					actualizadoEn: ahora,
					stockMinimo:
						stockEnTx?.stockMinimo ?? stockActual?.stockMinimo ?? 0.0,
				),
				db: tx,
			);
			await repo.guardar(
				MovimientoInventario(
					id: _generadorId.v4(),
					productoId: productoId,
					tiendaId: tiendaDestino,
					tipo: tipo,
					cantidad: cantidad,
					cantidadAnterior: baseAnterior,
					cantidadNueva: cantidadFinal,
					motivo: motivoLimpio,
					referenciaId: null,
					proveedorId: proveedorId,
					creadoEn: ahora,
					creadoPor: operador?.id,
				),
				db: tx,
			);
		});
		await _emisorEventos.ajusteStock(
			productoId,
			delta,
			motivoLimpio,
			tiendaId: tiendaDestino,
		);
	}

	Future<List<MovimientoInventario>> listarMovimientosInventario({
		String? tiendaId,
		Usuario? operador,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			return [];
		}
		final tiendaDestino = tiendaId ?? operador?.tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, tiendaDestino);
		return repo.listarPorTienda(tiendaDestino);
	}

	Future<void> configurarStockMinimo(
		String productoId,
		double stockMinimo, {
		String? tiendaId,
		Usuario? operador,
	}) async {
		final tiendaDestino = tiendaId ?? _tiendaActivaId;
		_validarPermisoTienda(operador, tiendaDestino);
		final stock = await _inventarioRepository.obtenerStock(
			productoId,
			tiendaDestino,
		);
		if (stock == null) {
			final ahora = DateTime.now().toUtc();
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: productoId,
					tiendaId: tiendaDestino,
					cantidad: 0.0,
					actualizadoEn: ahora,
					stockMinimo: stockMinimo,
				),
			);
			return;
		}
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaDestino,
				cantidad: stock.cantidad,
				actualizadoEn: stock.actualizadoEn,
				stockMinimo: stockMinimo,
			),
		);
	}

	Future<List<AlertaFaltante>> obtenerAlertasFaltantes({String? tiendaId}) async {
		final tiendas = await _tiendaRepository.listarActivas();
		final ids = tiendaId != null
			? [tiendaId]
			: tiendas.map((t) => t.id).toList();
		final alertas = <AlertaFaltante>[];
		for (final id in ids) {
			final bajoMinimo = await _inventarioRepository.listarBajoMinimo(id);
			final productos = await _productoRepository.listarActivosPorTienda(id);
			final nombres = {for (final p in productos) p.id: p.nombre};
			alertas.addAll(
				bajoMinimo.map(
					(stock) => AlertaFaltante(
						productoId: stock.productoId,
						nombreProducto: nombres[stock.productoId] ?? stock.productoId,
						cantidadActual: stock.cantidad,
						stockMinimo: stock.stockMinimo,
						tiendaId: stock.tiendaId,
					),
				),
			);
		}
		alertas.sort((a, b) => a.cantidadActual.compareTo(b.cantidadActual));
		return alertas;
	}
}
