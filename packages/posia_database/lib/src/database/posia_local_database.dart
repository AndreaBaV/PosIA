/// Gestor SQLite: dispositivo (config) + base operativa unica por instalacion.
library;

import 'dart:io';

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import 'migraciones_esquema.dart';
import '../seed/placeholders_ejemplo.dart';
import 'motor_sqlite_nativo.dart'
	if (dart.library.js_interop) 'motor_sqlite_web.dart' as motor_sqlite;

/// Abre la base del dispositivo y la base operativa unica.
class PosiaLocalDatabase {
	PosiaLocalDatabase._();

	static PosiaLocalDatabase? _instancia;
	static Database? _baseDispositivo;
	static Database? _baseOperativa;

	static const String _archivoDispositivo = 'posia_dispositivo.db';
	static const String _archivoOperativa = 'posia_operativa.db';

	static PosiaLocalDatabase obtenerInstancia() {
		_instancia ??= PosiaLocalDatabase._();
		return _instancia!;
	}

	static Future<void> inicializarMotor() async {
		await motor_sqlite.inicializarMotorSqlite();
	}

	Future<Database> obtenerBaseDatosDispositivo() async {
		final existente = _baseDispositivo;
		if (existente != null) {
			return existente;
		}
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoDispositivo);
		final base = await openDatabase(
			ruta,
			version: 2,
			onCreate: MigracionesEsquema.crearEsquemaDispositivo,
			onUpgrade: (base, anterior, nueva) async {
				if (anterior < 2 && nueva >= 2) {
					await PlaceholdersEjemplo.insertarGuiaDispositivo(base);
				}
			},
		);
		_baseDispositivo = base;
		return base;
	}

	Future<Database> obtenerBaseDatos() async {
		return _abrirBaseOperativa();
	}

	Future<void> cerrarBaseOperativa() async {
		if (_baseOperativa != null) {
			await _baseOperativa!.close();
			_baseOperativa = null;
		}
	}

	/// Elimina el archivo SQLite operativo; se recrea vacio en el siguiente acceso.
	Future<void> reiniciarBaseOperativa() async {
		await cerrarBaseOperativa();
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoOperativa);
		final archivo = File(ruta);
		if (await archivo.exists()) {
			await archivo.delete();
		}
	}

	Future<Database> _abrirBaseOperativa() async {
		final existente = _baseOperativa;
		if (existente != null) {
			return existente;
		}
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoOperativa);
		final base = await openDatabase(
			ruta,
			version: SCHEMA_VERSION,
			onCreate: _crearEsquemaTenant,
			onUpgrade: _migrarEsquemaTenant,
		);
		_baseOperativa = base;
		return base;
	}

	Future<void> _crearEsquemaTenant(Database base, int version) async {
		await MigracionesEsquema.crearEsquemaCompleto(base);
	}

	Future<void> _migrarEsquemaTenant(
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
		if (versionAnterior < 6 && versionNueva >= 6) {
			await MigracionesEsquema.migrarVersion5A6(base);
		}
		if (versionAnterior < 7 && versionNueva >= 7) {
			await MigracionesEsquema.migrarVersion6A7(base);
		}
		if (versionAnterior < 8 && versionNueva >= 8) {
			await MigracionesEsquema.migrarVersion7A8(base);
		}
		if (versionAnterior < 9 && versionNueva >= 9) {
			await MigracionesEsquema.migrarVersion8A9(base);
		}
		if (versionAnterior < 10 && versionNueva >= 10) {
			await MigracionesEsquema.migrarVersion9A10(base);
		}
		if (versionAnterior < 11 && versionNueva >= 11) {
			await MigracionesEsquema.migrarVersion10A11(base);
		}
		if (versionAnterior < 12 && versionNueva >= 12) {
			await MigracionesEsquema.migrarVersion11A12(base);
		}
		if (versionAnterior < 13 && versionNueva >= 13) {
			await MigracionesEsquema.migrarVersion12A13(base);
		}
		if (versionAnterior < 14 && versionNueva >= 14) {
			await MigracionesEsquema.migrarVersion13A14(base);
		}
		if (versionAnterior < 15 && versionNueva >= 15) {
			await MigracionesEsquema.migrarVersion14A15(base);
		}
		if (versionAnterior < 16 && versionNueva >= 16) {
			await MigracionesEsquema.migrarVersion15A16(base);
		}
		if (versionAnterior < 17 && versionNueva >= 17) {
			await MigracionesEsquema.migrarVersion16A17(base);
		}
		if (versionAnterior < 18 && versionNueva >= 18) {
			await MigracionesEsquema.migrarVersion17A18(base);
		}
		if (versionAnterior < 19 && versionNueva >= 19) {
			await MigracionesEsquema.migrarVersion18A19(base);
		}
		if (versionAnterior < 20 && versionNueva >= 20) {
			await MigracionesEsquema.migrarVersion19A20(base);
		}
		if (versionAnterior < 21 && versionNueva >= 21) {
			await MigracionesEsquema.migrarVersion20A21(base);
		}
		if (versionAnterior < 22 && versionNueva >= 22) {
			await MigracionesEsquema.migrarVersion21A22(base);
		}
	}
}
