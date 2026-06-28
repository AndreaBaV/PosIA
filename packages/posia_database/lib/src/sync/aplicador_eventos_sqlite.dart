/// Aplicador de eventos remotos sobre la base SQLite local.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:40:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

import '../repositories/almacen_repository.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/variante_repository.dart';
import '../repositories/venta_repository.dart';

/// Implementa [AplicadorEventosRemotos] con escritura idempotente.
class AplicadorEventosSqlite implements AplicadorEventosRemotos {
	/// Crea aplicador con repositorios locales.
	///
	/// [baseDatos] Conexion SQLite activa.
	/// [productoRepository] Catalogo local.
	/// [clienteRepository] Clientes locales.
	/// [ventaRepository] Ventas locales.
	/// [inventarioRepository] Stock local multi-tienda.
	AplicadorEventosSqlite({
		required Database baseDatos,
		required ProductoRepository productoRepository,
		required ClienteRepository clienteRepository,
		required VentaRepository ventaRepository,
		required InventarioRepository inventarioRepository,
		CategoriaRepository? categoriaRepository,
		TraspasoRepository? traspasoRepository,
		VarianteRepository? varianteRepository,
		TiendaRepository? tiendaRepository,
		UsuarioRepository? usuarioRepository,
		AlmacenRepository? almacenRepository,
	}) : _baseDatos = baseDatos,
	     _productoRepository = productoRepository,
	     _clienteRepository = clienteRepository,
	     _ventaRepository = ventaRepository,
	     _inventarioRepository = inventarioRepository,
	     _categoriaRepository = categoriaRepository,
	     _traspasoRepository = traspasoRepository,
	     _varianteRepository = varianteRepository,
	     _tiendaRepository = tiendaRepository,
	     _usuarioRepository = usuarioRepository,
	     _almacenRepository = almacenRepository;

	final Database _baseDatos;
	final ProductoRepository _productoRepository;
	final ClienteRepository _clienteRepository;
	final VentaRepository _ventaRepository;
	final InventarioRepository _inventarioRepository;
	final CategoriaRepository? _categoriaRepository;
	final TraspasoRepository? _traspasoRepository;
	final VarianteRepository? _varianteRepository;
	final TiendaRepository? _tiendaRepository;
	final UsuarioRepository? _usuarioRepository;
	final AlmacenRepository? _almacenRepository;

	@override
	Future<void> aplicarLote(List<SyncEvent> eventos) async {
		if (eventos.isEmpty) {
			return;
		}
		await _baseDatos.transaction((tx) async {
			for (final evento in eventos) {
				await _aplicarEventoInterno(evento, ejecutor: tx);
			}
		});
	}

	@override
	Future<void> aplicarEvento(SyncEvent evento) async {
		await _aplicarEventoInterno(evento);
	}

	Future<void> _aplicarEventoInterno(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		switch (evento.tipo) {
			case TipoSyncEvento.saleCompleted:
				await _aplicarVentaRemota(evento, ejecutor: ejecutor);
			case TipoSyncEvento.productUpserted:
				await _aplicarProductoRemoto(evento);
			case TipoSyncEvento.customerUpserted:
				await _aplicarClienteRemoto(evento);
			case TipoSyncEvento.stockAdjusted:
				await _aplicarAjusteStockRemoto(evento, ejecutor: ejecutor);
			case TipoSyncEvento.saleVoided:
				await _aplicarAnulacionRemota(evento, ejecutor: ejecutor);
			case TipoSyncEvento.categoryUpserted:
				await _aplicarCategoriaRemota(evento);
			case TipoSyncEvento.transferRequested:
				await _aplicarTraspasoSolicitado(evento, ejecutor: ejecutor);
			case TipoSyncEvento.transferCompleted:
				await _aplicarTraspasoCompletado(evento, ejecutor: ejecutor);
			case TipoSyncEvento.variantUpserted:
				await _aplicarVarianteRemota(evento);
			case TipoSyncEvento.salePartialReturn:
				await _aplicarDevolucionParcialRemota(evento);
			case TipoSyncEvento.storeUpserted:
				await _aplicarTiendaRemota(evento);
			case TipoSyncEvento.userUpserted:
				await _aplicarUsuarioRemoto(evento);
			case TipoSyncEvento.warehouseUpserted:
			case TipoSyncEvento.presentationTypeUpserted:
			case TipoSyncEvento.productPresentationUpserted:
			case TipoSyncEvento.attendanceChallengeCreated:
			case TipoSyncEvento.attendanceCheckedIn:
			case TipoSyncEvento.attendanceCheckedOut:
			case TipoSyncEvento.employeeProfileUpserted:
			case TipoSyncEvento.payrollPeriodClosed:
				break;
		}
	}

