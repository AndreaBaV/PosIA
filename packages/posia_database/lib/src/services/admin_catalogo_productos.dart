/// Dominio de catálogo: CRUD de productos, presentaciones asociadas a su
/// alta/edición, inventario consolidado/agrupado y validaciones de precio y
/// código de barras.
///
/// Extraído de `ServicioAdmin` (God Object original) para que el dominio de
/// producto tenga un único dueño reutilizable; `ServicioAdmin` delega aquí y
/// mantiene su API pública sin cambios para no romper pantallas/providers.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/alta_producto_request.dart';
import '../models/stock_por_tienda.dart';
import '../repositories/almacen_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/lote_promocion_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/presentacion_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/tienda_repository.dart';
import '../repositories/variante_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Catálogo de productos: alta, edición, baja e inventario consolidado.
class AdminCatalogoProductos {
	AdminCatalogoProductos({
		required ProductoRepository productoRepository,
		required InventarioRepository inventarioRepository,
		required TiendaRepository tiendaRepository,
		required LotePromocionRepository lotePromocionRepository,
		required AdminEmisorEventosSync emisorEventos,
		required Database baseDatos,
		required String tiendaActivaId,
		PrecioRepository? precioRepository,
		PresentacionRepository? presentacionRepository,
		VarianteRepository? varianteRepository,
		AlmacenRepository? almacenRepository,
	}) : _productoRepository = productoRepository,
	     _inventarioRepository = inventarioRepository,
	     _tiendaRepository = tiendaRepository,
	     _lotePromocionRepository = lotePromocionRepository,
	     _emisorEventos = emisorEventos,
	     _baseDatos = baseDatos,
	     _tiendaActivaId = tiendaActivaId,
	     _precioRepository = precioRepository,
	     _presentacionRepository = presentacionRepository,
	     _varianteRepository = varianteRepository,
	     _almacenRepository = almacenRepository;

	final ProductoRepository _productoRepository;
	final InventarioRepository _inventarioRepository;
	final TiendaRepository _tiendaRepository;
	final LotePromocionRepository _lotePromocionRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final Database _baseDatos;
	final String _tiendaActivaId;
	final PrecioRepository? _precioRepository;
	final PresentacionRepository? _presentacionRepository;
	final VarianteRepository? _varianteRepository;
	final AlmacenRepository? _almacenRepository;
	final Uuid _generadorId = const Uuid();

	Future<T> _enTransaccion<T>(Future<T> Function(Transaction tx) accion) {
		return _baseDatos.transaction(accion);
	}

	// --- Consultas ---

	/// Lista productos activos de la tienda local.
	Future<List<Producto>> listarProductos() {
		return _productoRepository.listarActivosPorTienda(_tiendaActivaId);
	}

	Future<List<Producto>> listarProductosActivosPorTienda(String tiendaId) {
		return _productoRepository.listarActivosPorTienda(tiendaId);
	}

	/// Lista catalogo completo incluyendo inactivos (admin).
	Future<List<Producto>> listarProductosCatalogo() {
		return _productoRepository.listarTodosPorTienda(_tiendaActivaId);
	}

	Future<Producto?> obtenerProducto(String productoId) {
		return _productoRepository.obtenerPorId(productoId);
	}

	Future<List<EscalaMayoreo>> listarEscalasMayoreo(String productoId) async {
		return _precioRepository?.obtenerEscalasMayoreo(productoId) ?? [];
	}

	Future<List<Producto>> listarProductosPorProveedor(String proveedorId) {
		return _productoRepository.listarPorProveedor(_tiendaActivaId, proveedorId);
	}

	/// Busca producto activo por codigo de barras en la tienda actual.
	Future<Producto?> buscarProductoPorCodigoBarras(String codigoBarras) {
		return _productoRepository.buscarPorCodigoBarras(
			codigoBarras,
			tiendaId: _tiendaActivaId,
		);
	}

	// --- Validaciones (reutilizadas también por variantes y precios de cliente) ---

