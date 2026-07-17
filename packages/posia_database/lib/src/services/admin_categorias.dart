/// Dominio de categorías: catálogo, orden y edición.
///
/// Extraído de `ServicioAdmin`. `_resolverCategoriaImportacion` (crea
/// categorías al vuelo durante importación de productos) y
/// `asignarCategoriaProducto` (muta un `Producto`) se quedaron ahí por
/// cruzar hacia el dominio de Producto/Importación.
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../repositories/categoria_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Catálogo de categorías de producto.
class AdminCategorias {
	AdminCategorias({
		required AdminEmisorEventosSync emisorEventos,
		CategoriaRepository? categoriaRepository,
	}) : _emisorEventos = emisorEventos,
	     _categoriaRepository = categoriaRepository;

	final AdminEmisorEventosSync _emisorEventos;
	final CategoriaRepository? _categoriaRepository;
	final Uuid _generadorId = const Uuid();

	Future<List<Categoria>> listarCategorias() async {
		return _categoriaRepository?.listarTodas() ?? [];
	}

	/// Crea la categoría o, si ya existe una activa con el mismo nombre
	/// (comparación normalizada), devuelve esa en vez de duplicarla.
	///
	/// Idempotencia por nombre necesaria porque múltiples dispositivos (3
	/// admins, 2 supervisores) pueden crear catálogo en paralelo — sin esto,
	/// dos altas del mismo nombre en dispositivos distintos generan dos IDs
	/// que Neon nunca fusiona solo.
	Future<Categoria> registrarCategoria({
		required String nombre,
		String icono = 'shopping_basket',
		String colorHex = '#4CAF50',
	}) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			throw StateError('Repositorio de categorias no configurado');
		}
		final existentes = await repo.listarTodas();
		final clave = normalizarTextoBusqueda(nombre);
		final coincidente = existentes
			.where((c) => c.activa && normalizarTextoBusqueda(c.nombre) == clave)
			.firstOrNull;
		if (coincidente != null) {
			return coincidente;
		}
		final categoria = Categoria(
			id: _generadorId.v4(),
			nombre: nombre,
			icono: icono,
			colorHex: colorHex,
			orden: existentes.length,
			activa: true,
		);
		await repo.guardar(categoria);
		await _emisorEventos.categoria(categoria);
		return categoria;
	}

	Future<void> actualizarCategoria(Categoria categoria) async {
		await _categoriaRepository?.guardar(categoria);
		await _emisorEventos.categoria(categoria);
	}

	/// Reordena categorias segun lista de ids.
	Future<void> reordenarCategorias(List<String> idsOrdenados) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			return;
		}
		for (var i = 0; i < idsOrdenados.length; i++) {
			final todas = await repo.listarTodas();
			final categoria = todas.where((c) => c.id == idsOrdenados[i]).firstOrNull;
			if (categoria != null) {
				await repo.guardar(categoria.copiarCon(orden: i));
				await _emisorEventos.categoria(categoria.copiarCon(orden: i));
			}
		}
	}

	Future<void> eliminarCategoria(String categoriaId) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			throw StateError('Repositorio de categorias no configurado');
		}
		final todas = await repo.listarTodas();
		final categoria = todas.where((c) => c.id == categoriaId).firstOrNull;
		if (categoria == null) {
			return;
		}
		await repo.guardar(categoria.copiarCon(activa: false));
		await _emisorEventos.categoria(categoria.copiarCon(activa: false));
	}
}
