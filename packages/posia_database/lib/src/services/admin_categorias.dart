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
import '../repositories/producto_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Catálogo de categorías de producto.
class AdminCategorias {
	AdminCategorias({
		required AdminEmisorEventosSync emisorEventos,
		CategoriaRepository? categoriaRepository,
		LapidaRepository? lapidaRepository,
		ProductoRepository? productoRepository,
	}) : _emisorEventos = emisorEventos,
	     _categoriaRepository = categoriaRepository,
	     _lapidaRepository = lapidaRepository,
	     _productoRepository = productoRepository;

	final AdminEmisorEventosSync _emisorEventos;
	final CategoriaRepository? _categoriaRepository;
	final LapidaRepository? _lapidaRepository;
	final ProductoRepository? _productoRepository;
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
	/// Si la categoria tiene productos, hay que pasarlos a [categoriaDestinoId]
	/// (otra categoria viva). Sin esa reasignacion el borrado se rechaza: el
	/// catalogo no puede quedar huerfano al unificar grupos.
	Future<void> eliminarCategoria(
		String categoriaId, {
		String? categoriaDestinoId,
		String eliminadoPor = '',
	}) async {
		final repo = _categoriaRepository;
		if (repo == null) {
			throw StateError('Repositorio de categorias no configurado');
		}
		final todas = await repo.listarTodas();
		final categoria = todas.where((c) => c.id == categoriaId).firstOrNull;
		if (categoria == null || categoria.esStubFk) {
			return;
		}
		final productos = await _productoRepository?.contarPorCategoria(categoriaId) ?? 0;
		var destinoId = categoriaDestinoId?.trim() ?? '';
		if (productos > 0) {
			if (destinoId.isEmpty || destinoId == categoriaId) {
				throw StateError(
					'Elija a qué categoría pasar los $productos productos '
					'antes de eliminar "${categoria.nombre}".',
				);
			}
			final destino = todas.where((c) => c.id == destinoId).firstOrNull;
			if (destino == null || destino.esStubFk) {
				throw StateError('La categoría destino no existe');
			}
			final enterrada = await _lapidaRepository?.estaEliminada(
				TipoLapida.categoria,
				destinoId,
			) ??
				false;
			if (enterrada) {
				throw StateError('La categoría destino ya fue eliminada');
			}
			await _productoRepository!.reasignarCategoria(
				origenId: categoriaId,
				destinoId: destinoId,
			);
		} else {
			destinoId = '';
		}
		await repo.guardar(categoria.copiarCon(activa: false));
		await _lapidaRepository?.registrar(
			tipo: TipoLapida.categoria,
			entidadId: categoriaId,
			eliminadoPor: eliminadoPor,
		);
		await _emisorEventos.categoriaEliminada(
			categoriaId,
			categoriaDestinoId: destinoId.isEmpty ? null : destinoId,
		);
	}

	/// Grupos reales de productos (incluye huerfanos y categorias ocultas).
	///
	/// Sirve para limpiar el catalogo cuando se revivieron placeholders o se
	/// renombraron grupos y ya no se distingue cual es cual: cada fila trae
	/// cuantos productos hay y nombres de muestra.
	Future<List<ResumenGrupoCategoria>> listarGruposProductos() async {
		final repoProd = _productoRepository;
		if (repoProd == null) {
			return const [];
		}
		final conteos = await repoProd.contarAgrupadoPorCategoria();
		final muestras = await repoProd.muestrasPorCategoria();
		final todas = await _categoriaRepository?.listarTodas() ?? [];
		final porId = {for (final c in todas) c.id: c};
		final grupos = <ResumenGrupoCategoria>[];
		for (final entrada in conteos.entries) {
			if (entrada.value <= 0) {
				continue;
			}
			grupos.add(
				ResumenGrupoCategoria(
					origenId: entrada.key,
					categoria: entrada.key.isEmpty ? null : porId[entrada.key],
					productos: entrada.value,
					muestras: muestras[entrada.key] ?? const [],
				),
			);
		}
		grupos.sort((a, b) => b.productos.compareTo(a.productos));
		return grupos;
	}

	/// Pasa todos los productos de [origenId] a [destinoId] sin borrar categorias.
	///
	/// [origenId] vacio = productos sin categoria. Emite `productUpserted` para
	/// que las demas cajas y Neon queden alineados (el hub ya entiende ese evento).
	Future<int> moverProductos({
		required String origenId,
		required String destinoId,
	}) async {
		final repoProd = _productoRepository;
		final repoCat = _categoriaRepository;
		if (repoProd == null || repoCat == null) {
			throw StateError('Repositorio de categorias no configurado');
		}
		final destino = destinoId.trim();
		if (destino.isEmpty || destino == origenId) {
			throw StateError('Elija una categoría destino distinta');
		}
		final todas = await repoCat.listarTodas();
		final destCat = todas.where((c) => c.id == destino).firstOrNull;
		if (destCat == null || destCat.esStubFk) {
			throw StateError('La categoría destino no existe');
		}
		final enterrada = await _lapidaRepository?.estaEliminada(
			TipoLapida.categoria,
			destino,
		) ??
			false;
		if (enterrada) {
			throw StateError('La categoría destino ya fue eliminada');
		}
		final productos = await repoProd.listarPorCategoriaId(origenId);
		if (productos.isEmpty) {
			return 0;
		}
		if (origenId.isEmpty) {
			await repoProd.reasignarHuerfanos(destino);
		} else {
			await repoProd.reasignarCategoria(
				origenId: origenId,
				destinoId: destino,
			);
		}
		for (final producto in productos) {
			await _emisorEventos.producto(
				producto.copiarCon(categoriaId: destino),
			);
		}
		return productos.length;
	}
}

/// Productos que hoy apuntan a una misma categoria (o a ninguna).
class ResumenGrupoCategoria {
	const ResumenGrupoCategoria({
		required this.origenId,
		required this.productos,
		this.categoria,
		this.muestras = const [],
	});

	/// Id de categoria; cadena vacia si los productos no tienen categoria.
	final String origenId;
	final Categoria? categoria;
	final int productos;
	final List<String> muestras;

	bool get esHuerfano => origenId.isEmpty;

	bool get esStub => categoria?.esStubFk ?? false;

	bool get esDesconocida => !esHuerfano && categoria == null;

	String get etiqueta {
		if (esHuerfano) {
			return 'Sin categoría';
		}
		final nombre = categoria?.nombre.trim();
		if (nombre == null || nombre.isEmpty) {
			return 'Grupo desconocido';
		}
		if (esStub) {
			return '$nombre (placeholder)';
		}
		if (categoria?.activa == false) {
			return '$nombre (desactivada)';
		}
		return nombre;
	}
}