	void validarPrecioVenta(double precioUnitario, double costoUnitario) {
		if (!precioVentaEsValido(precioUnitario, costoUnitario)) {
			throw StateError(mensajePrecioMinimoInvalido(costoUnitario));
		}
	}

	Future<void> validarCodigoBarrasUnico(
		String codigoBarras, {
		String? excluirProductoId,
	}) async {
		final codigo = codigoBarras.trim();
		if (codigo.isEmpty) {
			return;
		}
		final duplicado = await _productoRepository
			.existeCodigoBarrasActivoEnTienda(
				_tiendaActivaId,
				codigo,
				excluirProductoId: excluirProductoId,
			);
		if (duplicado) {
			final existente = await _productoRepository.buscarPorCodigoBarras(
				codigo,
				tiendaId: _tiendaActivaId,
			);
			final nombre = existente?.nombre ?? 'otro producto';
			throw StateError(
				'Ya existe un producto activo con el codigo de barras "$codigo" '
				'($nombre). Para cambiar el precio, edite ese producto o use '
				'"Actualizar precio" en el catalogo.',
			);
		}
	}

	ModuloVertical _derivarModuloVertical(
		String categoriaId,
		UnidadMedida unidad,
	) {
		if (categoriaId == ID_CAT_CARNICERIA) {
			return ModuloVertical.carniceria;
		}
		if (categoriaId == ID_CAT_FARMACIA) {
			return ModuloVertical.farmacia;
		}
		return ModuloVertical.general;
	}

	UnidadMedida _unidadPorCategoria(
		String categoriaId,
		UnidadMedida solicitada,
	) {
		if (categoriaId == ID_CAT_CARNICERIA && solicitada == UnidadMedida.pieza) {
			return UnidadMedida.kilogramo;
		}
		return solicitada;
	}

	// --- Alta / edición / baja ---

