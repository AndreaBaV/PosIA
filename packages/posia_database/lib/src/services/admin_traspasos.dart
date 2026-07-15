/// Dominio de traspasos entre tiendas: alta directa (un paso) y flujo de
/// dos pasos (solicitar → recibir).
///
/// Extraído de `ServicioAdmin`. Los traspasos con origen/destino en
/// almacén viven en `ServicioAdmin` (`traspasarAlmacenA*`/
/// `_registrarEventoTraspasoAlmacen`) — dominio relacionado pero distinto.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/linea_traspaso_solicitud.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Traspasos de mercancía entre tiendas.
class AdminTraspasos {
	AdminTraspasos({
		required ProductoRepository productoRepository,
		required InventarioRepository inventarioRepository,
		required AdminEmisorEventosSync emisorEventos,
		required Database baseDatos,
		required String tiendaActivaId,
		TraspasoRepository? traspasoRepository,
		MovimientoInventarioRepository? movimientoRepository,
	}) : _productoRepository = productoRepository,
	     _inventarioRepository = inventarioRepository,
	     _emisorEventos = emisorEventos,
	     _baseDatos = baseDatos,
	     _tiendaActivaId = tiendaActivaId,
	     _traspasoRepository = traspasoRepository,
	     _movimientoRepository = movimientoRepository;

	final ProductoRepository _productoRepository;
	final InventarioRepository _inventarioRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final Database _baseDatos;
	final String _tiendaActivaId;
	final TraspasoRepository? _traspasoRepository;
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

	Future<List<Traspaso>> listarTraspasos() async {
		final traspasos = await _traspasoRepository?.listarTodos() ?? [];
		final enriquecidos = <Traspaso>[];
		for (final traspaso in traspasos) {
			final lineas = <LineaTraspaso>[];
			for (final linea in traspaso.lineas) {
				if (linea.nombreProducto.isNotEmpty) {
					lineas.add(linea);
					continue;
				}
				final producto = await _productoRepository.obtenerPorId(
					linea.productoId,
				);
				lineas.add(
					LineaTraspaso(
						productoId: linea.productoId,
						nombreProducto: producto?.nombre ?? linea.productoId,
						cantidadSolicitada: linea.cantidadSolicitada,
						cantidadRecibida: linea.cantidadRecibida,
					),
				);
			}
			enriquecidos.add(
				Traspaso(
					id: traspaso.id,
					tiendaOrigenId: traspaso.tiendaOrigenId,
					tiendaDestinoId: traspaso.tiendaDestinoId,
					estado: traspaso.estado,
					solicitadoEn: traspaso.solicitadoEn,
					completadoEn: traspaso.completadoEn,
					notas: traspaso.notas,
					lineas: lineas,
				),
			);
		}
		return enriquecidos;
	}

	Future<Traspaso> realizarTraspaso({
		required String tiendaOrigenId,
		required String tiendaDestinoId,
		required String productoId,
		required double cantidad,
		String notas = '',
		Usuario? operador,
	}) {
		return realizarTraspasoMultiple(
			tiendaOrigenId: tiendaOrigenId,
			tiendaDestinoId: tiendaDestinoId,
			lineas: [
				LineaTraspasoSolicitud(productoId: productoId, cantidad: cantidad),
			],
			notas: notas,
			operador: operador,
		);
	}

