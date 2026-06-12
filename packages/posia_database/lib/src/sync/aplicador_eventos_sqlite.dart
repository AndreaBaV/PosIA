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

import '../repositories/categoria_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/traspaso_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/producto_repository.dart';
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
	}) : _baseDatos = baseDatos,
	     _productoRepository = productoRepository,
	     _clienteRepository = clienteRepository,
	     _ventaRepository = ventaRepository,
	     _inventarioRepository = inventarioRepository,
	     _categoriaRepository = categoriaRepository,
	     _traspasoRepository = traspasoRepository,
	     _varianteRepository = varianteRepository;

	final Database _baseDatos;
	final ProductoRepository _productoRepository;
	final ClienteRepository _clienteRepository;
	final VentaRepository _ventaRepository;
	final InventarioRepository _inventarioRepository;
	final CategoriaRepository? _categoriaRepository;
	final TraspasoRepository? _traspasoRepository;
	final VarianteRepository? _varianteRepository;

	@override
	Future<void> aplicarEvento(SyncEvent evento) async {
		switch (evento.tipo) {
			case TipoSyncEvento.saleCompleted:
				await _aplicarVentaRemota(evento);
			case TipoSyncEvento.productUpserted:
				await _aplicarProductoRemoto(evento);
			case TipoSyncEvento.customerUpserted:
				await _aplicarClienteRemoto(evento);
			case TipoSyncEvento.stockAdjusted:
				await _aplicarAjusteStockRemoto(evento);
			case TipoSyncEvento.saleVoided:
				await _aplicarAnulacionRemota(evento);
			case TipoSyncEvento.categoryUpserted:
				await _aplicarCategoriaRemota(evento);
			case TipoSyncEvento.transferRequested:
				await _aplicarTraspasoSolicitado(evento);
			case TipoSyncEvento.transferCompleted:
				await _aplicarTraspasoCompletado(evento);
			case TipoSyncEvento.variantUpserted:
				await _aplicarVarianteRemota(evento);
			case TipoSyncEvento.salePartialReturn:
				await _aplicarDevolucionParcialRemota(evento);
		}
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

	Future<void> _aplicarAnulacionRemota(SyncEvent evento) async {
		final ventaId = evento.payload['ventaId'] as String? ?? '';
		if (ventaId.isEmpty) {
			return;
		}
		final venta = await _ventaRepository.obtenerPorId(ventaId);
		if (venta == null || !venta.puedeAnularse()) {
			return;
		}
		final ahora = DateTime.now().toUtc();
		for (final linea in venta.lineas) {
			await _ajustarStock(linea.productoId, venta.tiendaId, linea.cantidad);
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

	Future<void> _aplicarTraspasoSolicitado(SyncEvent evento) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return;
		}
		final traspaso = _mapearTraspasoRemoto(evento, EstadoTraspaso.enTransito);
		await repo.guardar(traspaso);
	}

	Future<void> _aplicarTraspasoCompletado(SyncEvent evento) async {
		final repo = _traspasoRepository;
		if (repo == null) {
			return;
		}
		final traspaso = _mapearTraspasoRemoto(evento, EstadoTraspaso.completado);
		await repo.guardar(traspaso);
		for (final linea in traspaso.lineas) {
			await _ajustarStock(
				linea.productoId,
				traspaso.tiendaDestinoId,
				linea.cantidadRecibida ?? linea.cantidadSolicitada,
			);
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
	Future<void> _aplicarVentaRemota(SyncEvent evento) async {
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
			await _ajustarStock(linea.productoId, evento.tiendaId, -linea.cantidad);
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
	Future<void> _aplicarAjusteStockRemoto(SyncEvent evento) async {
		final productoId = evento.payload['productoId'] as String? ?? '';
		final delta = (evento.payload['delta'] as num?)?.toDouble() ?? 0.0;
		if (productoId.isEmpty || delta == 0.0) {
			return;
		}
		await _ajustarStock(productoId, evento.tiendaId, delta);
	}

	/// Suma delta al stock local de producto y tienda.
	///
	/// [productoId] Producto afectado.
	/// [tiendaId] Tienda del movimiento.
	/// [delta] Variacion; negativo descuenta.
	Future<void> _ajustarStock(String productoId, String tiendaId, double delta) async {
		final actual = await _inventarioRepository.obtenerStock(productoId, tiendaId);
		final cantidadBase = actual?.cantidad ?? 0.0;
		await _inventarioRepository.guardarStock(
			StockNivel(
				productoId: productoId,
				tiendaId: tiendaId,
				cantidad: cantidadBase + delta,
				actualizadoEn: DateTime.now().toUtc(),
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
