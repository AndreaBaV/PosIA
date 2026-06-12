/// Gestor SQLite local offline-first para POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 22:00:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import 'migraciones_esquema.dart';
import 'motor_sqlite_nativo.dart'
	if (dart.library.js_interop) 'motor_sqlite_web.dart' as motor_sqlite;

/// Abre y migra la base SQLite local de la caja.
class PosiaLocalDatabase {
	PosiaLocalDatabase._();

	static PosiaLocalDatabase? _instancia;
	static Database? _baseDatos;

	/// Obtiene instancia singleton del gestor de base de datos.
	///
	/// Retorna instancia unica de [PosiaLocalDatabase].
	static PosiaLocalDatabase obtenerInstancia() {
		_instancia ??= PosiaLocalDatabase._();
		return _instancia!;
	}

	/// Inicializa motor SQLite segun plataforma.
	///
	/// Debe invocarse antes de [obtenerBaseDatos].
	static Future<void> inicializarMotor() async {
		await motor_sqlite.inicializarMotorSqlite();
	}

	/// Obtiene conexion SQLite abierta y migrada.
	///
	/// Retorna instancia activa de [Database].
	Future<Database> obtenerBaseDatos() async {
		final baseExistente = _baseDatos;
		if (baseExistente != null) {
			return baseExistente;
		}
		final ruta = await _resolverRutaArchivo();
		final base = await openDatabase(
			ruta,
			version: SCHEMA_VERSION,
			onCreate: _crearEsquema,
			onUpgrade: _migrarEsquema,
		);
		_baseDatos = base;
		return base;
	}

	/// Resuelve ruta del archivo posia_local.db.
	///
	/// Retorna ruta o identificador segun plataforma.
	Future<String> _resolverRutaArchivo() async {
		return motor_sqlite.resolverRutaBaseDatos('posia_local.db');
	}

	/// Crea esquema inicial version 1.
	///
	/// [base] Conexion recien abierta.
	/// [version] Version de esquema solicitada.
	Future<void> _crearEsquema(Database base, int version) async {
		await MigracionesEsquema.crearEsquemaCompleto(base);
	}

	/// Aplica migraciones incrementales de esquema.
	///
	/// [base] Conexion activa.
	/// [versionAnterior] Version previa instalada.
	/// [versionNueva] Version objetivo.
	Future<void> _migrarEsquema(
		Database base,
		int versionAnterior,
		int versionNueva,
	) async {
		if (versionAnterior >= versionNueva) {
			return;
		}
		if (versionAnterior < 2 && versionNueva >= 2) {
			await MigracionesEsquema.migrarVersion1A2(base);
		}
		if (versionAnterior < 3 && versionNueva >= 3) {
			await MigracionesEsquema.migrarVersion2A3(base);
		}
		if (versionAnterior < 4 && versionNueva >= 4) {
			await MigracionesEsquema.migrarVersion3A4(base);
		}
		if (versionAnterior < 5 && versionNueva >= 5) {
			await MigracionesEsquema.migrarVersion4A5(base);
		}
	}
}
