/// Gestor SQLite: dispositivo (config) + base operativa unica por instalacion.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import 'conexion_operativa_ruteada.dart';
import 'migraciones_esquema.dart';
import '../seed/placeholders_ejemplo.dart';
import 'motor_sqlite_nativo.dart'
	if (dart.library.js_interop) 'motor_sqlite_web.dart' as motor_sqlite;

/// Abre la base del dispositivo y la base operativa unica.
class PosiaLocalDatabase {
	PosiaLocalDatabase._();

	static PosiaLocalDatabase? _instancia;
	static Database? _baseDispositivo;
	/// Conexion de escritura (unica que ejecuta migraciones y mutaciones).
	static Database? _baseOperativa;
	/// Conexion de solo-lectura para snapshots WAL concurrentes.
	static Database? _baseOperativaLectura;
	/// Envoltorio que enruta lecturas/escrituras a la conexion adecuada.
	static Database? _baseOperativaRuteada;

	static const String _archivoDispositivo = 'posia_dispositivo.db';
	static const String _archivoOperativa = 'posia_operativa.db';
	static const int _timeoutOcupadoMs = 5000;

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
		final ruteada = _baseOperativaRuteada;
		if (ruteada != null) {
			return ruteada;
		}
		return _abrirBaseOperativa();
	}

	Future<void> cerrarBaseOperativa() async {
		_baseOperativaRuteada = null;
		if (_baseOperativaLectura != null) {
			await _baseOperativaLectura!.close();
			_baseOperativaLectura = null;
		}
		if (_baseOperativa != null) {
			await _baseOperativa!.close();
			_baseOperativa = null;
		}
	}

	/// Elimina el archivo SQLite operativo; se recrea vacio en el siguiente acceso.
	Future<void> reiniciarBaseOperativa() async {
		await cerrarBaseOperativa();
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoOperativa);
		// deleteDatabase elimina tambien los archivos -wal y -shm de WAL.
		await deleteDatabase(ruta);
	}

	/// Elimina la base de configuracion del dispositivo (hub, caja, sesion).
	Future<void> reiniciarBaseDispositivo() async {
		if (_baseDispositivo != null) {
			await _baseDispositivo!.close();
			_baseDispositivo = null;
		}
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoDispositivo);
		await deleteDatabase(ruta);
	}

	/// Borra ambas bases SQLite locales (instalacion en blanco).
	Future<void> reiniciarAlmacenLocalCompleto() async {
		await reiniciarBaseOperativa();
		await reiniciarBaseDispositivo();
	}

	Future<Database> _abrirBaseOperativa() async {
		final existente = _baseOperativaRuteada;
		if (existente != null) {
			return existente;
		}
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoOperativa);
		final escritura = await openDatabase(
			ruta,
			version: SCHEMA_VERSION,
			onConfigure: _configurarConexionEscritura,
			onCreate: _crearEsquemaTenant,
			onUpgrade: _migrarEsquemaTenant,
		);
		_baseOperativa = escritura;
		final lectura = await _abrirConexionLectura(ruta);
		final ruteada = ConexionOperativaRuteada(
			escritura: escritura,
			lectura: lectura ?? escritura,
		);
		_baseOperativaRuteada = ruteada;
		return ruteada;
	}

	/// Activa WAL para que lectores y escritor operen sin bloquearse, con
	/// synchronous=NORMAL (seguro bajo WAL) para minimizar fsync por escritura.
	Future<void> _configurarConexionEscritura(Database db) async {
		await db.rawQuery('PRAGMA journal_mode=WAL');
		await db.execute('PRAGMA synchronous=NORMAL');
		await db.rawQuery('PRAGMA busy_timeout=$_timeoutOcupadoMs');
	}

	/// Abre una conexion de solo-lectura independiente (snapshots WAL).
	///
	/// Si la plataforma no soporta multiples conexiones (p. ej. web), retorna
	/// null y se reutiliza la conexion de escritura para leer (sin regresion).
	Future<Database?> _abrirConexionLectura(String ruta) async {
		try {
			final lectura = await openDatabase(
				ruta,
				readOnly: true,
				singleInstance: false,
			);
			// onConfigure se ignora en readOnly; busy_timeout es ajuste de
			// conexion (no escritura) y si es valido en solo-lectura.
			await lectura.rawQuery('PRAGMA busy_timeout=$_timeoutOcupadoMs');
			_baseOperativaLectura = lectura;
			return lectura;
		} on Object {
			return null;
		}
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
		if (versionAnterior < 23 && versionNueva >= 23) {
			await MigracionesEsquema.migrarVersion22A23(base);
		}
		if (versionAnterior < 24 && versionNueva >= 24) {
			await MigracionesEsquema.migrarVersion23A24(base);
		}
		if (versionAnterior < 25 && versionNueva >= 25) {
			await MigracionesEsquema.migrarVersion24A25(base);
		}
		if (versionAnterior < 26 && versionNueva >= 26) {
			await MigracionesEsquema.migrarVersion25A26(base);
		}
		if (versionAnterior < 27 && versionNueva >= 27) {
			await MigracionesEsquema.migrarVersion26A27(base);
		}
		if (versionAnterior < 28 && versionNueva >= 28) {
			await MigracionesEsquema.migrarVersion27A28(base);
		}
	}
}