	Future<Traspaso> realizarTraspasoMultiple({
		required String tiendaOrigenId,
		required String tiendaDestinoId,
		required List<LineaTraspasoSolicitud> lineas,
		String notas = '',
		Usuario? operador,
	}) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			throw StateError('Repositorio de traspasos no configurado');
		}
		if (tiendaOrigenId == tiendaDestinoId) {
			throw StateError('Origen y destino deben ser tiendas distintas');
		}
		if (lineas.isEmpty) {
			throw StateError('Seleccione al menos un producto');
		}
		_validarPermisoTienda(operador, tiendaOrigenId);
		_validarPermisoTienda(operador, tiendaDestinoId);

		final lineasTraspaso = <LineaTraspaso>[];
		final ahora = DateTime.now().toUtc();
		final lineasPendientes =
			<
				({
					String productoId,
					double cantidad,
					double anteriorOrigen,
					double anteriorDestino,
				})
			>[];

		for (final solicitud in lineas) {
			if (solicitud.cantidad <= 0) {
				throw StateError('La cantidad debe ser mayor a cero');
			}
			final producto =
				await _productoRepository.obtenerPorId(solicitud.productoId) ??
				(await _productoRepository.listarActivosPorTienda(
					tiendaOrigenId,
				)).where((p) => p.id == solicitud.productoId).firstOrNull;
			if (producto == null) {
				throw StateError('Producto no encontrado: ${solicitud.productoId}');
			}

			final stockOrigen = await _inventarioRepository.obtenerStock(
				solicitud.productoId,
				tiendaOrigenId,
			);
			final anteriorOrigen = stockOrigen?.cantidad ?? 0.0;
			if (anteriorOrigen < solicitud.cantidad) {
				throw StateError('Stock insuficiente de ${producto.nombre} en origen');
			}

			final stockDestino = await _inventarioRepository.obtenerStock(
				solicitud.productoId,
				tiendaDestinoId,
			);
			final anteriorDestino = stockDestino?.cantidad ?? 0.0;

			lineasPendientes.add((
				productoId: solicitud.productoId,
				cantidad: solicitud.cantidad,
				anteriorOrigen: anteriorOrigen,
				anteriorDestino: anteriorDestino,
			));

			lineasTraspaso.add(
				LineaTraspaso(
					productoId: solicitud.productoId,
					nombreProducto: producto.nombre,
					cantidadSolicitada: solicitud.cantidad,
					cantidadRecibida: solicitud.cantidad,
				),
			);
		}

		final traspaso = Traspaso(
			id: _generadorId.v4(),
			tiendaOrigenId: tiendaOrigenId,
			tiendaDestinoId: tiendaDestinoId,
			estado: EstadoTraspaso.completado,
			solicitadoEn: ahora,
			completadoEn: ahora,
			notas: notas,
			lineas: lineasTraspaso,
		);

		await _enTransaccion((tx) async {
			for (final linea in lineasPendientes) {
				final stockOrigen = await _inventarioRepository.obtenerStock(
					linea.productoId,
					tiendaOrigenId,
					db: tx,
				);
				final anteriorOrigen = stockOrigen?.cantidad ?? 0.0;
				final nuevoOrigen = anteriorOrigen - linea.cantidad;
				await _inventarioRepository.guardarStock(
					StockNivel(
						productoId: linea.productoId,
						tiendaId: tiendaOrigenId,
						cantidad: nuevoOrigen,
						actualizadoEn: ahora,
						stockMinimo: stockOrigen?.stockMinimo ?? 0.0,
					),
					db: tx,
				);

				final stockDestino = await _inventarioRepository.obtenerStock(
					linea.productoId,
					tiendaDestinoId,
					db: tx,
				);
				final anteriorDestino = stockDestino?.cantidad ?? 0.0;
				final nuevoDestino = anteriorDestino + linea.cantidad;
				await _inventarioRepository.guardarStock(
					StockNivel(
						productoId: linea.productoId,
						tiendaId: tiendaDestinoId,
						cantidad: nuevoDestino,
						actualizadoEn: ahora,
						stockMinimo: stockDestino?.stockMinimo ?? 0.0,
					),
					db: tx,
				);

				await _registrarAuditoriaInventario(
					productoId: linea.productoId,
					tiendaId: tiendaOrigenId,
					tipo: TipoMovimientoInventario.traspasoSalida,
					cantidad: linea.cantidad,
					cantidadAnterior: anteriorOrigen,
					cantidadNueva: nuevoOrigen,
					motivo: 'Traspaso enviado',
					operadorId: operador?.id,
					creadoEn: ahora,
					db: tx,
				);
				await _registrarAuditoriaInventario(
					productoId: linea.productoId,
					tiendaId: tiendaDestinoId,
					tipo: TipoMovimientoInventario.traspasoEntrada,
					cantidad: linea.cantidad,
					cantidadAnterior: anteriorDestino,
					cantidadNueva: nuevoDestino,
					motivo: 'Traspaso recibido',
					operadorId: operador?.id,
					creadoEn: ahora,
					db: tx,
				);
			}
			await repo.guardar(traspaso, db: tx);
		});
		await _emisorEventos.traspaso(traspaso, TipoSyncEvento.transferCompleted);
		return traspaso;
	}

	/// Compatibilidad: delega en [realizarTraspaso] usando [tiendaOrigenId]
	/// pasado explícitamente por el llamador (antes: tienda activa del
	/// dispositivo — el llamador en `ServicioAdmin` sigue resolviendo eso).
	Future<Traspaso> solicitarTraspaso({
		required String tiendaDestinoId,
		required String productoId,
		required double cantidad,
		String notas = '',
	}) {
		return realizarTraspaso(
			tiendaOrigenId: _tiendaActivaId,
			tiendaDestinoId: tiendaDestinoId,
			productoId: productoId,
			cantidad: cantidad,
			notas: notas,
		);
	}

	/// Completa traspasos antiguos en transito (flujo de dos pasos).
	Future<bool> recibirTraspaso(String traspasoId) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return false;
		}
		final traspaso = await repo.obtenerPorId(traspasoId);
		if (traspaso == null || traspaso.estado == EstadoTraspaso.completado) {
			return false;
		}
		if (traspaso.estado != EstadoTraspaso.enTransito) {
			return false;
		}
		if (traspaso.tiendaDestinoId != _tiendaActivaId) {
			return false;
		}
		final ahora = DateTime.now().toUtc();
		final lineasRecibidas = traspaso.lineas
			.map(
				(linea) => LineaTraspaso(
					productoId: linea.productoId,
					nombreProducto: linea.nombreProducto,
					cantidadSolicitada: linea.cantidadSolicitada,
					cantidadRecibida: linea.cantidadSolicitada,
				),
			)
			.toList();
		final completado = Traspaso(
			id: traspaso.id,
			tiendaOrigenId: traspaso.tiendaOrigenId,
			tiendaDestinoId: traspaso.tiendaDestinoId,
			estado: EstadoTraspaso.completado,
			solicitadoEn: traspaso.solicitadoEn,
			completadoEn: ahora,
			notas: traspaso.notas,
			lineas: lineasRecibidas,
		);
		await _enTransaccion((tx) async {
			for (final linea in traspaso.lineas) {
				final stock = await _inventarioRepository.obtenerStock(
					linea.productoId,
					_tiendaActivaId,
					db: tx,
				);
				final anterior = stock?.cantidad ?? 0.0;
				final cantidadNueva = anterior + linea.cantidadSolicitada;
				await _inventarioRepository.guardarStock(
					StockNivel(
						productoId: linea.productoId,
						tiendaId: _tiendaActivaId,
						cantidad: cantidadNueva,
						actualizadoEn: ahora,
						stockMinimo: stock?.stockMinimo ?? 0.0,
					),
					db: tx,
				);
				await _registrarAuditoriaInventario(
					productoId: linea.productoId,
					tiendaId: _tiendaActivaId,
					tipo: TipoMovimientoInventario.traspasoEntrada,
					cantidad: linea.cantidadSolicitada,
					cantidadAnterior: anterior,
					cantidadNueva: cantidadNueva,
					motivo: 'Traspaso recibido',
					creadoEn: ahora,
					db: tx,
				);
			}
			await repo.guardar(completado, db: tx);
		});
		await _emisorEventos.traspaso(
			completado,
			TipoSyncEvento.transferCompleted,
		);
		return true;
	}

	Future<void> _registrarAuditoriaInventario({
		required String productoId,
		required String tiendaId,
		required TipoMovimientoInventario tipo,
		required double cantidad,
		required double cantidadAnterior,
		required double cantidadNueva,
		required String motivo,
		required DateTime creadoEn,
		String? operadorId,
		DatabaseExecutor? db,
	}) async {
		final repo = _movimientoRepository;
		if (repo == null) {
			return;
		}
		await repo.guardar(
			MovimientoInventario(
				id: _generadorId.v4(),
				productoId: productoId,
				tiendaId: tiendaId,
				tipo: tipo,
				cantidad: cantidad,
				cantidadAnterior: cantidadAnterior,
				cantidadNueva: cantidadNueva,
				motivo: motivo,
				referenciaId: null,
				proveedorId: null,
				creadoEn: creadoEn,
				creadoPor: operadorId,
			),
			db: db,
		);
	}
}
