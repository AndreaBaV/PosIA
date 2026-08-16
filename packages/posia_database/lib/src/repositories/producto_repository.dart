/// Repositorio SQLite de productos comerciales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../seed/placeholders_ejemplo.dart';
import '../utils/asegurador_padres_fk.dart';
import '../utils/duplicados_producto.dart';

/// Persiste y consulta catalogo de productos local.
class ProductoRepository {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	ProductoRepository({required Database baseDatos})
		: _baseDatos = baseDatos,
		  _padresFk = AseguradorPadresFk(baseDatos);

	final Database _baseDatos;
	final AseguradorPadresFk _padresFk;

	static const _sqlCatalogoActivo = '''
		SELECT p.*
		FROM products p
		WHERE p.activo = 1
	''';

	static const _sqlCatalogoCompleto = '''
		SELECT p.*
		FROM products p
	''';

	/// Lista todos los productos activos del catalogo unificado del tenant.
	///
	/// [tiendaId] Se conserva por compatibilidad; la existencia se consulta aparte.
	Future<List<Producto>> listarActivosPorTienda(String tiendaId) async {
		final filas = await _baseDatos.rawQuery(
			'$_sqlCatalogoActivo ORDER BY p.nombre ASC',
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Cuenta productos activos del catalogo, sin contar el placeholder guia.
	///
	/// El sync la usa para detectar un catalogo local vacio y reconstruirlo
	/// desde origen en vez de pedir solo el delta.
	Future<int> contarActivosReales() async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM products WHERE activo = 1 AND id <> ?',
			[IdsEjemplo.producto],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	/// Cuenta productos (activos e inactivos) asignados a una categoria.
	Future<int> contarPorCategoria(String categoriaId) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT COUNT(*) AS total FROM products WHERE categoria_id = ?',
			[categoriaId],
		);
		return (filas.first['total'] as int?) ?? 0;
	}

	/// Mueve todos los productos de [origenId] a [destinoId].
	///
	/// Necesario antes de enterrar una categoria: la FK local impide borrar
	/// el padre si aun hay hijos, y el catalogo no debe quedar huerfano.
	Future<int> reasignarCategoria({
		required String origenId,
		required String destinoId,
	}) {
		return _baseDatos.update(
			'products',
			{
				'categoria_id': destinoId,
				'actualizado_en': DateTime.now().toUtc().toIso8601String(),
			},
			where: 'categoria_id = ?',
			whereArgs: [origenId],
		);
	}

	/// Productos sin categoria (null o cadena vacia).
	Future<int> reasignarHuerfanos(String destinoId) {
		return _baseDatos.rawUpdate(
			'''
			UPDATE products
			SET categoria_id = ?, actualizado_en = ?
			WHERE categoria_id IS NULL OR categoria_id = ''
			''',
			[destinoId, DateTime.now().toUtc().toIso8601String()],
		);
	}

