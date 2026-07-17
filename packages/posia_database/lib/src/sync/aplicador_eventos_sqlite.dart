/// Aplicador de eventos remotos sobre la base SQLite local.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:40:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:sqflite/sqflite.dart';

import '../repositories/almacen_repository.dart';
import '../repositories/asistencia_repository.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/cotizacion_repository.dart';
import '../repositories/pedido_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/presentacion_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/compra_repository.dart';
import '../repositories/descuento_cliente_repository.dart';
import '../repositories/empleado_perfil_repository.dart';
import '../repositories/nomina_repository.dart';
import '../repositories/rol_personalizado_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_promocion_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/turno_caja_repository.dart';
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
		TurnoCajaRepository? turnoCajaRepository,
		CotizacionRepository? cotizacionRepository,
		PedidoRepository? pedidoRepository,
		PrecioRepository? precioRepository,
		PresentacionRepository? presentacionRepository,
		ProveedorRepository? proveedorRepository,
		CompraRepository? compraRepository,
		RolPersonalizadoRepository? rolPersonalizadoRepository,
		AsistenciaRepository? asistenciaRepository,
		EmpleadoPerfilRepository? empleadoPerfilRepository,
		NominaRepository? nominaRepository,
		DescuentoClienteRepository? descuentoClienteRepository,
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
	     _almacenRepository = almacenRepository,
	     _turnoCajaRepository = turnoCajaRepository,
	     _cotizacionRepository = cotizacionRepository,
	     _pedidoRepository = pedidoRepository,
	     _precioRepository = precioRepository,
	     _presentacionRepository = presentacionRepository,
	     _proveedorRepository = proveedorRepository,
	     _compraRepository = compraRepository,
	     _rolPersonalizadoRepository = rolPersonalizadoRepository,
	     _asistenciaRepository = asistenciaRepository,
	     _empleadoPerfilRepository = empleadoPerfilRepository,
	     _nominaRepository = nominaRepository,
	     _descuentoClienteRepository = descuentoClienteRepository;

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
	final TurnoCajaRepository? _turnoCajaRepository;
	final CotizacionRepository? _cotizacionRepository;
	final PedidoRepository? _pedidoRepository;
	final PrecioRepository? _precioRepository;
	final PresentacionRepository? _presentacionRepository;
	final ProveedorRepository? _proveedorRepository;
	final CompraRepository? _compraRepository;
	final RolPersonalizadoRepository? _rolPersonalizadoRepository;
	final AsistenciaRepository? _asistenciaRepository;
	final EmpleadoPerfilRepository? _empleadoPerfilRepository;
	final NominaRepository? _nominaRepository;
	final DescuentoClienteRepository? _descuentoClienteRepository;

	/// Eventos cuya aplicacion no es idempotente por si sola (mutan stock con
	/// deltas o escriben varias filas). Se aplican en transaccion + dedupe para
	/// garantizar integridad y efecto "exactamente una vez" ante reintentos.
	static const Set<TipoSyncEvento> _tiposTransaccionales = {
		TipoSyncEvento.saleCompleted,
		TipoSyncEvento.saleVoided,
		TipoSyncEvento.stockAdjusted,
		TipoSyncEvento.transferRequested,
		TipoSyncEvento.transferCompleted,
		TipoSyncEvento.salePartialReturn,
		TipoSyncEvento.purchaseCompleted,
	};

	@override
	Future<void> aplicarLote(List<SyncEvent> eventos) async {
		if (eventos.isEmpty) {
			return;
		}
		for (final evento in eventos) {
			await _aplicarConGarantias(evento);
		}
	}

	@override
	Future<void> aplicarEvento(SyncEvent evento) async {
		await _aplicarConGarantias(evento);
	}

	/// Aplica un evento garantizando atomicidad e idempotencia cuando importa.
	///
	/// - Eventos con deltas/multiescritura: transaccion unica que aplica los
	///   cambios y registra el id como aplicado (dedupe) de forma atomica; si el
	///   pull reintenta la misma pagina, el evento se omite y no hay doble efecto.
	/// - Upserts de fila unica: se aplican directo (ya son atomicos e
	///   idempotentes via ConflictAlgorithm.replace).
	Future<void> _aplicarConGarantias(SyncEvent evento) async {
		if (!_tiposTransaccionales.contains(evento.tipo)) {
			await _aplicarEventoInterno(evento);
			return;
		}
		await _baseDatos.transaction((txn) async {
			if (evento.id.isNotEmpty && await _yaAplicado(txn, evento.id)) {
				return;
			}
			await _aplicarEventoInterno(evento, ejecutor: txn);
			await _marcarAplicado(txn, evento.id);
		});
	}

	Future<bool> _yaAplicado(DatabaseExecutor exec, String eventoId) async {
		final filas = await exec.query(
			'sync_eventos_aplicados',
			columns: const ['evento_id'],
			where: 'evento_id = ?',
			whereArgs: [eventoId],
			limit: 1,
		);
		return filas.isNotEmpty;
	}

	Future<void> _marcarAplicado(DatabaseExecutor exec, String eventoId) async {
		if (eventoId.isEmpty) {
			return;
		}
		await exec.insert(
			'sync_eventos_aplicados',
			{
				'evento_id': eventoId,
				'aplicado_en': DateTime.now().toUtc().toIso8601String(),
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
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
				await _aplicarDevolucionParcialRemota(evento, ejecutor: ejecutor);
			case TipoSyncEvento.storeUpserted:
				await _aplicarTiendaRemota(evento);
			case TipoSyncEvento.userUpserted:
				await _aplicarUsuarioRemoto(evento);
			case TipoSyncEvento.customRoleUpserted:
				await _aplicarRolPersonalizadoRemoto(evento);
			case TipoSyncEvento.cashShiftUpserted:
				await _aplicarTurnoRemoto(evento);
			case TipoSyncEvento.quoteUpserted:
				await _aplicarCotizacionRemota(evento);
			case TipoSyncEvento.quoteDeleted:
				await _aplicarCotizacionEliminadaRemota(evento);
			case TipoSyncEvento.orderUpserted:
				await _aplicarPedidoRemoto(evento);
			case TipoSyncEvento.wholesaleTiersReplaced:
				await _aplicarEscalasMayoreoRemotas(evento);
			case TipoSyncEvento.lotePromocionReplaced:
				await _aplicarLotePromocionRemoto(evento);
			case TipoSyncEvento.priceListUpserted:
				await _aplicarListaPreciosRemota(evento);
			case TipoSyncEvento.priceListDeleted:
				await _aplicarListaPreciosEliminadaRemota(evento);
			case TipoSyncEvento.priceListItemUpserted:
				await _aplicarItemListaPreciosRemoto(evento);
			case TipoSyncEvento.priceListItemDeleted:
				await _aplicarItemListaPreciosEliminadoRemoto(evento);
			case TipoSyncEvento.customerProductPriceUpserted:
				await _aplicarPrecioClienteProductoRemoto(evento);
			case TipoSyncEvento.customerProductPriceDeleted:
				await _aplicarPrecioClienteProductoEliminadoRemoto(evento);
			case TipoSyncEvento.customerDiscountUpserted:
				await _aplicarDescuentoClienteRemoto(evento);
			case TipoSyncEvento.customerDiscountDeleted:
				await _aplicarDescuentoClienteEliminadoRemoto(evento);
			case TipoSyncEvento.supplierUpserted:
				await _aplicarProveedorRemoto(evento);
			case TipoSyncEvento.supplierDeleted:
				await _aplicarProveedorEliminadoRemoto(evento);
			case TipoSyncEvento.purchaseCompleted:
				await _aplicarCompraRemota(evento, ejecutor: ejecutor);
			case TipoSyncEvento.productPresentationsReplaced:
				await _aplicarPresentacionesRemotas(evento);
			case TipoSyncEvento.attendanceChallengeCreated:
				await _aplicarDesafioAsistenciaRemoto(evento);
			case TipoSyncEvento.attendanceCheckedIn:
				await _aplicarEntradaAsistenciaRemota(evento);
			case TipoSyncEvento.attendanceCheckedOut:
				await _aplicarSalidaAsistenciaRemota(evento);
			case TipoSyncEvento.warehouseUpserted:
				await _aplicarAlmacenRemoto(evento);
			case TipoSyncEvento.employeeProfileUpserted:
				await _aplicarPerfilEmpleadoRemoto(evento);
			case TipoSyncEvento.payrollPeriodClosed:
				await _aplicarPeriodoNominaRemoto(evento);
			case TipoSyncEvento.presentationTypeUpserted:
				await _aplicarTipoPresentacionRemoto(evento);
			case TipoSyncEvento.productPresentationUpserted:
				// Legacy: reemplazado por productPresentationsReplaced.
				break;
		}
	}

	Future<void> _aplicarTipoPresentacionRemoto(SyncEvent evento) async {
		final repo = _presentacionRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardarTipo(
			TipoPresentacion(
				id: id,
				nombre: payload['nombre'] as String? ?? '',
				unidad: payload['unidad'] as String? ?? 'pieza',
				activo: payload['activo'] as bool? ?? true,
			),
		);
	}

	Future<void> _aplicarAlmacenRemoto(SyncEvent evento) async {
		final repo = _almacenRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardar(
			Almacen(
				id: id,
				nombre: payload['nombre'] as String? ?? '',
				tiendaId: payload['tiendaId'] as String?,
				activo: payload['activo'] as bool? ?? true,
				latitud: (payload['latitud'] as num?)?.toDouble(),
				longitud: (payload['longitud'] as num?)?.toDouble(),
				radioMetros: (payload['radioMetros'] as num?)?.toDouble() ?? 150,
			),
		);
	}

	Future<void> _aplicarPerfilEmpleadoRemoto(SyncEvent evento) async {
		final repo = _empleadoPerfilRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final usuarioId = payload['usuarioId'] as String? ?? '';
		if (usuarioId.isEmpty) {
			return;
		}
		await repo.guardar(
			EmpleadoPerfil(
				usuarioId: usuarioId,
				tarifaHora: (payload['tarifaHora'] as num?)?.toDouble() ?? 0.0,
				tipoPago: payload['tipoPago'] as String? ?? 'por_hora',
				actualizadoEn: DateTime.parse(
					payload['actualizadoEn'] as String? ??
						evento.creadoEn.toIso8601String(),
				),
			),
		);
	}

	Future<void> _aplicarPeriodoNominaRemoto(SyncEvent evento) async {
		final repo = _nominaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final periodoId = payload['periodoId'] as String? ?? '';
		if (periodoId.isEmpty) {
			return;
		}
		final cerradoCrudo = payload['cerradoEn'] as String?;
		await repo.guardarPeriodo(
			PeriodoNomina(
				id: periodoId,
				tiendaId: payload['tiendaId'] as String? ?? evento.tiendaId,
				inicioEn: DateTime.parse(
					payload['inicioEn'] as String? ?? evento.creadoEn.toIso8601String(),
				),
				finEn: DateTime.parse(
					payload['finEn'] as String? ?? evento.creadoEn.toIso8601String(),
				),
				estado: payload['estado'] as String? ?? 'cerrado',
				cerradoEn: cerradoCrudo == null ? null : DateTime.parse(cerradoCrudo),
				cerradoPor: payload['cerradoPor'] as String?,
			),
		);
		final lineasCrudas = payload['lineas'];
		if (lineasCrudas is! List) {
			return;
		}
		for (final cruda in lineasCrudas) {
			if (cruda is! Map) {
				continue;
			}
			final linea = Map<String, Object?>.from(cruda);
			final lineaId = linea['id'] as String? ?? '';
			if (lineaId.isEmpty) {
				continue;
			}
			await repo.guardarLinea(
				LineaNomina(
					id: lineaId,
					periodoId: periodoId,
					usuarioId: linea['usuarioId'] as String? ?? '',
					horasTrabajadas: (linea['horasTrabajadas'] as num?)?.toDouble() ?? 0.0,
					tarifaHora: (linea['tarifaHora'] as num?)?.toDouble() ?? 0.0,
					montoBruto: (linea['montoBruto'] as num?)?.toDouble() ?? 0.0,
					montoNeto: (linea['montoNeto'] as num?)?.toDouble() ?? 0.0,
				),
			);
		}
	}

	Future<void> _aplicarTurnoRemoto(SyncEvent evento) async {
		final repo = _turnoCajaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final cerradoCrudo = payload['cerradoEn'] as String?;
		final turno = TurnoCaja(
			id: id,
			tiendaId: payload['tiendaId'] as String? ?? evento.tiendaId,
			cajaId: payload['cajaId'] as String? ?? '',
			vendedorId: payload['vendedorId'] as String?,
			fondoInicial: (payload['fondoInicial'] as num?)?.toDouble() ?? 0.0,
			totalEfectivo: (payload['totalEfectivo'] as num?)?.toDouble() ?? 0.0,
			totalTarjeta: (payload['totalTarjeta'] as num?)?.toDouble() ?? 0.0,
			totalTransferencia:
				(payload['totalTransferencia'] as num?)?.toDouble() ?? 0.0,
			totalVentas: (payload['totalVentas'] as num?)?.toDouble() ?? 0.0,
			cantidadVentas: payload['cantidadVentas'] as int? ?? 0,
			abiertoEn: DateTime.parse(
				payload['abiertoEn'] as String? ?? evento.creadoEn.toIso8601String(),
			),
			cerradoEn: cerradoCrudo == null ? null : DateTime.parse(cerradoCrudo),
			estado: EstadoTurnoCaja.values.byName(
				payload['estado'] as String? ?? EstadoTurnoCaja.abierto.name,
			),
		);
		await repo.guardar(turno);
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
		await repo.fusionarRemota(
			Tienda(
				id: id,
				nombre: payload['nombre'] as String? ?? '',
				direccion: payload['direccion'] as String? ?? '',
				activa: payload['activa'] as bool? ?? true,
				latitud: (payload['latitud'] as num?)?.toDouble(),
				longitud: (payload['longitud'] as num?)?.toDouble(),
				radioMetrosAsistencia: _radioMetrosDesdePayload(payload),
			),
		);
	}

	double _radioMetrosDesdePayload(Map<String, Object?> payload) {
		final canonico = payload['radioMetros'];
		if (canonico is num) {
			return canonico.toDouble();
		}
		final legacy = payload['radioMetrosAsistencia'];
		if (legacy is num) {
			return legacy.toDouble();
		}
		return 150;
	}

	Future<void> _aplicarUsuarioRemoto(SyncEvent evento) async {
		final repo = _usuarioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		// Nulo (no ausente-y-descartado): el perfil se aplica igual para que el
		// equipo se vea íntegro en todos los dispositivos; guardarRemoto
		// preserva la credencial local existente o deja vacía si es nuevo aquí.
		final pinCredencial = extraerPinCredencialSync(payload);
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
			rolPersonalizadoId: payload['rolPersonalizadoId'] as String?,
			activo: payload['activo'] as bool? ?? true,
			pinCredencial: pinCredencial,
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

	Future<void> _aplicarDevolucionParcialRemota(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final venta = await _ventaRepository.obtenerPorId(ventaId, db: ejecutor);
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
					await _ajustarStock(
						linea.productoId,
						evento.tiendaId,
						devuelta,
						ejecutor: ejecutor,
					);
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
			db: ejecutor,
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
		final venta = await _ventaRepository.obtenerPorId(ventaId, db: ejecutor);
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
		await _ventaRepository.actualizarEstado(
			ventaId,
			EstadoVenta.cancelada,
			db: ejecutor,
		);
	}

	Future<void> _aplicarCategoriaRemota(SyncEvent evento) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		var activa = payload['activa'] as bool? ?? true;
		final nombre = payload['nombre'] as String? ?? '';
		if (activa) {
			// Auto-sanado de duplicados históricos (mismo nombre, distinto id,
			// generados antes de que el alta fuera idempotente por nombre): la
			// categoría ya existente y activa gana localmente; esta se guarda
			// inactiva para no ofrecerla dos veces en la UI, sin romper
			// productos que ya referencian este id.
			final existentes = await repo.listarTodas();
			final clave = normalizarTextoBusqueda(nombre);
			final yaHayOtraActiva = existentes.any(
				(c) => c.id != id && c.activa && normalizarTextoBusqueda(c.nombre) == clave,
			);
			if (yaHayOtraActiva) {
				activa = false;
			}
		}
		final categoria = Categoria(
			id: id,
			nombre: nombre,
			icono: payload['icono'] as String? ?? 'shopping_basket',
			colorHex: payload['colorHex'] as String? ?? '#4CAF50',
			orden: (payload['orden'] as num?)?.toInt() ?? 0,
			activa: activa,
		);
		await repo.guardar(categoria);
	}

	Future<void> _aplicarRolPersonalizadoRemoto(SyncEvent evento) async {
		final repo = _rolPersonalizadoRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final permisos = payload['permisosAdmin'];
		final categorias = payload['categoriasPermitidas'];
		await repo.guardar(
			RolPersonalizado(
				id: id,
				nombre: payload['nombre'] as String? ?? '',
				descripcion: payload['descripcion'] as String? ?? '',
				permisosAdmin: permisos is List
					? permisos.map((e) => e.toString()).toList()
					: [],
				categoriasPermitidas: categorias is List
					? categorias.map((e) => e.toString()).toList()
					: [],
				activo: payload['activo'] as bool? ?? true,
				tiendaId: payload['tiendaId'] as String?,
			),
		);
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
		final payload = evento.payload;
		final lineasCrudas = payload['lineas'] as List<Object?>? ?? [];
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
		final tiendaOrigenCruda = payload['tiendaOrigenId'] as String? ?? '';
		final tiendaDestinoCruda = payload['tiendaDestinoId'] as String? ?? '';
		final almacenOrigen = payload['almacenOrigenId'] as String? ?? '';
		final almacenDestino = payload['almacenDestinoId'] as String? ?? '';
		final tiendaOrigenId = tiendaOrigenCruda.isNotEmpty
			? tiendaOrigenCruda
			: (almacenOrigen.isNotEmpty
				? codificarAlmacenEnTraspaso(almacenOrigen)
				: '');
		final tiendaDestinoId = tiendaDestinoCruda.isNotEmpty
			? tiendaDestinoCruda
			: (almacenDestino.isNotEmpty
				? codificarAlmacenEnTraspaso(almacenDestino)
				: '');
		return Traspaso(
			id: payload['traspasoId'] as String? ?? evento.id,
			tiendaOrigenId: tiendaOrigenId,
			tiendaDestinoId: tiendaDestinoId,
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
		final exec = ejecutor ?? _baseDatos;
		final existentes = await exec.query(
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
		await _ventaRepository.guardar(venta, db: ejecutor);
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
		final tiendaId = payload['tiendaId'] as String? ?? evento.tiendaId;
		await _asegurarTiendaPadre(tiendaId);
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
			tiendaId: tiendaId,
			moduloVertical: ModuloVertical.values.firstWhere(
				(valor) => valor.name == verticalNombre,
				orElse: () => ModuloVertical.general,
			),
			categoriaId: payload['categoriaId'] as String?,
			piezasPorCaja: (payload['piezasPorCaja'] as num?)?.toInt(),
			unidadesPorBulto: (payload['unidadesPorBulto'] as num?)?.toInt(),
			proveedorId: payload['proveedorId'] as String?,
			notas: payload['notas'] as String? ?? '',
			costoUnitario: (payload['costoUnitario'] as num?)?.toDouble() ?? 0.0,
			favoritoCaja: payload['favoritoCaja'] as bool? ?? false,
			permiteStockNegativo: payload['permiteStockNegativo'] as bool? ?? true,
		);
		await _productoRepository.guardar(producto);
	}

	/// Garantiza que exista la tienda padre antes de insertar productos (FK v33).
	Future<void> _asegurarTiendaPadre(String tiendaId) async {
		final repo = _tiendaRepository;
		if (repo == null || tiendaId.trim().isEmpty) {
			return;
		}
		final existente = await repo.obtenerPorId(tiendaId);
		if (existente != null) {
			return;
		}
		await repo.guardar(
			Tienda(
				id: tiendaId,
				nombre: 'Tienda',
				direccion: '',
				activa: true,
			),
		);
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
			diasCredito: (payload['diasCredito'] as num?)?.toInt() ??
				DIAS_CREDITO_PREDETERMINADO,
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

	Future<void> _aplicarCotizacionRemota(SyncEvent evento) async {
		final repo = _cotizacionRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final lineasCrudas = payload['lineas'] as List<Object?>? ?? [];
		final lineas = lineasCrudas
			.whereType<Map<Object?, Object?>>()
			.map((cruda) {
				final mapa = Map<String, Object?>.from(cruda);
				final reglaNombre =
					mapa['reglaPrecio'] as String? ?? ReglaPrecio.precioBase.name;
				return LineaCotizacion(
					productoId: mapa['productoId'] as String? ?? '',
					nombreProducto: mapa['nombreProducto'] as String? ?? '',
					cantidad: (mapa['cantidad'] as num?)?.toDouble() ?? 0.0,
					precioUnitario: (mapa['precioUnitario'] as num?)?.toDouble() ?? 0.0,
					reglaPrecio: ReglaPrecio.values.firstWhere(
						(valor) => valor.name == reglaNombre,
						orElse: () => ReglaPrecio.precioBase,
					),
				);
			})
			.toList();
		await repo.guardar(
			Cotizacion(
				id: id,
				tiendaId: payload['tiendaId'] as String? ?? evento.tiendaId,
				nombre: payload['nombre'] as String? ?? '',
				clienteId: payload['clienteId'] as String?,
				nombreCliente: payload['nombreCliente'] as String?,
				total: (payload['total'] as num?)?.toDouble() ?? 0.0,
				notas: payload['notas'] as String? ?? '',
				vigenciaDias: (payload['vigenciaDias'] as num?)?.toInt() ??
					VIGENCIA_COTIZACION_DIAS,
				creadaEn: DateTime.parse(
					payload['creadaEn'] as String? ?? evento.creadoEn.toIso8601String(),
				),
				cajaId: payload['cajaId'] as String?,
				vendedorId: payload['vendedorId'] as String?,
				lineas: lineas,
			),
		);
	}

	Future<void> _aplicarCotizacionEliminadaRemota(SyncEvent evento) async {
		final repo = _cotizacionRepository;
		if (repo == null) {
			return;
		}
		final id = evento.payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.eliminar(id);
	}

	Future<void> _aplicarPedidoRemoto(SyncEvent evento) async {
		final repo = _pedidoRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final metodoNombre = payload['metodoPago'] as String? ?? MetodoPago.efectivo.name;
		final estadoNombre = payload['estado'] as String? ?? EstadoPedido.recibido.name;
		final lineasCrudas = payload['lineas'] as List<Object?>? ?? [];
		final lineas = lineasCrudas
			.whereType<Map<Object?, Object?>>()
			.map((cruda) {
				final mapa = Map<String, Object?>.from(cruda);
				return LineaPedido(
					productoId: mapa['productoId'] as String? ?? '',
					nombreProducto: mapa['nombreProducto'] as String? ?? '',
					cantidad: (mapa['cantidad'] as num?)?.toDouble() ?? 0.0,
					precioUnitario: (mapa['precioUnitario'] as num?)?.toDouble() ?? 0.0,
				);
			})
			.toList();
		final asignadoEnCrudo = payload['asignadoEn'] as String?;
		final creditoVenceCrudo = payload['creditoVenceEn'] as String?;
		await repo.guardar(
			Pedido(
				id: id,
				tiendaId: payload['tiendaId'] as String? ?? evento.tiendaId,
				clienteId: payload['clienteId'] as String?,
				nombreEntrega: payload['nombreEntrega'] as String? ?? '',
				telefonoEntrega: payload['telefonoEntrega'] as String? ?? '',
				direccionEntrega: payload['direccionEntrega'] as String? ?? '',
				esCredito: payload['esCredito'] as bool? ?? false,
				creditoDias: (payload['creditoDias'] as num?)?.toInt(),
				creditoVenceEn: creditoVenceCrudo == null
					? null
					: DateTime.parse(creditoVenceCrudo),
				metodoPago: MetodoPago.values.firstWhere(
					(valor) => valor.name == metodoNombre,
					orElse: () => MetodoPago.efectivo,
				),
				total: (payload['total'] as num?)?.toDouble() ?? 0.0,
				notas: payload['notas'] as String? ?? '',
				estado: EstadoPedido.values.firstWhere(
					(valor) => valor.name == estadoNombre,
					orElse: () => EstadoPedido.recibido,
				),
				asignadoAUsuarioId: payload['asignadoAUsuarioId'] as String?,
				asignadoAUsuarioNombre: payload['asignadoAUsuarioNombre'] as String?,
				asignadoEn: asignadoEnCrudo == null ? null : DateTime.parse(asignadoEnCrudo),
				creadoEn: DateTime.parse(
					payload['creadoEn'] as String? ?? evento.creadoEn.toIso8601String(),
				),
				creadoPorUsuarioId: payload['creadoPorUsuarioId'] as String?,
				ventaId: payload['ventaId'] as String?,
				lineas: lineas,
			),
		);
	}

	Future<void> _aplicarEscalasMayoreoRemotas(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final productoId = evento.payload['productoId'] as String? ?? '';
		if (productoId.isEmpty) {
			return;
		}
		final escalasCrudas = evento.payload['escalas'] as List<Object?>? ?? [];
		final escalas = escalasCrudas
			.whereType<Map<Object?, Object?>>()
			.map((cruda) {
				final mapa = Map<String, Object?>.from(cruda);
				return EscalaMayoreo(
					productoId: productoId,
					cantidadMinima: (mapa['cantidadMinima'] as num?)?.toDouble() ?? 0.0,
					precioUnitario: (mapa['precioUnitario'] as num?)?.toDouble() ?? 0.0,
				);
			})
			.toList();
		await repo.reemplazarEscalasMayoreo(productoId, escalas);
	}

	Future<void> _aplicarLotePromocionRemoto(SyncEvent evento) async {
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final productoIdsCrudos = p['productoIds'] as List<Object?>? ?? [];
		final productoIds = productoIdsCrudos
			.whereType<String>()
			.where((idProducto) => idProducto.isNotEmpty)
			.toList();
		final lote = LotePromocion(
			id: id,
			codigoExterno: p['codigoExterno'] as String? ?? '',
			nombre: p['nombre'] as String? ?? '',
			cantidadMinima: (p['cantidadMinima'] as num?)?.toDouble() ?? 0.0,
			precioUnitario: (p['precioUnitario'] as num?)?.toDouble() ?? 0.0,
			activo: p['activo'] as bool? ?? true,
			productoIds: productoIds,
		);
		await LotePromocionRepository(baseDatos: _baseDatos).reemplazarLote(lote);
	}

	Future<void> _aplicarProveedorRemoto(SyncEvent evento) async {
		final repo = _proveedorRepository;
		if (repo == null) {
			return;
		}
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardar(
			Proveedor(
				id: id,
				nombre: p['nombre'] as String? ?? '',
				contacto: p['contacto'] as String? ?? '',
				telefono: p['telefono'] as String? ?? '',
				activo: p['activo'] as bool? ?? true,
				email: p['email'] as String? ?? '',
				rfc: p['rfc'] as String? ?? '',
				direccion: p['direccion'] as String? ?? '',
				notas: p['notas'] as String? ?? '',
				diasCredito: (p['diasCredito'] as num?)?.toInt() ?? 0,
			),
		);
	}

	Future<void> _aplicarProveedorEliminadoRemoto(SyncEvent evento) async {
		final repo = _proveedorRepository;
		if (repo == null) {
			return;
		}
		final id = evento.payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.eliminar(id);
	}

	Future<void> _aplicarCompraRemota(
		SyncEvent evento, {
		DatabaseExecutor? ejecutor,
	}) async {
		final repo = _compraRepository;
		if (repo == null) {
			return;
		}
		final p = evento.payload;
		final id = p['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final existente = await repo.obtenerPorId(id);
		final lineasCrudas = p['lineas'] as List<Object?>? ?? [];
		final lineas = lineasCrudas
			.whereType<Map<Object?, Object?>>()
			.map((cruda) {
				final mapa = Map<String, Object?>.from(cruda);
				return LineaCompra(
					productoId: mapa['productoId'] as String? ?? '',
					nombreProducto: mapa['nombreProducto'] as String? ?? '',
					cantidad: (mapa['cantidad'] as num?)?.toDouble() ?? 0.0,
					costoUnitario: (mapa['costoUnitario'] as num?)?.toDouble() ?? 0.0,
					subtotal: (mapa['subtotal'] as num?)?.toDouble() ?? 0.0,
				);
			})
			.toList();
		final asignacionesCrudas = p['asignaciones'] as List<Object?>? ?? [];
		final asignaciones = <AsignacionCompra>[];
		var seq = 0;
		for (final cruda in asignacionesCrudas.whereType<Map<Object?, Object?>>()) {
			seq++;
			final mapa = Map<String, Object?>.from(cruda);
			final tipoRaw = mapa['destinoTipo'] as String? ?? 'almacen';
			final tipo = TipoDestinoCompra.values.firstWhere(
				(t) => t.name == tipoRaw,
				orElse: () => TipoDestinoCompra.almacen,
			);
			asignaciones.add(
				AsignacionCompra(
					id: mapa['id'] as String? ?? '$id-alloc-$seq',
					productoId: mapa['productoId'] as String? ?? '',
					destinoTipo: tipo,
					destinoId: mapa['destinoId'] as String? ?? '',
					cantidad: (mapa['cantidad'] as num?)?.toDouble() ?? 0.0,
				),
			);
		}
		final tiendaRaw = p['tiendaId'] as String?;
		final tiendaId = (tiendaRaw != null && tiendaRaw.trim().isNotEmpty)
			? tiendaRaw
			: null;
		final compra = Compra(
			id: id,
			tiendaId: tiendaId,
			proveedorId: p['proveedorId'] as String? ?? '',
			fechaCompra: DateTime.parse(
				p['fechaCompra'] as String? ?? evento.creadoEn.toIso8601String(),
			),
			notas: p['notas'] as String? ?? '',
			total: (p['total'] as num?)?.toDouble() ?? 0.0,
			creadaEn: DateTime.parse(
				p['creadaEn'] as String? ?? evento.creadoEn.toIso8601String(),
			),
			creadoPor: p['creadoPor'] as String?,
			lineas: lineas,
			asignaciones: asignaciones,
		);
		await repo.guardar(compra, db: ejecutor);
		if (existente != null) {
			return;
		}
		if (asignaciones.isNotEmpty) {
			for (final asignacion in asignaciones) {
				if (asignacion.destinoTipo == TipoDestinoCompra.tienda) {
					await _ajustarStock(
						asignacion.productoId,
						asignacion.destinoId,
						asignacion.cantidad,
						ejecutor: ejecutor,
					);
				} else {
					await _ajustarStockAlmacen(
						asignacion.productoId,
						asignacion.destinoId,
						asignacion.cantidad,
						ejecutor: ejecutor,
					);
				}
			}
			return;
		}
		// Legacy sin asignaciones: stock a tienda del evento.
		final destinoLegacy = tiendaId ?? evento.tiendaId;
		for (final linea in lineas) {
			await _ajustarStock(
				linea.productoId,
				destinoLegacy,
				linea.cantidad,
				ejecutor: ejecutor,
			);
		}
	}

	Future<void> _aplicarListaPreciosRemota(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardarLista(
			ListaPrecios(
				id: id,
				nombre: payload['nombre'] as String? ?? '',
				activa: payload['activa'] as bool? ?? true,
			),
		);
	}

	Future<void> _aplicarListaPreciosEliminadaRemota(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final id = evento.payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.eliminarLista(id);
	}

	Future<void> _aplicarItemListaPreciosRemoto(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final listaId = payload['listaPreciosId'] as String? ?? '';
		final productoId = payload['productoId'] as String? ?? '';
		if (listaId.isEmpty || productoId.isEmpty) {
			return;
		}
		await repo.guardarPrecioLista(
			listaId,
			productoId,
			(payload['precioUnitario'] as num?)?.toDouble() ?? 0.0,
		);
	}

	Future<void> _aplicarItemListaPreciosEliminadoRemoto(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final listaId = payload['listaPreciosId'] as String? ?? '';
		final productoId = payload['productoId'] as String? ?? '';
		if (listaId.isEmpty || productoId.isEmpty) {
			return;
		}
		await repo.eliminarPrecioDeLista(listaId, productoId);
	}

	Future<void> _aplicarPrecioClienteProductoRemoto(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final clienteId = payload['clienteId'] as String? ?? '';
		final productoId = payload['productoId'] as String? ?? '';
		if (clienteId.isEmpty || productoId.isEmpty) {
			return;
		}
		await repo.guardarPrecioClienteProducto(
			PrecioClienteProducto(
				clienteId: clienteId,
				productoId: productoId,
				precioUnitario: (payload['precioUnitario'] as num?)?.toDouble() ?? 0.0,
			),
		);
	}

	Future<void> _aplicarPrecioClienteProductoEliminadoRemoto(SyncEvent evento) async {
		final repo = _precioRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final clienteId = payload['clienteId'] as String? ?? '';
		final productoId = payload['productoId'] as String? ?? '';
		if (clienteId.isEmpty || productoId.isEmpty) {
			return;
		}
		await repo.eliminarPrecioClienteProducto(clienteId, productoId);
	}

	Future<void> _aplicarDescuentoClienteRemoto(SyncEvent evento) async {
		final repo = _descuentoClienteRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final tipoNombre = payload['tipo'] as String? ?? '';
		final condicionNombre = payload['condicion'] as String? ?? '';
		await repo.guardar(
			DescuentoCliente(
				id: id,
				clienteId: payload['clienteId'] as String? ?? '',
				tipo: TipoDescuentoCliente.values.firstWhere(
					(v) => v.name == tipoNombre,
					orElse: () => TipoDescuentoCliente.porcentajeGeneral,
				),
				valor: (payload['valor'] as num?)?.toDouble() ?? 0.0,
				productoId: payload['productoId'] as String?,
				condicion: CondicionDescuentoCliente.values.firstWhere(
					(v) => v.name == condicionNombre,
					orElse: () => CondicionDescuentoCliente.siempre,
				),
				umbral: (payload['umbral'] as num?)?.toDouble(),
				activo: payload['activo'] as bool? ?? true,
				descripcion: payload['descripcion'] as String? ?? '',
			),
		);
	}

	Future<void> _aplicarDescuentoClienteEliminadoRemoto(SyncEvent evento) async {
		final repo = _descuentoClienteRepository;
		if (repo == null) {
			return;
		}
		final id = evento.payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.eliminar(id);
	}

	Future<void> _aplicarPresentacionesRemotas(SyncEvent evento) async {
		final repo = _presentacionRepository;
		if (repo == null) {
			return;
		}
		final productoId = evento.payload['productoId'] as String? ?? '';
		if (productoId.isEmpty) {
			return;
		}
		final presentacionesCrudas =
			evento.payload['presentaciones'] as List<Object?>? ?? [];
		final presentaciones = presentacionesCrudas
			.whereType<Map<Object?, Object?>>()
			.map((cruda) {
				final mapa = Map<String, Object?>.from(cruda);
				return PresentacionProducto(
					id: mapa['id'] as String? ?? '',
					productoId: productoId,
					tipoPresentacionId: mapa['tipoPresentacionId'] as String?,
					nombre: mapa['nombre'] as String? ?? '',
					factorABase: (mapa['factorABase'] as num?)?.toDouble() ?? 1.0,
					esPresentacionBase: mapa['esPresentacionBase'] == true,
					codigoBarras: mapa['codigoBarras'] as String? ?? '',
					precio: (mapa['precio'] as num?)?.toDouble(),
					activo: mapa['activo'] != false,
				);
			})
			.where((p) => p.id.isNotEmpty)
			.toList();
		await repo.reemplazarPresentacionesProducto(productoId, presentaciones);
	}

	Future<void> _aplicarDesafioAsistenciaRemoto(SyncEvent evento) async {
		final repo = _asistenciaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		final tiendaId = payload['tiendaId'] as String? ?? evento.tiendaId;
		await _baseDatos.transaction((tx) async {
			await repo.desactivarDesafiosTienda(tiendaId, db: tx);
			await repo.guardarDesafio(
				DesafioAsistencia(
					id: id,
					tiendaId: tiendaId,
					pinHash: payload['pinHash'] as String? ?? '',
					expiraEn: DateTime.parse(
						payload['expiraEn'] as String? ?? evento.creadoEn.toIso8601String(),
					),
					creadoPor: evento.dispositivoId,
					latitud: (payload['latitud'] as num?)?.toDouble(),
					longitud: (payload['longitud'] as num?)?.toDouble(),
					radioMetros: (payload['radioMetros'] as num?)?.toDouble() ?? 150,
					activo: true,
				),
				db: tx,
			);
		});
	}

	Future<void> _aplicarEntradaAsistenciaRemota(SyncEvent evento) async {
		final repo = _asistenciaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final id = payload['id'] as String? ?? '';
		if (id.isEmpty) {
			return;
		}
		await repo.guardarRegistro(
			RegistroAsistencia(
				id: id,
				usuarioId: payload['usuarioId'] as String? ?? '',
				tiendaId: payload['tiendaId'] as String? ?? evento.tiendaId,
				entradaEn: DateTime.parse(
					payload['entradaEn'] as String? ?? evento.creadoEn.toIso8601String(),
				),
				metodo: payload['metodo'] as String? ?? '',
				latitud: (payload['latitud'] as num?)?.toDouble(),
				longitud: (payload['longitud'] as num?)?.toDouble(),
				desafioId: payload['desafioId'] as String?,
			),
		);
	}

	Future<void> _aplicarSalidaAsistenciaRemota(SyncEvent evento) async {
		final repo = _asistenciaRepository;
		if (repo == null) {
			return;
		}
		final payload = evento.payload;
		final registroId = payload['registroId'] as String? ?? '';
		if (registroId.isEmpty) {
			return;
		}
		final abierta = await repo.obtenerEntradaAbierta(
			payload['usuarioId'] as String? ?? '',
		);
		final base = abierta?.id == registroId
			? abierta!
			: RegistroAsistencia(
				id: registroId,
				usuarioId: payload['usuarioId'] as String? ?? '',
				tiendaId: evento.tiendaId,
				entradaEn: evento.creadoEn,
				metodo: '',
			);
		await repo.guardarRegistro(
			RegistroAsistencia(
				id: base.id,
				usuarioId: base.usuarioId,
				tiendaId: base.tiendaId,
				entradaEn: base.entradaEn,
				salidaEn: DateTime.parse(
					payload['salidaEn'] as String? ?? evento.creadoEn.toIso8601String(),
				),
				metodo: base.metodo,
				latitud: base.latitud,
				longitud: base.longitud,
				desafioId: base.desafioId,
			),
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

String? extraerPinCredencialSync(Map<String, Object?> payload) {
	final credencial = payload['pinCredencial'] as String?;
	if (credencial == null || credencial.isEmpty) {
		return null;
	}
	return credencial;
}
