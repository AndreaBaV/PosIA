/// Tabla guia `ejemplo` y registros placeholder del registro de tenants.
library;

import 'package:sqflite_common/sqlite_api.dart';

/// Crea guias y filas `ejemplo` en el registro maestro de plataforma.
class PlaceholdersRegistroTenants {
	const PlaceholdersRegistroTenants._();

	static const String idTenant = 'id-ejemplo-tenant';
	static const String idTienda = 'id-ejemplo-tienda';
	static const String idUsuario = 'id-ejemplo-usuario';

	static Future<void> crearTablaGuia(Database db) async {
		await db.execute('''
			CREATE TABLE IF NOT EXISTS ejemplo (
				seccion TEXT PRIMARY KEY,
				ejemplo TEXT NOT NULL
			)
		''');
	}

	static Future<void> insertarTodo(Database db) async {
		await crearTablaGuia(db);
		final guias = {
			'tenant': 'Nombre del negocio: ejemplo',
			'tienda': 'Nombre sucursal: ejemplo',
			'usuario': 'Nombre usuario: ejemplo | codigo numerico | PIN de 4 digitos',
			'hub': 'DATABASE_URL en platform/.env apunta a Neon',
		};
		for (final entrada in guias.entries) {
			await db.insert(
				'ejemplo',
				{'seccion': entrada.key, 'ejemplo': entrada.value},
				conflictAlgorithm: ConflictAlgorithm.replace,
			);
		}
		final ahora = DateTime.now().toUtc().toIso8601String();
		await db.insert('tenants', {
			'id': idTenant,
			'nombre': 'ejemplo',
			'contacto': 'ejemplo',
			'email': 'ejemplo',
			'telefono': 'ejemplo',
			'activo': 1,
			'max_usuarios': 15,
			'max_tiendas': 5,
			'notas': 'ejemplo',
			'creado_en': ahora,
			'provisionado_en_hub': 0,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await db.insert('tiendas', {
			'id': idTienda,
			'tenant_id': idTenant,
			'nombre': 'ejemplo',
			'direccion': 'ejemplo',
			'activa': 1,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
		await db.insert('usuarios_bootstrap', {
			'id': idUsuario,
			'tenant_id': idTenant,
			'nombre': 'ejemplo',
			'codigo': '9998',
			'pin_plano': '1234',
			'rol': 'administrador',
			'tienda_id': null,
			'activo': 1,
			'provisionado_en_hub': 0,
		}, conflictAlgorithm: ConflictAlgorithm.ignore);
	}
}
