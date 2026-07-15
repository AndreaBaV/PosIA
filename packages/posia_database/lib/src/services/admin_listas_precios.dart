/// Dominio de listas de precios: catálogo de listas, items por producto y
/// resumen consolidado de precios (genérico, por lista y por cliente).
///
/// Extraído de `ServicioAdmin`. `establecerPrecioProducto` se quedó ahí:
/// orquesta tres dominios (producto, esta clase, clientes) según el
/// alcance elegido.
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../models/item_lista_precios.dart';
import '../models/resumen_precios_producto.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/precio_repository.dart';
import '../repositories/producto_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';
import 'admin_catalogo_productos.dart';
import 'admin_clientes.dart';

/// Listas de precios y su resumen por producto.
class AdminListasPrecios {
	AdminListasPrecios({
		required ProductoRepository productoRepository,
		required AdminEmisorEventosSync emisorEventos,
		required AdminCatalogoProductos catalogoProductos,
		required AdminClientes clientes,
		PrecioRepository? precioRepository,
		ClienteRepository? clienteRepository,
	}) : _productoRepository = productoRepository,
	     _emisorEventos = emisorEventos,
	     _catalogoProductos = catalogoProductos,
	     _clientes = clientes,
	     _precioRepository = precioRepository,
	     _clienteRepository = clienteRepository;

	final ProductoRepository _productoRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final AdminCatalogoProductos _catalogoProductos;
	final AdminClientes _clientes;
	final PrecioRepository? _precioRepository;
	final ClienteRepository? _clienteRepository;
	final Uuid _generadorId = const Uuid();

	Future<List<ListaPrecios>> listarListasPrecios() async {
		return _precioRepository?.listarTodasListas() ?? [];
	}

	Future<ListaPrecios> registrarListaPrecios(String nombre) async {
		final repo = _precioRepository;
		if (repo == null) {
			throw StateError('Repositorio de precios no disponible');
		}
		final lista = ListaPrecios(id: _generadorId.v4(), nombre: nombre.trim());
		await repo.guardarLista(lista);
		await _emisorEventos.listaPrecios(lista);
		return lista;
	}

	Future<void> guardarPrecioLista(
		String listaId,
		String productoId,
		double precio,
	) async {
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			throw StateError('Producto no encontrado');
		}
		_catalogoProductos.validarPrecioVenta(precio, producto.costoUnitario);
		final precioRedondeado = redondearMonto(precio);
		await _precioRepository?.guardarPrecioLista(
			listaId,
			productoId,
			precioRedondeado,
		);
		await _emisorEventos.itemListaPrecios(
			listaId: listaId,
			productoId: productoId,
			precioUnitario: precioRedondeado,
		);
	}

	Future<ResumenPreciosProducto?> obtenerResumenPreciosProducto(
		String productoId,
	) async {
		final producto = await _productoRepository.obtenerPorId(productoId);
		if (producto == null) {
			return null;
		}
		final repo = _precioRepository;
		final listas = await repo?.listarTodasListas() ?? [];
		final clientes = await _clientes.listarClientes();
		final preciosLista =
			await repo?.listarPreciosProductoEnListas(productoId) ?? {};
		final preciosCliente =
			await repo?.listarPreciosProductoPorCliente(productoId) ?? [];
		return ResumenPreciosProducto(
			productoId: producto.id,
			nombreProducto: producto.nombre,
			costoUnitario: producto.costoUnitario,
			precioGenerico: producto.precioBase,
			precioMinimo: calcularPrecioMinimoVenta(producto.costoUnitario),
			preciosPorLista: preciosLista,
			preciosPorCliente: preciosCliente,
			nombresListas: {for (final l in listas) l.id: l.nombre},
			nombresClientes: {for (final c in clientes) c.id: c.nombre},
		);
	}

	Future<void> eliminarListaPrecios(String listaId) async {
		await _precioRepository?.eliminarLista(listaId);
		await _emisorEventos.listaPreciosEliminada(listaId);
	}

	Future<List<Cliente>> listarClientesPorLista(String listaId) async {
		return _clienteRepository?.listarPorLista(listaId) ?? [];
	}

	Future<List<ItemListaPrecios>> listarItemsListaPrecios(String listaId) async {
		final repo = _precioRepository;
		if (repo == null) {
			return [];
		}
		final precios = await repo.listarPreciosDeLista(listaId);
		final items = <ItemListaPrecios>[];
		for (final entry in precios.entries) {
			final producto = await _productoRepository.obtenerPorId(entry.key);
			if (producto == null || !producto.activo) {
				continue;
			}
			items.add(ItemListaPrecios(producto: producto, precioLista: entry.value));
		}
		items.sort((a, b) => a.producto.nombre.compareTo(b.producto.nombre));
		return items;
	}

	Future<void> eliminarProductoDeLista(
		String listaId,
		String productoId,
	) async {
		await _precioRepository?.eliminarPrecioDeLista(listaId, productoId);
		await _emisorEventos.itemListaPreciosEliminado(
			listaId: listaId,
			productoId: productoId,
		);
	}
}
