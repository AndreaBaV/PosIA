/// Dominio de compras: alta de compra con recepción de mercancía (a tienda
/// o almacén) y consulta de historial.
///
/// Extraído de `ServicioAdmin`.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/asignacion_compra_solicitud.dart';
import '../models/linea_compra_solicitud.dart';
import '../repositories/almacen_repository.dart';
import '../repositories/compra_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/movimiento_inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';
import 'admin_almacenes.dart';

/// Alta de compras (recepción de mercancía) y su historial.
class AdminCompras {
	AdminCompras({
		required ProductoRepository productoRepository,
		required InventarioRepository inventarioRepository,
		required AdminEmisorEventosSync emisorEventos,
		required AdminAlmacenes almacenes,
		required Database baseDatos,
		CompraRepository? compraRepository,
		ProveedorRepository? proveedorRepository,
		AlmacenRepository? almacenRepository,
		MovimientoInventarioRepository? movimientoRepository,
	}) : _productoRepository = productoRepository,
	     _inventarioRepository = inventarioRepository,
	     _emisorEventos = emisorEventos,
	     _almacenes = almacenes,
	     _baseDatos = baseDatos,
	     _compraRepository = compraRepository,
	     _proveedorRepository = proveedorRepository,
	     _almacenRepository = almacenRepository,
	     _movimientoRepository = movimientoRepository;

	final ProductoRepository _productoRepository;
	final InventarioRepository _inventarioRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final AdminAlmacenes _almacenes;
	final Database _baseDatos;
	final CompraRepository? _compraRepository;
	final ProveedorRepository? _proveedorRepository;
	final AlmacenRepository? _almacenRepository;
	final MovimientoInventarioRepository? _movimientoRepository;
	final Uuid _generadorId = const Uuid();

	Future<T> _enTransaccion<T>(Future<T> Function(Transaction tx) accion) {
		return _baseDatos.transaction(accion);
	}

	/// Almacén por defecto para compras sin ubicación explícita.
	Future<Almacen> obtenerAlmacenPorDefectoCompra() async {
		final almacenes = await _almacenes.listarAlmacenes();
		final activos = almacenes.where((a) => a.activo).toList();
		if (activos.isEmpty) {
			throw StateError('No hay almacenes disponibles para recibir la compra');
		}
		final central = activos.where(
			(a) => a.nombre.toLowerCase().contains('central'),
		);
		if (central.isNotEmpty) {
			return central.first;
		}
		final sinTienda = activos.where((a) => a.tiendaId == null);
		if (sinTienda.isNotEmpty) {
			return sinTienda.first;
		}
		return activos.first;
	}

	List<AsignacionCompraSolicitud> _resolverUbicacionesCompra({
		required List<LineaCompraSolicitud> lineas,
		required List<AsignacionCompraSolicitud>? ubicaciones,
		required String almacenPorDefectoId,
	}) {
		if (ubicaciones == null || ubicaciones.isEmpty) {
			return lineas
				.map(
					(l) => AsignacionCompraSolicitud(
						productoId: l.productoId,
						destinoTipo: TipoDestinoCompra.almacen,
						destinoId: almacenPorDefectoId,
						cantidad: l.cantidad,
					),
				)
				.toList();
		}
		for (final u in ubicaciones) {
			if (u.cantidad <= 0) {
				throw StateError('La cantidad de ubicación debe ser mayor a cero');
			}
			if (u.destinoId.trim().isEmpty) {
				throw StateError('Ubicación de mercancía incompleta');
			}
		}
		for (final linea in lineas) {
			final suma = ubicaciones
				.where((u) => u.productoId == linea.productoId)
				.fold<double>(0.0, (acc, u) => acc + u.cantidad);
			if ((suma - linea.cantidad).abs() > 0.0001) {
				throw StateError(
					'Las ubicaciones del producto no suman la cantidad comprada',
				);
			}
		}
		return ubicaciones;
	}