	/// Todos los productos de una categoria, o huerfanos si [categoriaId] vacio.
	Future<List<Producto>> listarPorCategoriaId(String categoriaId) async {
		if (categoriaId.isEmpty) {
			final filas = await _baseDatos.rawQuery(
				'''
				SELECT * FROM products
				WHERE categoria_id IS NULL OR categoria_id = ''
				ORDER BY nombre ASC
				''',
			);
			return filas.map(_mapearProducto).toList();
		}
		final filas = await _baseDatos.query(
			'products',
			where: 'categoria_id = ?',
			whereArgs: [categoriaId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Conteo de productos por categoria_id. Clave vacia = sin categoria.
	Future<Map<String, int>> contarAgrupadoPorCategoria() async {
		final filas = await _baseDatos.rawQuery(
			'''
			SELECT categoria_id AS id, COUNT(*) AS total
			FROM products
			GROUP BY categoria_id
			''',
		);
		final mapa = <String, int>{};
		for (final fila in filas) {
			final id = fila['id'] as String? ?? '';
			final total = fila['total'];
			mapa[id] = total is int ? total : int.tryParse('$total') ?? 0;
		}
		return mapa;
	}

	/// Hasta [limite] nombres de producto por categoria, para reconocer el grupo.
	Future<Map<String, List<String>>> muestrasPorCategoria({int limite = 4}) async {
		final filas = await _baseDatos.rawQuery(
			'SELECT categoria_id AS id, nombre FROM products ORDER BY nombre ASC',
		);
		final mapa = <String, List<String>>{};
		for (final fila in filas) {
			final id = fila['id'] as String? ?? '';
			final lista = mapa.putIfAbsent(id, () => <String>[]);
			if (lista.length >= limite) {
				continue;
			}
			final nombre = (fila['nombre'] as String? ?? '').trim();
			if (nombre.isNotEmpty) {
				lista.add(nombre);
			}
		}
		return mapa;
	}

	/// Lista productos activos filtrados por categoria.
	///
	/// [tiendaId] Tienda propietaria del catalogo.
	/// [categoriaId] Categoria solicitada.
	Future<List<Producto>> listarActivosPorCategoria(
		String tiendaId,
		String categoriaId,
	) async {
		final filas = await _baseDatos.rawQuery(
			'''
			$_sqlCatalogoActivo
				AND p.categoria_id = ?
			ORDER BY p.nombre ASC
			''',
			[categoriaId],
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Obtiene producto por identificador.
	Future<Producto?> obtenerPorId(String productoId) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'id = ?',
			whereArgs: [productoId],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearProducto(filas.first);
	}

	/// Lista catalogo completo de gestion (activos e inactivos).
	Future<List<Producto>> listarTodosPorTienda(String tiendaId) async {
		final filas = await _baseDatos.rawQuery(
			'$_sqlCatalogoCompleto ORDER BY p.nombre ASC',
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Lista productos activos vinculados a un proveedor.
	Future<List<Producto>> listarPorProveedor(String tiendaId, String proveedorId) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'proveedor_id = ? AND activo = 1',
			whereArgs: [proveedorId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Elimina producto del catalogo.
	Future<void> eliminar(String productoId, {DatabaseExecutor? db}) async {
		final exec = db ?? _baseDatos;
		await exec.delete(
			'products',
			where: 'id = ?',
			whereArgs: [productoId],
		);
	}

	/// Busca producto activo por codigo de barras en una tienda.
	///
	/// [codigoBarras] Codigo escaneado.
	/// [tiendaId] Tienda donde buscar; si es null, busca en cualquier tienda.
	/// Retorna producto encontrado o null.
	Future<Producto?> buscarPorCodigoBarras(
		String codigoBarras, {
		String? tiendaId,
	}) async {
		final codigo = codigoBarras.trim();
		if (codigo.isEmpty) {
			return null;
		}
		if (tiendaId != null) {
			final filas = await _baseDatos.rawQuery(
				'''
				$_sqlCatalogoActivo
					AND p.codigo_barras = ?
				ORDER BY p.id ASC
				LIMIT 1
				''',
				[codigo],
			);
			if (filas.isEmpty) {
				return null;
			}
			return _mapearProducto(filas.first);
		}
		final filas = await _baseDatos.query(
			'products',
			where: 'codigo_barras = ? AND activo = 1',
			whereArgs: [codigo],
			orderBy: 'id ASC',
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearProducto(filas.first);
	}

	/// Busca un producto activo por nombre normalizado, en el catalogo
	/// unificado (cualquier tienda). Usado para evitar altas duplicadas cuando
	/// no hay codigo de barras que las prevenga (p. ej. importacion a granel).
	Future<Producto?> buscarActivoPorNombre(String nombre) async {
		final clave = normalizarTextoBusqueda(nombre.trim());
		if (clave.isEmpty) {
			return null;
		}
		final filas = await _baseDatos.rawQuery(
			'''
			$_sqlCatalogoActivo
			ORDER BY p.id ASC
			''',
		);
		for (final fila in filas) {
			if (normalizarTextoBusqueda((fila['nombre'] as String).trim()) == clave) {
				return _mapearProducto(fila);
			}
		}
		return null;
	}

	/// Indica si ya existe un producto activo con el mismo codigo de barras.
	///
	/// [tiendaId] Tienda del catalogo.
	/// [codigoBarras] Codigo a validar.
	/// [excluirProductoId] Producto a ignorar (edicion).
	Future<bool> existeCodigoBarrasActivoEnTienda(
		String tiendaId,
		String codigoBarras, {
		String? excluirProductoId,
	}) async {
		final codigo = codigoBarras.trim();
		if (codigo.isEmpty) {
			return false;
		}
		final where = StringBuffer('codigo_barras = ? AND activo = 1');
		final args = <Object?>[codigo];
		if (excluirProductoId != null) {
			where.write(' AND id != ?');
			args.add(excluirProductoId);
		}
		final filas = await _baseDatos.query(
			'products',
			columns: ['id'],
			where: where.toString(),
			whereArgs: args,
			limit: 1,
		);
		return filas.isNotEmpty;
	}

	/// Inserta o reemplaza producto en catalogo local.
	///
	/// [producto] Producto a persistir.
	Future<void> guardar(Producto producto, {DatabaseExecutor? db}) async {
		final padres = db == null ? _padresFk : AseguradorPadresFk(db);
		await padres.asegurarPadresDeProducto(
			tiendaId: producto.tiendaId,
			categoriaId: producto.categoriaId,
			proveedorId: producto.proveedorId,
		);
		final exec = db ?? _baseDatos;
		// Si el llamador no trae una fecha de edicion explicita (los eventos
		// remotos SI la traen: la fecha real en que se hizo el cambio, no
		// cuando este dispositivo la aplico), se estampa ahora. Sin esto la
		// resolucion de colisiones de catalogo (ver `_resolverColisionAlInsertar`)
		// no tendria forma de saber "cual version es mas reciente" para las
		// escrituras locales normales (alta/edicion desde administracion).
		final productoAGuardar = producto.actualizadoEn == null
			? producto.copiarCon(actualizadoEn: DateTime.now().toUtc())
			: producto;
		final datos = _mapearProductoMapa(productoAGuardar);
		// NUNCA ConflictAlgorithm.replace aqui. `INSERT OR REPLACE` resuelve el
		// conflicto de clave primaria BORRANDO la fila existente antes de
		// insertar la nueva, y desde la migracion v33 ese borrado dispara
		// ON DELETE CASCADE sobre nueve tablas hijas: presentaciones (empaques),
		// stock_levels y stock_almacen (inventario), wholesale_tiers (escalas),
		// product_variants, price_list_items, customer_product_prices,
		// lote_promocion_miembros y combo_miembros.
		//
		// Es decir: guardar un producto le vaciaba empaques, existencias, precios
		// de mayoreo y variantes. UPDATE + INSERT preserva las filas hijas.
		final filasActualizadas = await exec.update(
			'products',
			datos,
			where: 'id = ?',
			whereArgs: [productoAGuardar.id],
		);
		if (filasActualizadas > 0) {
			return;
		}
		if (productoAGuardar.codigoBarras.trim().isEmpty) {
			// Sin codigo no hay indice unico que pueda chocar: alta directa.
			await exec.insert(
				'products',
				datos,
				conflictAlgorithm: ConflictAlgorithm.ignore,
			);
			return;
		}
		try {
			await exec.insert('products', datos);
		} on DatabaseException catch (error) {
			if (!error.isUniqueConstraintError()) {
				rethrow;
			}
			await _resolverColisionAlInsertar(exec, productoAGuardar, datos);
		}
	}

	/// Resuelve una colision del indice unico `(tienda_id, codigo_barras)` al
	/// insertar un producto que no existia localmente.
	///
	/// Antes esta colision se resolvia con `ConflictAlgorithm.ignore`: el
	/// producto entrante desaparecia sin dejar rastro (ni error, ni fila, ni
	/// evento en cuarentena) y el dispositivo quedaba con un catalogo
	/// incompleto aunque su cursor de sync ya estuviera al dia. Aqui el
	/// entrante SIEMPRE queda persistido.
	///
	/// Quien "gana" (que sus valores -precio, costo, nombre- terminen en la
	/// fila activa) lo decide `actualizado_en`: la edicion mas reciente
	/// manda, igual que el hub decide en Neon (`ProyectorEventosPostgres.
	/// _producto`: el ultimo evento que llega sobreescribe el canonico). Si
	/// ninguno de los dos lados tiene fecha (bases de antes de este
	/// seguimiento) se cae a la regla anterior -mas referencias
	/// transaccionales gana, empate por id- como respaldo.
	///
	/// La fila EXISTENTE conserva siempre su id (no rompe referencias
	/// transaccionales -ventas, stock- que ya la usan); solo sus VALORES se
	/// sobreescriben cuando el entrante gana. El id del entrante queda como
	/// alias inactivo con el codigo vacio, para no volver a chocar.
	Future<void> _resolverColisionAlInsertar(
		DatabaseExecutor exec,
		Producto entrante,
		Map<String, Object?> datosEntrante,
	) async {
		final filasExistente = await exec.query(
			'products',
			columns: ['id', 'actualizado_en'],
			where: 'tienda_id = ? AND codigo_barras = ? AND activo = 1 AND id <> ?',
			whereArgs: [entrante.tiendaId, entrante.codigoBarras, entrante.id],
			limit: 1,
		);
		if (filasExistente.isEmpty) {
			// La fila que bloqueaba ya no esta activa (se desactivo en paralelo
			// justo entre el UPDATE y este INSERT): el slot esta libre.
			await exec.insert(
				'products',
				datosEntrante,
				conflictAlgorithm: ConflictAlgorithm.ignore,
			);
			return;
		}
		final existenteId = filasExistente.first['id']! as String;
		final existenteActualizadoEn = DateTime.tryParse(
			filasExistente.first['actualizado_en'] as String? ?? '',
		);
		final entranteActualizadoEn = entrante.actualizadoEn;
		final bool entranteGana;
		if (entranteActualizadoEn != null || existenteActualizadoEn != null) {
			// Al menos un lado tiene fecha conocida: un lado sin fecha se trata
			// como "desconocida hace mucho" y pierde contra cualquier fecha real.
			final centinela = DateTime.utc(1970);
			entranteGana = (entranteActualizadoEn ?? centinela)
				.isAfter(existenteActualizadoEn ?? centinela);
		} else {
			final refsExistente =
				await contarReferenciasTransaccionalesProducto(exec, existenteId);
			final refsEntrante =
				await contarReferenciasTransaccionalesProducto(exec, entrante.id);
			entranteGana = productoGanaColision(
				idA: entrante.id,
				refsA: refsEntrante,
				idB: existenteId,
				refsB: refsExistente,
			);
		}
		if (entranteGana) {
			final datosRemapeados = Map<String, Object?>.from(datosEntrante)
				..['id'] = existenteId;
			await exec.update(
				'products',
				datosRemapeados,
				where: 'id = ?',
				whereArgs: [existenteId],
			);
		}
		// El id propio del entrante queda como alias inactivo -gane o no-: asi
		// se conserva su dato completo (costo, notas, lo que haya capturado el
		// usuario) sin competir por el slot del codigo activo.
		await exec.insert(
			'products',
			{...datosEntrante, 'activo': 0, 'codigo_barras': ''},
			conflictAlgorithm: ConflictAlgorithm.ignore,
		);
	}

	/// Convierte fila SQLite a entidad [Producto].
	///
	/// Tolera valores que esta build no conoce en vez de lanzar. La escritura ya
	/// era tolerante (el aplicador de eventos usa `firstWhere` con `orElse`) pero
	/// la lectura no: bastaba un producto guardado por una version mas nueva —con
	/// una unidad de medida o un vertical que aqui no existen— para que
	/// `byName` lanzara y se cayera el catalogo COMPLETO, no solo esa fila.
	/// Igual con `precio_base`: SQLite devuelve int si el valor se guardo sin
	/// decimales y el cast a double reventaba.
	///
	/// [fila] Registro de base de datos.
	/// Retorna instancia de dominio.
	Producto _mapearProducto(Map<String, Object?> fila) {
		return Producto(
			id: fila['id'] as String? ?? '',
			nombre: fila['nombre'] as String? ?? '',
			codigoBarras: fila['codigo_barras'] as String? ?? '',
			precioBase: (fila['precio_base'] as num?)?.toDouble() ?? 0.0,
			unidadMedida: _leerEnum(
				UnidadMedida.values,
				fila['unidad_medida'],
				UnidadMedida.pieza,
			),
			rutaImagen: fila['ruta_imagen'] as String? ?? '',
			activo: ((fila['activo'] as num?)?.toInt() ?? 0) == 1,
			tiendaId: fila['tienda_id'] as String? ?? '',
			moduloVertical: _leerEnum(
				ModuloVertical.values,
				fila['modulo_vertical'],
				ModuloVertical.general,
			),
			categoriaId: fila['categoria_id'] as String?,
			piezasPorCaja: (fila['piezas_por_caja'] as num?)?.toInt(),
			unidadesPorBulto: (fila['unidades_por_bulto'] as num?)?.toInt(),
			proveedorId: fila['proveedor_id'] as String?,
			notas: fila['notas'] as String? ?? '',
			costoUnitario: (fila['costo_unitario'] as num?)?.toDouble() ?? 0.0,
			favoritoCaja: ((fila['favorito_caja'] as num?)?.toInt() ?? 0) == 1,
			permiteStockNegativo:
				((fila['permite_stock_negativo'] as num?)?.toInt() ?? 0) == 1,
			actualizadoEn: DateTime.tryParse(
				fila['actualizado_en'] as String? ?? '',
			),
		);
	}

	/// Resuelve un enum por nombre cayendo a [porDefecto] si no se reconoce.
	static T _leerEnum<T extends Enum>(
		List<T> valores,
		Object? almacenado,
		T porDefecto,
	) {
		final nombre = almacenado as String?;
		if (nombre == null || nombre.isEmpty) {
			return porDefecto;
		}
		for (final valor in valores) {
			if (valor.name == nombre) {
				return valor;
			}
		}
		return porDefecto;
	}

	/// Convierte entidad a mapa para SQLite.
	///
	/// [producto] Producto de dominio.
	/// Retorna mapa de columnas.
	Map<String, Object?> _mapearProductoMapa(Producto producto) {
		return {
			'id': producto.id,
			'nombre': producto.nombre,
			'codigo_barras': producto.codigoBarras,
			'precio_base': producto.precioBase,
			'unidad_medida': producto.unidadMedida.name,
			'ruta_imagen': producto.rutaImagen,
			'activo': producto.activo ? 1 : 0,
			'tienda_id': producto.tiendaId,
			'modulo_vertical': producto.moduloVertical.name,
			'categoria_id': producto.categoriaId,
			'piezas_por_caja': producto.piezasPorCaja,
			'unidades_por_bulto': producto.unidadesPorBulto,
			'proveedor_id': producto.proveedorId,
			'notas': producto.notas,
			'costo_unitario': producto.costoUnitario,
			'favorito_caja': producto.favoritoCaja ? 1 : 0,
			'permite_stock_negativo': producto.permiteStockNegativo ? 1 : 0,
			'actualizado_en': producto.actualizadoEn?.toUtc().toIso8601String(),
		};
	}

	/// Lista productos marcados como favoritos de caja.
	Future<List<Producto>> listarFavoritosCaja(String tiendaId) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'activo = 1 AND favorito_caja = 1',
			whereArgs: const [],
			orderBy: 'nombre ASC',
			limit: 12,
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Alterna marca de favorito en caja.
	Future<void> establecerFavoritoCaja(String productoId, bool favorito) async {
		await _baseDatos.update(
			'products',
			{'favorito_caja': favorito ? 1 : 0},
			where: 'id = ?',
			whereArgs: [productoId],
		);
	}
}
