/// Tabla guia `ejemplo` y registros placeholder al crear el esquema.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

/// IDs fijos de filas con nombre literal `ejemplo`.
abstract final class IdsEjemplo {
	static const String tienda = 'id-ejemplo-tienda';
	static const String categoria = 'id-ejemplo-categoria';
	static const String producto = 'id-ejemplo-producto';
	static const String cliente = 'id-ejemplo-cliente';
	static const String vendedor = 'id-ejemplo-vendedor';
	static const String proveedor = 'id-ejemplo-proveedor';
	static const String tenant = 'id-ejemplo-tenant';
	static const String usuario = 'id-ejemplo-usuario';
}

/// Crea la tabla `ejemplo` y datos guia al inicializar SQLite.
class PlaceholdersEjemplo {
	const PlaceholdersEjemplo._();

	/// Columna unica de texto guia por seccion del sistema.
	static Future<void> crearTablaGuia(Database base) async {
		await base.execute('''
			CREATE TABLE IF NOT EXISTS ejemplo (
				seccion TEXT PRIMARY KEY,
				ejemplo TEXT NOT NULL
			)
		''');
	}

	/// Guia en la base del dispositivo (hub, sin datos de negocio).
	static Future<void> insertarGuiaDispositivo(Database base) async {
		await crearTablaGuia(base);
		final filas = {
			'hub_url': 'ejemplo',
			'hub_api_key': 'ejemplo',
			'configuracion': 'Copie POSIA_HUB_URL y POSIA_HUB_API_KEY en apps/posia_pos/.env',
		};
		for (final entrada in filas.entries) {
			await base.insert(
				'ejemplo',
				{'seccion': entrada.key, 'ejemplo': entrada.value},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
		}
	}

	/// Guia y registros `ejemplo` en la base operativa del tenant.
	static Future<void> insertarGuiaTenant(Database base) async {
		await crearTablaGuia(base);
		final guias = {
			'tienda': 'Nombre de sucursal: ejemplo',
			'categoria': 'Nombre de categoria: ejemplo',
			'producto': 'Nombre de producto: ejemplo',
			'cliente': 'Nombre de cliente: ejemplo',
			'vendedor': 'Nombre de vendedor: ejemplo',
			'proveedor': 'Nombre de proveedor: ejemplo',
			'usuario': 'Nombre de usuario: ejemplo (codigo numerico propio)',
		};
		for (final entrada in guias.entries) {
			await base.insert(
				'ejemplo',
				{'seccion': entrada.key, 'ejemplo': entrada.value},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
		}
		if (!MODO_RELEASE) {
			await _insertarRegistrosTenant(base);
		}
	}

	static Future<void> _insertarRegistrosTenant(Database base) async {
		final ahora = DateTime.now().toUtc().toIso8601String();
		await base.insert('stores', {
			'id': IdsEjemplo.tienda,
			'nombre': 'ejemplo',
			'direccion': 'ejemplo',
			'activa': 1,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await base.insert('categories', {
			'id': IdsEjemplo.categoria,
			'nombre': 'ejemplo',
			'icono': 'shopping_basket',
			'color_hex': '#4CAF50',
			'orden': 0,
			'activa': 1,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await base.insert('products', {
			'id': IdsEjemplo.producto,
			'nombre': 'ejemplo',
			'codigo_barras': 'ejemplo',
			'precio_base': 0.0,
			'unidad_medida': 'pieza',
			'ruta_imagen': '',
			'activo': 1,
			'tienda_id': IdsEjemplo.tienda,
			'modulo_vertical': 'general',
			'categoria_id': IdsEjemplo.categoria,
			'notas': 'ejemplo',
			'costo_unitario': 0.0,
			'favorito_caja': 0,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await base.insert('customers', {
			'id': IdsEjemplo.cliente,
			'nombre': 'ejemplo',
			'credito_habilitado': 0,
			'activo': 1,
			'telefono': 'ejemplo',
			'email': 'ejemplo',
			'rfc': 'ejemplo',
			'direccion': 'ejemplo',
			'notas': 'ejemplo',
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await base.insert('vendedores', {
			'id': IdsEjemplo.vendedor,
			'nombre': 'ejemplo',
			'codigo': 'ejemplo',
			'activo': 1,
			'tienda_id': IdsEjemplo.tienda,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await base.insert('proveedores', {
			'id': IdsEjemplo.proveedor,
			'nombre': 'ejemplo',
			'contacto': 'ejemplo',
			'telefono': 'ejemplo',
			'activo': 1,
			'email': 'ejemplo',
			'rfc': 'ejemplo',
			'direccion': 'ejemplo',
			'notas': 'ejemplo',
			'dias_credito': 0,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		final sal = HasherPin.generarSal();
		final hash = HasherPin.hashPin('1234', sal);
		await base.insert('usuarios', {
			'id': IdsEjemplo.usuario,
			'nombre': 'ejemplo',
			'codigo': '9998',
			'pin_hash': hash,
			'pin_salt': sal,
			'rol': RolUsuario.administrador.name,
			'tienda_id': null,
			'activo': 1,
			'creado_en': ahora,
			'actualizado_en': ahora,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await base.insert('stock_levels', {
			'producto_id': IdsEjemplo.producto,
			'tienda_id': IdsEjemplo.tienda,
			'cantidad': 0.0,
			'actualizado_en': ahora,
			'stock_minimo': 0.0,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
	}
}
