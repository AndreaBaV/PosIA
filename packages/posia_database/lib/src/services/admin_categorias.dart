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
import '../repositories/lapida_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Catálogo de categorías de producto.
class AdminCategorias {
	AdminCategorias({
		required AdminEmisorEventosSync emisorEventos,
		CategoriaRepository? categoriaRepository,
		LapidaRepository? lapidaRepository,
	}) : _emisorEventos = emisorEventos,
	     _categoriaRepository = categoriaRepository,
	     _lapidaRepository = lapidaRepository;

	final AdminEmisorEventosSync _emisorEventos;
	final CategoriaRepository? _categoriaRepository;
	final LapidaRepository? _lapidaRepository;
	final Uuid _generadorId = const Uuid();

	/// Lista categorías del catálogo, sin stubs FK ni las que un admin borró.
	///
	/// Un stub ("Categoría", ver `Categoria.esStubFk`) es un placeholder de
	/// integridad creado cuando un producto llegó antes que su categoría real
	/// — no es un grupo de negocio. Mostrarlo aquí con su switch de
	/// "reactivar" invita a reactivarlo por error, lo que ensucia el hub
	/// (misma corrección que ya aplica `ServicioCaja.listarCategorias`).
	Future<List<Categoria>> listarCategorias() async {
		final todas = await _categoriaRepository?.listarTodas() ?? [];
		final sinStubs = todas.where((c) => !c.esStubFk).toList();
		final enterradas =
			await _lapidaRepository?.idsEliminados(TipoLapida.categoria) ??
			const <String>{};
		if (enterradas.isEmpty) {
			return sinStubs;
		}
		// Las eliminadas por un administrador ya no existen para el usuario.
		return sinStubs.where((c) => !enterradas.contains(c.id)).toList();
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

	/// Borrado manual del administrador: absoluto y con prioridad sobre el hub.
	///
	/// Antes solo hacia baja logica y emitia un upsert con `activa: false`, asi
	/// que cualquier equipo podia reactivarla y volvia a aparecer. Ahora ademas
	/// deja lapida: los listados la ocultan y todo `categoryUpserted` posterior
	/// se descarta en cualquier caja.
	Future<void> eliminarCategoria(
		String categoriaId, {
		String eliminadoPor = '',
	}) async {
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
		await _lapidaRepository?.registrar(
			tipo: TipoLapida.categoria,
			entidadId: categoriaId,
			eliminadoPor: eliminadoPor,
		);
		await _emisorEventos.categoriaEliminada(categoriaId);
	}
}
