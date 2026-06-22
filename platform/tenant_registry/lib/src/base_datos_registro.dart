/// SQLite local del catalogo maestro de tenants.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'placeholders_registro_tenants.dart';

/// Abre o crea `platform/tenant_registry/data/registro_tenants.db`.
class BaseDatosRegistro {
	BaseDatosRegistro._(this._db);

	final Database _db;

	static const int _version = 2;

	/// Ruta por defecto del archivo de registro.
	static String rutaPorDefecto() {
		final script = Platform.script.toFilePath();
		final paquete = p.dirname(p.dirname(script));
		return p.join(paquete, 'data', 'registro_tenants.db');
	}

	/// Inicializa motor FFI en escritorio y abre la base.
	static Future<BaseDatosRegistro> abrir({String? ruta}) async {
		sqfliteFfiInit();
		databaseFactory = databaseFactoryFfi;
		final archivo = ruta ?? rutaPorDefecto();
		final dir = p.dirname(archivo);
		if (!Directory(dir).existsSync()) {
			Directory(dir).createSync(recursive: true);
		}
		final db = await openDatabase(
			archivo,
			version: _version,
			onCreate: _crearEsquema,
			onUpgrade: _migrarEsquema,
		);
		return BaseDatosRegistro._(db);
	}

	static Future<void> _crearEsquema(Database db, int version) async {
		await db.execute('''
			CREATE TABLE tenants (
				id TEXT PRIMARY KEY,
				nombre TEXT NOT NULL,
				contacto TEXT NOT NULL DEFAULT '',
				email TEXT NOT NULL DEFAULT '',
				telefono TEXT NOT NULL DEFAULT '',
				activo INTEGER NOT NULL DEFAULT 1,
				max_usuarios INTEGER NOT NULL DEFAULT 15,
				max_tiendas INTEGER NOT NULL DEFAULT 5,
				notas TEXT NOT NULL DEFAULT '',
				creado_en TEXT NOT NULL,
				provisionado_en_hub INTEGER NOT NULL DEFAULT 0,
				provisionado_en TEXT
			)
		''');
		await db.execute('''
			CREATE TABLE tiendas (
				id TEXT PRIMARY KEY,
				tenant_id TEXT NOT NULL,
				nombre TEXT NOT NULL,
				direccion TEXT NOT NULL DEFAULT '',
				activa INTEGER NOT NULL DEFAULT 1,
				FOREIGN KEY (tenant_id) REFERENCES tenants(id)
			)
		''');
		await db.execute('''
			CREATE INDEX idx_tiendas_tenant ON tiendas(tenant_id)
		''');
		await db.execute('''
			CREATE TABLE usuarios_bootstrap (
				id TEXT PRIMARY KEY,
				tenant_id TEXT NOT NULL,
				nombre TEXT NOT NULL,
				codigo TEXT NOT NULL,
				pin_plano TEXT NOT NULL,
				rol TEXT NOT NULL DEFAULT 'administrador',
				tienda_id TEXT,
				activo INTEGER NOT NULL DEFAULT 1,
				provisionado_en_hub INTEGER NOT NULL DEFAULT 0,
				UNIQUE (codigo),
				FOREIGN KEY (tenant_id) REFERENCES tenants(id)
			)
		''');
		await db.execute('''
			CREATE INDEX idx_usuarios_tenant ON usuarios_bootstrap(tenant_id)
		''');
		await PlaceholdersRegistroTenants.insertarTodo(db);
	}

	static Future<void> _migrarEsquema(
		Database db,
		int anterior,
		int nueva,
	) async {
		if (anterior < 2 && nueva >= 2) {
			await PlaceholdersRegistroTenants.insertarTodo(db);
		}
	}

	Database get conexion => _db;

	Future<void> cerrar() => _db.close();
}