	Future<Compra> registrarCompra({
		required String proveedorId,
		required List<LineaCompraSolicitud> lineas,
		required DateTime fechaCompra,
		String notas = '',
		List<AsignacionCompraSolicitud>? ubicaciones,
		Usuario? operador,
	}) async {
		final repo = _compraRepository;
		if (repo == null) {
			throw StateError('Repositorio de compras no configurado');
		}
		if (lineas.isEmpty) {
			throw StateError('Seleccione al menos un producto');
		}
		final proveedor = await _proveedorRepository?.obtenerPorId(proveedorId);
		if (proveedor == null) {
			throw StateError('Proveedor no encontrado');
		}
		final almacenDefecto = await obtenerAlmacenPorDefectoCompra();
		final ubicacionesEfectivas = _resolverUbicacionesCompra(
			lineas: lineas,
			ubicaciones: ubicaciones,
			almacenPorDefectoId: almacenDefecto.id,
		);
		for (final u in ubicacionesEfectivas) {
			if (u.destinoTipo == TipoDestinoCompra.tienda &&
				operador != null &&
				!PermisosUsuario.puedeGestionarTienda(operador, u.destinoId)) {
				throw StateError('Sin permiso para gestionar esta tienda');
			}
		}

		final ahora = DateTime.now().toUtc();
		final compraId = _generadorId.v4();
		final lineasCompra = <LineaCompra>[];
		final productosActualizados = <Producto>[];
		var total = 0.0;

		for (final solicitud in lineas) {
			if (solicitud.cantidad <= 0) {
				throw StateError('La cantidad debe ser mayor a cero');
			}
			if (solicitud.costoUnitario < 0) {
				throw StateError('El costo no puede ser negativo');
			}
			final producto = await _productoRepository.obtenerPorId(
				solicitud.productoId,
			);
			if (producto == null) {
				throw StateError('Producto no encontrado');
			}
			final costo = redondearMonto(solicitud.costoUnitario);
			final subtotal = redondearMonto(solicitud.cantidad * costo);
			total = total + subtotal;
			productosActualizados.add(
				producto.copiarCon(costoUnitario: costo, proveedorId: proveedorId),
			);
			lineasCompra.add(
				LineaCompra(
					productoId: solicitud.productoId,
					nombreProducto: producto.nombre,
					cantidad: solicitud.cantidad,
					costoUnitario: costo,
					subtotal: subtotal,
				),
			);
		}

		final asignaciones = ubicacionesEfectivas
			.map(
				(u) => AsignacionCompra(
					id: _generadorId.v4(),
					productoId: u.productoId,
					destinoTipo: u.destinoTipo,
					destinoId: u.destinoId,
					cantidad: u.cantidad,
				),
			)
			.toList();

		final compra = Compra(
			id: compraId,
			proveedorId: proveedorId,
			fechaCompra: fechaCompra.toUtc(),
			notas: notas.trim(),
			total: redondearMonto(total),
			creadaEn: ahora,
			creadoPor: operador?.id,
			lineas: lineasCompra,
			asignaciones: asignaciones,
		);

		final almacenRepo = _almacenRepository;
		await _enTransaccion((tx) async {
			for (var i = 0; i < lineasCompra.length; i++) {
				await _productoRepository.guardar(productosActualizados[i], db: tx);
			}
			for (final asignacion in asignaciones) {
				final motivo = 'Compra ${compraId.substring(0, 8).toUpperCase()}';
				if (asignacion.destinoTipo == TipoDestinoCompra.tienda) {
					final stockActual = await _inventarioRepository.obtenerStock(
						asignacion.productoId,
						asignacion.destinoId,
						db: tx,
					);
					final anterior = stockActual?.cantidad ?? 0.0;
					final nuevo = anterior + asignacion.cantidad;
					await _inventarioRepository.guardarStock(
						StockNivel(
							productoId: asignacion.productoId,
							tiendaId: asignacion.destinoId,
							cantidad: nuevo,
							actualizadoEn: ahora,
							stockMinimo: stockActual?.stockMinimo ?? 0.0,
						),
						db: tx,
					);
					final movimientoRepo = _movimientoRepository;
					if (movimientoRepo != null) {
						await movimientoRepo.guardar(
							MovimientoInventario(
								id: _generadorId.v4(),
								productoId: asignacion.productoId,
								tiendaId: asignacion.destinoId,
								tipo: TipoMovimientoInventario.entrada,
								cantidad: asignacion.cantidad,
								cantidadAnterior: anterior,
								cantidadNueva: nuevo,
								motivo: motivo,
								referenciaId: compraId,
								proveedorId: proveedorId,
								creadoEn: ahora,
								creadoPor: operador?.id,
							),
							db: tx,
						);
					}
				} else {
					if (almacenRepo == null) {
						throw StateError('Almacenes no disponibles');
					}
					final stockActual = await almacenRepo.obtenerStock(
						asignacion.productoId,
						asignacion.destinoId,
						db: tx,
					);
					final anterior = stockActual?.cantidad ?? 0.0;
					await almacenRepo.guardarStock(
						StockAlmacen(
							productoId: asignacion.productoId,
							almacenId: asignacion.destinoId,
							cantidad: anterior + asignacion.cantidad,
							actualizadoEn: ahora,
							stockMinimo: stockActual?.stockMinimo ?? 0,
						),
						db: tx,
					);
				}
			}
			await repo.guardar(compra, db: tx);
		});

		for (final producto in productosActualizados) {
			await _emisorEventos.producto(producto);
		}
		await _emisorEventos.compra(compra);
		return compra;
	}

	Future<List<Compra>> listarCompras() async {
		// Historial a nivel empresa (razon social); no se filtra por tienda.
		return _compraRepository?.listarTodas() ?? [];
	}

	Future<Compra?> obtenerCompra(String compraId) async {
		return _compraRepository?.obtenerPorId(compraId);
	}
}
