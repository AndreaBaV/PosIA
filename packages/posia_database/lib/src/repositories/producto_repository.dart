/// Repositorio SQLite de productos comerciales.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 20:15:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// Persiste y consulta catalogo de productos local.
class ProductoRepository {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	ProductoRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Lista productos activos de una tienda.
	///
	/// [tiendaId] Tienda propietaria del catalogo.
	/// Retorna productos activos ordenados por nombre.
	Future<List<Producto>> listarActivosPorTienda(String tiendaId) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'tienda_id = ? AND activo = 1',
			whereArgs: [tiendaId],
			orderBy: 'nombre ASC',
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
		final filas = await _baseDatos.query(
			'products',
			where: 'tienda_id = ? AND activo = 1 AND categoria_id = ?',
			whereArgs: [tiendaId, categoriaId],
			orderBy: 'nombre ASC',
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

	/// Lista todos los productos de tienda incluyendo inactivos (admin).
	Future<List<Producto>> listarTodosPorTienda(String tiendaId) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'tienda_id = ?',
			whereArgs: [tiendaId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Lista productos activos vinculados a un proveedor.
	Future<List<Producto>> listarPorProveedor(String tiendaId, String proveedorId) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'tienda_id = ? AND proveedor_id = ? AND activo = 1',
			whereArgs: [tiendaId, proveedorId],
			orderBy: 'nombre ASC',
		);
		return filas.map(_mapearProducto).toList();
	}

	/// Elimina producto del catalogo.
	Future<void> eliminar(String productoId) async {
		await _baseDatos.delete(
			'products',
			where: 'id = ?',
			whereArgs: [productoId],
		);
	}

	/// Busca producto por codigo de barras.
	///
	/// [codigoBarras] Codigo escaneado.
	/// Retorna producto encontrado o null.
	Future<Producto?> buscarPorCodigoBarras(String codigoBarras) async {
		final filas = await _baseDatos.query(
			'products',
			where: 'codigo_barras = ? AND activo = 1',
			whereArgs: [codigoBarras],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return _mapearProducto(filas.first);
	}

	/// Inserta o reemplaza producto en catalogo local.
	///
	/// [producto] Producto a persistir.
	Future<void> guardar(Producto producto) async {
		await _baseDatos.insert(
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
		};
	}
}
