/// Repositorio SQLite de productos comerciales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/asegurador_padres_fk.dart';

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
		if (db == null) {
			await _padresFk.asegurarPadresDeProducto(
				tiendaId: producto.tiendaId,
				categoriaId: producto.categoriaId,
				proveedorId: producto.proveedorId,
			);
		}
		final exec = db ?? _baseDatos;
		await exec.insert(
			'products',
			_mapearProductoMapa(producto),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Convierte fila SQLite a entidad [Producto].
	///
	/// [fila] Registro de base de datos.
	/// Retorna instancia de dominio.
	Producto _mapearProducto(Map<String, Object?> fila) {
		final verticalNombre = fila['modulo_vertical'] as String? ?? ModuloVertical.general.name;
		return Producto(
			id: fila['id'] as String,
			nombre: fila['nombre'] as String,
			codigoBarras: fila['codigo_barras'] as String,
			precioBase: fila['precio_base'] as double,
			unidadMedida: UnidadMedida.values.byName(fila['unidad_medida'] as String),
			rutaImagen: fila['ruta_imagen'] as String,
			activo: (fila['activo'] as int) == 1,
			tiendaId: fila['tienda_id'] as String,
			moduloVertical: ModuloVertical.values.byName(verticalNombre),
			categoriaId: fila['categoria_id'] as String?,
			piezasPorCaja: fila['piezas_por_caja'] as int?,
			unidadesPorBulto: fila['unidades_por_bulto'] as int?,
			proveedorId: fila['proveedor_id'] as String?,
			notas: fila['notas'] as String? ?? '',
			costoUnitario: (fila['costo_unitario'] as num?)?.toDouble() ?? 0.0,
			favoritoCaja: ((fila['favorito_caja'] as int?) ?? 0) == 1,
			permiteStockNegativo: ((fila['permite_stock_negativo'] as int?) ?? 0) == 1,
		);
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