	Future<void> _aplicarTiendaRemota(SyncEvent evento) async {
		final repo = _tiendaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardar(
			Tienda(
				id: id,
				nombre: payload['nombre'] as String? ?? '',
				direccion: payload['direccion'] as String? ?? '',
				activa: payload['activa'] as bool? ?? true,
				latitud: (payload['latitud'] as num?)?.toDouble(),
				longitud: (payload['longitud'] as num?)?.toDouble(),
				radioMetrosAsistencia:
					(payload['radioMetrosAsistencia'] as num?)?.toDouble() ?? 150,
			),
		);
	}

	Future<void> _aplicarUsuarioRemoto(SyncEvent evento) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		final pinHash = payload['pinHash'] as String?;
		final pinSalt = payload['pinSalt'] as String?;
		if (id.isEmpty || pinHash == null || pinSalt == null) {
			return;
		}
		final rolNombre = payload['rol'] as String? ?? RolUsuario.empleado.name;
		final rol = RolUsuario.values.firstWhere(
			(valor) => valor.name == rolNombre,
			orElse: () => RolUsuario.empleado,
		);
		await repo.guardarRemoto(
			id: id,
			nombre: payload['nombre'] as String? ?? '',
			codigo: payload['codigo'] as String? ?? '',
			rol: rol,
			tiendaId: payload['tiendaId'] as String?,
			activo: payload['activo'] as bool? ?? true,
			pinHash: pinHash,
			pinSalt: pinSalt,
			creadoEn: payload['creadoEn'] as String? ?? evento.creadoEn.toIso8601String(),
			actualizadoEn:
				payload['actualizadoEn'] as String? ?? evento.creadoEn.toIso8601String(),
		);
	}

	Future<void> _aplicarVarianteRemota(SyncEvent evento) async {
		final repo = _varianteRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardar(
			VarianteProducto(
				id: id,
				productoPadreId: payload['productoPadreId'] as String? ?? '',
				nombre: payload['nombre'] as String? ?? '',
				sku: payload['sku'] as String? ?? '',
				codigoBarras: payload['codigoBarras'] as String? ?? '',
				precioBase: (payload['precioBase'] as num?)?.toDouble() ?? 0.0,
				activo: payload['activo'] as bool? ?? true,
			),
		);
	}

	Future<void> _aplicarDevolucionParcialRemota(SyncEvent evento) async {
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final venta = await _ventaRepository.obtenerPorId(ventaId);
		if (venta == null || venta.estado == EstadoVenta.cancelada) {
			return;
		}
		final lineasCrudas = evento.payload['lineas'] as List<Object?>? ?? [];
		final lineasActualizadas = <LineaVenta>[];
		for (final linea in venta.lineas) {
			var cantidadRestante = linea.cantidad;
			for (final cruda in lineasCrudas.whereType<Map<Object?, Object?>>()) {
				final mapa = Map<String, Object?>.from(cruda);
				if (mapa['productoId'] == linea.productoId) {
					final devuelta = (mapa['cantidadDevuelta'] as num?)?.toDouble() ?? 0.0;
					cantidadRestante = cantidadRestante - devuelta;
					await _ajustarStock(linea.productoId, evento.tiendaId, devuelta);
				}
			}
			if (cantidadRestante > 0.0) {
				lineasActualizadas.add(
					LineaVenta(
						productoId: linea.productoId,
						nombreProducto: linea.nombreProducto,
						cantidad: cantidadRestante,
						precioUnitario: linea.precioUnitario,
						reglaPrecio: linea.reglaPrecio,
						loteId: linea.loteId,
						etiquetaLote: linea.etiquetaLote,
					),
				);
			}
		}
		final nuevoTotal = Venta.calcularTotalDesdeLineas(lineasActualizadas);
		final nuevoEstado = lineasActualizadas.isEmpty
			? EstadoVenta.devuelta
			: EstadoVenta.completada;
		await _ventaRepository.actualizarVenta(
			venta.copiarCon(
				lineas: lineasActualizadas,
				total: nuevoTotal,
				estado: nuevoEstado,
			),
		);
	}

	Future<void> _aplicarAnulacionRemota(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final venta = await _ventaRepository.obtenerPorId(ventaId);
		if (venta == null || !venta.puedeAnularse()) {
			return;
		}
		for (final linea in venta.lineas) {
			await _ajustarStock(
				linea.productoId,
				venta.tiendaId,
				linea.cantidad,
				ejecutor: ejecutor,
			);
		}
		await _ventaRepository.actualizarEstado(ventaId, EstadoVenta.cancelada);
	}

	Future<void> _aplicarCategoriaRemota(SyncEvent evento) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final categoria = Categoria(
			id: payload['id'] as String? ?? '',
			nombre: payload['nombre'] as String? ?? '',
			icono: payload['icono'] as String? ?? 'shopping_basket',
			colorHex: payload['colorHex'] as String? ?? '#4CAF50',
			orden: (payload['orden'] as num?)?.toInt() ?? 0,
			activa: payload['activa'] as bool? ?? true,
		);
		if (categoria.id.isEmpty) {
			return;
		}
		await repo.guardar(categoria);
	}

	Future<void> _aplicarTraspasoSolicitado(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return;
		}
		final traspaso = _mapearTraspasoRemoto(evento, EstadoTraspaso.enTransito);
		await repo.guardar(traspaso, db: ejecutor);
	}

	Future<void> _aplicarTraspasoCompletado(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final traspaso = _mapearTraspasoRemoto(evento, EstadoTraspaso.completado);
		await repo.guardar(traspaso, db: ejecutor);
		final almacenOrigen = payload['almacenOrigenId'] as String? ?? '';
		final almacenDestino = payload['almacenDestinoId'] as String? ?? '';
		for (final linea in traspaso.lineas) {
			final cantidad = linea.cantidadRecibida ?? linea.cantidadSolicitada;
			if (cantidad <= 0) {
				continue;
			}
			if (almacenOrigen.isNotEmpty) {
				await _ajustarStockAlmacen(
					linea.productoId,
					almacenOrigen,
					-cantidad,
					ejecutor: ejecutor,
				);
			} else if (traspaso.tiendaOrigenId.isNotEmpty) {
				await _ajustarStock(
					linea.productoId,
					traspaso.tiendaOrigenId,
					-cantidad,
					ejecutor: ejecutor,
				);
			}
			if (almacenDestino.isNotEmpty) {
				await _ajustarStockAlmacen(
					linea.productoId,
					almacenDestino,
					cantidad,
					ejecutor: ejecutor,
				);
			} else if (traspaso.tiendaDestinoId.isNotEmpty) {
				await _ajustarStock(
					linea.productoId,
					traspaso.tiendaDestinoId,
					cantidad,
					ejecutor: ejecutor,
				);
			}
		}
	}

	Traspaso _mapearTraspasoRemoto(SyncEvent evento, EstadoTraspaso estado) {
		final lineasCrudas = evento.payload['lineas'] as List<Object?>? ?? [];
		final lineas = lineasCrudas
			.whereType<Map<Object?, Object?>>()
			.map(
				(cruda) => LineaTraspaso(
					productoId: cruda['productoId'] as String? ?? '',
					nombreProducto: '',
					cantidadSolicitada: (cruda['cantidadSolicitada'] as num?)?.toDouble() ?? 0.0,
					cantidadRecibida: (cruda['cantidadRecibida'] as num?)?.toDouble(),
				),
			)
			.toList();
		return Traspaso(
			id: evento.payload['traspasoId'] as String? ?? evento.id,
			tiendaOrigenId: evento.payload['tiendaOrigenId'] as String? ?? '',
			tiendaDestinoId: evento.payload['tiendaDestinoId'] as String? ?? '',
			estado: estado,
			solicitadoEn: evento.creadoEn,
			completadoEn: estado == EstadoTraspaso.completado ? evento.creadoEn : null,
			notas: '',
			lineas: lineas,
		);
	}

	/// Inserta venta remota y descuenta stock de su tienda.
	///
	/// [evento] Evento saleCompleted de otra caja.
	Future<void> _aplicarVentaRemota(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final existentes = await _baseDatos.query(
			'sales',
			where: 'id = ?',
			whereArgs: [ventaId],
			limit: 1,
		);
		if (existentes.isNotEmpty) {
			return;
		}
		final lineasCrudas = evento.payload['lineas'] as List<Object?>? ?? [];
		final lineas = lineasCrudas
			.whereType<Map<Object?, Object?>>()
			.map((cruda) => _mapearLineaRemota(Map<String, Object?>.from(cruda)))
			.toList();
		final metodoNombre = evento.payload['metodoPago'] as String? ?? '';
		final metodo = MetodoPago.values.firstWhere(
			(valor) => valor.name == metodoNombre,
			orElse: () => MetodoPago.efectivo,
		);
		final venta = Venta(
			id: ventaId,
			tiendaId: evento.tiendaId,
			cajaId: evento.dispositivoId,
			clienteId: evento.payload['clienteId'] as String?,
			lineas: lineas,
			metodoPago: metodo,
			total: (evento.payload['total'] as num?)?.toDouble() ?? 0.0,
			creadaEn: evento.creadoEn,
		);
		await _ventaRepository.guardar(venta);
		for (final linea in lineas) {
			await _ajustarStock(
				linea.productoId,
				evento.tiendaId,
				-linea.cantidad,
				ejecutor: ejecutor,
			);
		}
	}

	/// Inserta o actualiza producto remoto en catalogo local.
	///
	/// [evento] Evento productUpserted.
	Future<void> _aplicarProductoRemoto(SyncEvent evento) async {
		final payload = evento.payload;
		final productoId = payload['id'] as String? ?? '';
		if (productoId.isEmpty) {
			return;
		}
		final unidadNombre = payload['unidadMedida'] as String? ?? UnidadMedida.pieza.name;
		final verticalNombre = payload['moduloVertical'] as String? ?? ModuloVertical.general.name;
		final producto = Producto(
			id: productoId,
			nombre: payload['nombre'] as String? ?? '',
			codigoBarras: payload['codigoBarras'] as String? ?? '',
			precioBase: (payload['precioBase'] as num?)?.toDouble() ?? 0.0,
			unidadMedida: UnidadMedida.values.firstWhere(
				(valor) => valor.name == unidadNombre,
				orElse: () => UnidadMedida.pieza,
			),
			rutaImagen: payload['rutaImagen'] as String? ?? '',
			activo: payload['activo'] as bool? ?? true,
			tiendaId: payload['tiendaId'] as String? ?? evento.tiendaId,
			moduloVertical: ModuloVertical.values.firstWhere(
				(valor) => valor.name == verticalNombre,
				orElse: () => ModuloVertical.general,
			),
			categoriaId: payload['categoriaId'] as String?,
			piezasPorCaja: (payload['piezasPorCaja'] as num?)?.toInt(),
			unidadesPorBulto: (payload['unidadesPorBulto'] as num?)?.toInt(),
			proveedorId: payload['proveedorId'] as String?,
			notas: payload['notas'] as String? ?? '',
			permiteStockNegativo: payload['permiteStockNegativo'] as bool? ?? false,
		);
		await _productoRepository.guardar(producto);
	}

	/// Inserta o actualiza cliente remoto.
	///
	/// [evento] Evento customerUpserted.
	Future<void> _aplicarClienteRemoto(SyncEvent evento) async {
		final payload = evento.payload;
		final clienteId = payload['id'] as String? ?? '';
		if (clienteId.isEmpty) {
			return;
		}
		final cliente = Cliente(
			id: clienteId,
			nombre: payload['nombre'] as String? ?? '',
			listaPreciosId: payload['listaPreciosId'] as String?,
			creditoHabilitado: payload['creditoHabilitado'] as bool? ?? false,
			activo: payload['activo'] as bool? ?? true,
			telefono: payload['telefono'] as String? ?? '',
			email: payload['email'] as String? ?? '',
			rfc: payload['rfc'] as String? ?? '',
			direccion: payload['direccion'] as String? ?? '',
			notas: payload['notas'] as String? ?? '',
		);
		await _clienteRepository.guardar(cliente);
	}

	/// Aplica ajuste manual de stock proveniente de otra caja.
	///
	/// [evento] Evento stockAdjusted con delta.
	Future<void> _aplicarAjusteStockRemoto(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final productoId = evento.payload['productoId'] as String? ?? '';
		final delta = (evento.payload['delta'] as num?)?.toDouble() ?? 0.0;
		if (productoId.isEmpty || delta == 0.0) {
			return;
		}
		final almacenId = evento.payload['almacenId'] as String? ?? '';
		if (almacenId.isNotEmpty) {
			await _ajustarStockAlmacen(
				productoId,
				almacenId,
				delta,
				ejecutor: ejecutor,
			);
			return;
		}
		await _ajustarStock(
			productoId,
			evento.tiendaId,
			delta,
			ejecutor: ejecutor,
		);
	}

	Future<void> _ajustarStock(
		String productoId,
		String tiendaId,
		double delta, {
		DatabaseExecutor? ejecutor,
	}) async {
		if (tiendaId.isEmpty) {
			return;
		}
		final actual = await _inventarioRepository.obtenerStock(
			productoId,
			tiendaId,
			db: ejecutor,
		);
		final cantidadBase = actual?.cantidad ?? 0.0;
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaId,
				cantidad: cantidadBase + delta,
				actualizadoEn: DateTime.now().toUtc(),
				stockMinimo: actual?.stockMinimo ?? 0.0,
			),
			db: ejecutor,
		);
	}

	Future<void> _ajustarStockAlmacen(
		String productoId,
		String almacenId,
		double delta, {
		DatabaseExecutor? ejecutor,
	}) async {
		final repo = _almacenRepository;
		if (repo == null || almacenId.isEmpty) {
			return;
		}
		final actual = await repo.obtenerStock(productoId, almacenId, db: ejecutor);
		final cantidadBase = actual?.cantidad ?? 0.0;
		await repo.guardarStock(
			StockAlmacen(
				productoId: productoId,
				almacenId: almacenId,
				cantidad: cantidadBase + delta,
				actualizadoEn: DateTime.now().toUtc(),
				stockMinimo: actual?.stockMinimo ?? 0.0,
			),
			db: ejecutor,
		);
	}

	/// Reconstruye linea de venta desde payload remoto.
	///
	/// [cruda] Mapa de la linea en JSON.
	/// Retorna [LineaVenta] de dominio.
	LineaVenta _mapearLineaRemota(Map<String, Object?> cruda) {
		final reglaNombre = cruda['reglaPrecio'] as String? ?? ReglaPrecio.precioBase.name;
		return LineaVenta(
			productoId: cruda['productoId'] as String? ?? '',
			nombreProducto: cruda['nombreProducto'] as String? ?? '',
			cantidad: (cruda['cantidad'] as num?)?.toDouble() ?? 0.0,
			precioUnitario: (cruda['precioUnitario'] as num?)?.toDouble() ?? 0.0,
			reglaPrecio: ReglaPrecio.values.firstWhere(
				(valor) => valor.name == reglaNombre,
				orElse: () => ReglaPrecio.precioBase,
			),
			loteId: cruda['loteId'] as String?,
			etiquetaLote: cruda['etiquetaLote'] as String?,
		);
	}
}