	/// Crea el producto, su stock inicial, escalas, presentaciones y precio de
	/// caja en una sola transacción, y emite los eventos de sync correspondientes.
	///
	/// No sincroniza presentaciones al hub (eso requiere `SyncEventRepository`,
	/// fuera de este dominio) — el llamador debe hacerlo si aplica.
	Future<Producto> registrarProductoCompleto(AltaProductoRequest req) async {
		if (req.categoriaId.isEmpty) {
			throw StateError('La categoria es obligatoria');
		}
		await validarCodigoBarrasUnico(req.codigoBarras);
		validarPrecioVenta(req.precioBase, req.costoUnitario);
		for (final escala in req.escalasMayoreo) {
			validarPrecioVenta(escala.precioUnitario, req.costoUnitario);
		}
		final unidad = _unidadPorCategoria(req.categoriaId, req.unidadMedida);
		final producto = Producto(
			id: _generadorId.v4(),
			nombre: req.nombre.trim(),
			codigoBarras: req.codigoBarras.trim(),
			precioBase: redondearMonto(req.precioBase),
			unidadMedida: unidad,
			rutaImagen: '',
			activo: req.activo,
			tiendaId: _tiendaActivaId,
			moduloVertical: _derivarModuloVertical(req.categoriaId, unidad),
			categoriaId: req.categoriaId,
			piezasPorCaja: req.piezasPorCaja,
			unidadesPorBulto: req.unidadesPorBulto,
			proveedorId: req.proveedorId,
			notas: req.notas.trim(),
			costoUnitario: redondearMonto(req.costoUnitario),
			permiteStockNegativo: req.permiteStockNegativo,
		);
		await _enTransaccion((tx) async {
			await _productoRepository.guardar(producto, db: tx);
			final ahora = DateTime.now().toUtc();
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: producto.id,
					tiendaId: _tiendaActivaId,
					cantidad: req.stockInicial,
					actualizadoEn: ahora,
					stockMinimo: req.stockMinimo,
				),
				db: tx,
			);
			if (req.escalasMayoreo.isNotEmpty && _precioRepository != null) {
				final escalas = req.escalasMayoreo
					.map(
						(e) => EscalaMayoreo(
							productoId: producto.id,
							cantidadMinima: e.cantidadMinima,
							precioUnitario: e.precioUnitario,
						),
					)
					.toList();
				await _precioRepository.reemplazarEscalasMayoreo(
					producto.id,
					escalas,
					db: tx,
				);
			}
			await asegurarPresentacionBase(producto, db: tx);
			await _aplicarPrecioYCodigoCaja(
				producto: producto,
				precioCaja: req.precioCaja,
				codigoCaja: req.codigoCaja,
				db: tx,
			);
			if (req.presentaciones.isNotEmpty) {
				await _aplicarPresentacionesImportacion(
					producto: producto,
					presentaciones: req.presentaciones,
					db: tx,
				);
			}
		});
		await _emisorEventos.producto(producto);
		if (req.escalasMayoreo.isNotEmpty) {
			await _emisorEventos.escalasMayoreo(
				producto.id,
				req.escalasMayoreo
					.map(
						(e) => EscalaMayoreo(
							productoId: producto.id,
							cantidadMinima: e.cantidadMinima,
							precioUnitario: e.precioUnitario,
						),
					)
					.toList(),
			);
		}
		return producto;
	}

	Future<void> _aplicarPresentacionesImportacion({
		required Producto producto,
		required List<PresentacionImportacionSolicitud> presentaciones,
		DatabaseExecutor? db,
	}) async {
		final repo = _presentacionRepository;
		if (repo == null || presentaciones.isEmpty) {
			return;
		}
		final lista = <PresentacionProducto>[
			for (final p in presentaciones)
				PresentacionProducto(
					id: _generadorId.v4(),
					productoId: producto.id,
					nombre: p.nombre,
					factorABase: p.factorABase,
					esPresentacionBase: p.esPresentacionBase,
					precio: redondearMonto(p.precio),
					activo: true,
				),
		];
		if (!lista.any((p) => p.esPresentacionBase)) {
			lista.insert(
				0,
				PresentacionProducto(
					id: _generadorId.v4(),
					productoId: producto.id,
					nombre: '1 kg',
					factorABase: 1,
					esPresentacionBase: true,
					precio: producto.precioBase,
					activo: true,
				),
			);
		}
		await repo.reemplazarPresentacionesProducto(producto.id, lista, db: db);
	}

	Future<void> _aplicarPrecioYCodigoCaja({
		required Producto producto,
		required double? precioCaja,
		required String codigoCaja,
		DatabaseExecutor? db,
	}) async {
		final repo = _presentacionRepository;
		if (repo == null) {
			return;
		}
		if ((precioCaja == null || precioCaja <= 0) && codigoCaja.trim().isEmpty) {
			return;
		}
		final piezas = producto.piezasPorCaja;
		if (piezas == null || piezas <= 1) {
			return;
		}
		final presentaciones = await repo.listarPorProducto(producto.id, db: db);
		final caja = presentaciones
			.where(
				(p) => !p.esPresentacionBase && p.tipoPresentacionId == 'tp-caja',
			)
			.firstOrNull;
		if (caja == null) {
			return;
		}
		await repo.guardarPresentacion(
			caja.copiarWith(
				precio: precioCaja != null && precioCaja > 0
					? redondearMonto(precioCaja)
					: caja.precio,
				codigoBarras: codigoCaja.trim().isNotEmpty
					? codigoCaja.trim()
					: caja.codigoBarras,
			),
			db: db,
		);
	}

	/// Garantiza que el producto tenga una presentación base (y de caja si
	/// aplica) antes de operar en caja. Idempotente.
	Future<void> asegurarPresentacionBase(
		Producto producto, {
		DatabaseExecutor? db,
	}) async {
		final repo = _presentacionRepository;
		if (repo == null) {
			return;
		}
		final existentes = await repo.listarPorProducto(producto.id, db: db);
		if (existentes.any((p) => p.esPresentacionBase)) {
			return;
		}
		await repo.guardarPresentacion(
			PresentacionProducto(
				id: _generadorId.v4(),
				productoId: producto.id,
				nombre: 'Unidad base',
				factorABase: 1,
				esPresentacionBase: true,
				precio: producto.precioBase,
				activo: true,
			),
			db: db,
		);
		if (producto.piezasPorCaja != null && producto.piezasPorCaja! > 1) {
			await repo.guardarPresentacion(
				PresentacionProducto(
					id: _generadorId.v4(),
					productoId: producto.id,
					tipoPresentacionId: 'tp-caja',
					nombre: 'Caja x${producto.piezasPorCaja}',
					factorABase: producto.piezasPorCaja!.toDouble(),
					esPresentacionBase: false,
					precio: producto.precioBase * producto.piezasPorCaja!,
					activo: true,
				),
				db: db,
			);
		}
	}

	Future<Producto> actualizarProducto(
		Producto producto, {
		List<EscalaMayoreo>? escalasMayoreo,
	}) async {
		if (producto.categoriaId == null || producto.categoriaId!.isEmpty) {
			throw StateError('La categoria es obligatoria');
		}
		await validarCodigoBarrasUnico(
			producto.codigoBarras,
			excluirProductoId: producto.id,
		);
		validarPrecioVenta(producto.precioBase, producto.costoUnitario);
		if (escalasMayoreo != null) {
			for (final escala in escalasMayoreo) {
				validarPrecioVenta(escala.precioUnitario, producto.costoUnitario);
			}
		}
		final unidad = _unidadPorCategoria(
			producto.categoriaId!,
			producto.unidadMedida,
		);
		final actualizado = producto.copiarCon(
			moduloVertical: _derivarModuloVertical(producto.categoriaId!, unidad),
			unidadMedida: unidad,
			precioBase: redondearMonto(producto.precioBase),
		);
		await _enTransaccion((tx) async {
			await _productoRepository.guardar(actualizado, db: tx);
			if (escalasMayoreo != null && _precioRepository != null) {
				await _precioRepository.reemplazarEscalasMayoreo(
					actualizado.id,
					escalasMayoreo
						.map(
							(e) => EscalaMayoreo(
								productoId: actualizado.id,
								cantidadMinima: e.cantidadMinima,
								precioUnitario: e.precioUnitario,
							),
						)
						.toList(),
					db: tx,
				);
			}
			await asegurarPresentacionBase(actualizado, db: tx);
			final repo = _presentacionRepository;
			if (repo != null) {
				final presentaciones = await repo.listarPorProducto(
					actualizado.id,
					db: tx,
				);
				final base = presentaciones
					.where((p) => p.esPresentacionBase && p.activo)
					.firstOrNull;
				if (base != null) {
					await repo.guardarPresentacion(
						base.copiarWith(precio: actualizado.precioBase),
						db: tx,
					);
				}
			}
		});
		await _emisorEventos.producto(actualizado);
		if (escalasMayoreo != null) {
			await _emisorEventos.escalasMayoreo(actualizado.id, escalasMayoreo);
		}
		return actualizado;
	}

	Future<bool> eliminarProducto(String productoId) async {
		if (await _productoTieneStock(productoId)) {
			return false;
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		await _productoRepository.guardar(producto.copiarCon(activo: false));
		await _emisorEventos.producto(producto.copiarCon(activo: false));
		return true;
	}

	Future<bool> reactivarProducto(String productoId) async {
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		final reactivado = producto.copiarCon(activo: true);
		await _productoRepository.guardar(reactivado);
		await _emisorEventos.producto(reactivado);
		return true;
	}

	Future<bool> eliminarProductoPermanente(String productoId) async {
		if (await _productoTieneStock(productoId)) {
			return false;
		}
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return false;
		}
		await _enTransaccion((tx) async {
			await _lotePromocionRepository.eliminarMiembroProducto(
				productoId,
				db: tx,
			);
			await _precioRepository?.eliminarEscalasPorProducto(productoId, db: tx);
			await _precioRepository?.eliminarPreciosPorProducto(productoId, db: tx);
			await _varianteRepository?.eliminarPorProductoPadre(productoId, db: tx);
			await _inventarioRepository.eliminarStockPorProducto(productoId, db: tx);
			await _productoRepository.eliminar(productoId, db: tx);
		});
		return true;
	}

	Future<bool> _productoTieneStock(String productoId) async {
		final tiendas = await _tiendaRepository.listarActivas();
		for (final tienda in tiendas) {
			final stock = await _inventarioRepository.obtenerStock(
				productoId,
				tienda.id,
			);
			if ((stock?.cantidad ?? 0.0) > 0.0) {
				return true;
			}
		}
		return false;
	}

	/// Registra producto nuevo en catalogo local (legacy simple).
	Future<Producto> registrarProducto({
		required String nombre,
		required String codigoBarras,
		required double precioBase,
	}) async {
		await validarCodigoBarrasUnico(codigoBarras);
		final producto = Producto(
			id: _generadorId.v4(),
			nombre: nombre,
			codigoBarras: codigoBarras,
			precioBase: redondearMonto(precioBase),
			unidadMedida: UnidadMedida.pieza,
			rutaImagen: '',
			activo: true,
			tiendaId: _tiendaActivaId,
		);
		await _enTransaccion((tx) async {
			await _productoRepository.guardar(producto, db: tx);
			final ahora = DateTime.now().toUtc();
			await _inventarioRepository.guardarStock(
				StockNivel(
					productoId: producto.id,
					tiendaId: _tiendaActivaId,
					cantidad: 0.0,
					actualizadoEn: ahora,
				),
				db: tx,
			);
		});
		await _emisorEventos.producto(producto);
		return producto;
	}

	// --- Inventario consolidado / agrupado ---

	/// Obtiene inventario consolidado de todas las tiendas activas.
	Future<List<StockPorTienda>> obtenerInventarioConsolidado() async {
		final tiendas = await _tiendaRepository.listarActivas();
		final productos = await _productoRepository.listarActivosPorTienda(
			_tiendaActivaId,
		);
		final resultado = <StockPorTienda>[];
		for (final tienda in tiendas) {
			for (final producto in productos) {
				final stock = await _inventarioRepository.obtenerStock(
					producto.id,
					tienda.id,
				);
				resultado.add(
					StockPorTienda(
						productoId: producto.id,
						nombreProducto: producto.nombre,
						tiendaId: tienda.id,
						nombreTienda: tienda.nombre,
						cantidad: stock?.cantidad ?? 0.0,
						actualizadoEn:
							stock?.actualizadoEn ?? DateTime.fromMillisecondsSinceEpoch(0),
						stockMinimo: stock?.stockMinimo ?? 0.0,
					),
				);
			}
		}
		return resultado;
	}

	/// Agrupa existencias por producto con totales por tienda y almacén.
	Future<List<InventarioAgrupado>> obtenerInventarioAgrupado({
		String? tiendaReferenciaId,
	}) async {
		final tiendaRef = tiendaReferenciaId ?? _tiendaActivaId;
		final productos = await _productoRepository.listarTodosPorTienda(
			_tiendaActivaId,
		);
		final agrupados = <InventarioAgrupado>[];
		for (final producto in productos) {
			final agrupado = await _construirInventarioAgrupado(
				producto: producto,
				tiendaReferenciaId: tiendaRef,
			);
			if (agrupado != null) {
				agrupados.add(agrupado);
			}
		}
		agrupados.sort((a, b) => a.nombreProducto.compareTo(b.nombreProducto));
		return agrupados;
	}

	/// Existencias de un producto en todas las tiendas y almacenes.
	Future<InventarioAgrupado?> obtenerExistenciasProducto(
		String productoId, {
		String? tiendaReferenciaId,
	}) async {
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return null;
		}
		return _construirInventarioAgrupado(
			producto: producto,
			tiendaReferenciaId: tiendaReferenciaId ?? _tiendaActivaId,
		);
	}

	Future<InventarioAgrupado?> _construirInventarioAgrupado({
		required Producto producto,
		required String tiendaReferenciaId,
	}) async {
		final tiendas = await _tiendaRepository.listarActivas();
		final almacenRepo = _almacenRepository;
		final almacenes = almacenRepo != null
			? await almacenRepo.listarActivos()
			: <Almacen>[];
		final stocksProducto = <String, StockAlmacen>{};
		if (almacenRepo != null) {
			for (final stock in await almacenRepo.listarTodoStock()) {
				if (stock.productoId == producto.id) {
					stocksProducto[stock.almacenId] = stock;
				}
			}
		}
		final porNombre = <String, double>{};
		final porTiendaId = <String, double>{};
		final minimosPorTiendaId = <String, double>{};
		for (final tienda in tiendas) {
			final stock = await _inventarioRepository.obtenerStock(
				producto.id,
				tienda.id,
			);
			porNombre[tienda.nombre] = stock?.cantidad ?? 0.0;
			porTiendaId[tienda.id] = stock?.cantidad ?? 0.0;
			minimosPorTiendaId[tienda.id] = stock?.stockMinimo ?? 0.0;
		}
		final porAlmacenNombre = <String, double>{};
		final porAlmacenId = <String, double>{};
		final minimosPorAlmacenId = <String, double>{};
		for (final almacen in almacenes) {
			final stock = stocksProducto[almacen.id];
			porAlmacenNombre[almacen.nombre] = stock?.cantidad ?? 0.0;
			porAlmacenId[almacen.id] = stock?.cantidad ?? 0.0;
			minimosPorAlmacenId[almacen.id] = stock?.stockMinimo ?? 0.0;
		}
		final referencia = await _inventarioRepository.obtenerStock(
			producto.id,
			tiendaReferenciaId,
		);
		return InventarioAgrupado(
			productoId: producto.id,
			nombreProducto: producto.nombre,
			existenciasPorTienda: porNombre,
			existenciasPorTiendaId: porTiendaId,
			stockMinimoPorTiendaId: minimosPorTiendaId,
			existenciasPorAlmacen: porAlmacenNombre,
			existenciasPorAlmacenId: porAlmacenId,
			stockMinimoPorAlmacenId: minimosPorAlmacenId,
			stockMinimoLocal: referencia?.stockMinimo ?? 0.0,
			cantidadLocal: referencia?.cantidad ?? 0.0,
		);
	}

	// --- Variantes ---

	Future<List<VarianteProducto>> listarVariantes(String productoPadreId) async {
		return _varianteRepository?.listarPorProductoPadre(productoPadreId) ?? [];
	}

	Future<VarianteProducto> registrarVariante({
		required String productoPadreId,
		required String nombre,
		required String sku,
		required String codigoBarras,
		required double precioBase,
	}) async {
		final repo = _varianteRepository;
		if (repo == null) {
			throw StateError('Repositorio de variantes no configurado');
		}
		final padre = await _productoRepository.obtenerPorId(productoPadreId);
		if (padre != null) {
			validarPrecioVenta(precioBase, padre.costoUnitario);
		}
		final variante = VarianteProducto(
			id: _generadorId.v4(),
			productoPadreId: productoPadreId,
			nombre: nombre,
			sku: sku,
			codigoBarras: codigoBarras,
			precioBase: precioBase,
			activo: true,
		);
		await repo.guardar(variante);
		await _emisorEventos.variante(variante);
		return variante;
	}

	Future<void> actualizarVariante(VarianteProducto variante) async {
		final padre = await _productoRepository.obtenerPorId(
			variante.productoPadreId,
		);
		if (padre != null) {
			validarPrecioVenta(variante.precioBase, padre.costoUnitario);
		}
		await _varianteRepository?.guardar(variante);
		await _emisorEventos.variante(variante);
	}
}
