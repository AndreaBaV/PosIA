/// Gestor SQLite: dispositivo (config) + una base operativa por tenant.
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import 'migraciones_esquema.dart';
import '../seed/placeholders_ejemplo.dart';
import 'motor_sqlite_nativo.dart'
	if (dart.library.js_interop) 'motor_sqlite_web.dart' as motor_sqlite;

/// Abre la base del dispositivo y bases aisladas por tenant.
class PosiaLocalDatabase {
	PosiaLocalDatabase._();

	static PosiaLocalDatabase? _instancia;
	static Database? _baseDispositivo;
	static Database? _baseTenant;
	static String? _tenantActivo;

	static const String _archivoDispositivo = 'posia_dispositivo.db';

	/// Obtiene instancia singleton del gestor de base de datos.
	static PosiaLocalDatabase obtenerInstancia() {
		_instancia ??= PosiaLocalDatabase._();
		return _instancia!;
	}

	/// Inicializa motor SQLite segun plataforma.
	static Future<void> inicializarMotor() async {
		await motor_sqlite.inicializarMotorSqlite();
	}

	/// Base con `app_config` (caja, hub, ultimo tenant).
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

	/// Base operativa del tenant activo (catalogo, ventas, usuarios locales).
	Future<Database> obtenerBaseDatos() async {
		final tenant = _tenantActivo;
		if (tenant == null || tenant.isEmpty) {
			throw StateError('No hay tenant activo. Inicie sesion primero.');
		}
		return _abrirBaseTenant(tenant);
	}

	/// Tenant actualmente cargado en memoria.
	String? get tenantActivo => _tenantActivo;

	/// Cambia a la base SQLite del tenant indicado.
	Future<void> establecerTenant(String tenantId) async {
		final limpio = tenantId.trim();
		if (limpio.isEmpty) {
			throw StateError('Tenant ID invalido');
		}
		if (_tenantActivo == limpio && _baseTenant != null) {
			return;
		}
		if (_baseTenant != null) {
			await _baseTenant!.close();
			_baseTenant = null;
		}
		_tenantActivo = limpio;
		await _abrirBaseTenant(limpio);
	}

	/// Cierra la base del tenant (p. ej. al cerrar sesion).
	Future<void> liberarTenant() async {
		if (_baseTenant != null) {
			await _baseTenant!.close();
			_baseTenant = null;
		}
		_tenantActivo = null;
	}

	Future<Database> _abrirBaseTenant(String tenantId) async {
		final existente = _baseTenant;
		if (existente != null && _tenantActivo == tenantId) {
			return existente;
		}
		final ruta = await motor_sqlite.resolverRutaBaseDatos(_archivoTenant(tenantId));
		final base = await openDatabase(
			ruta,
			version: SCHEMA_VERSION,
			onCreate: _crearEsquemaTenant,
			onUpgrade: _migrarEsquemaTenant,
		);
		_baseTenant = base;
		return base;
	}

	static String _archivoTenant(String tenantId) {
		final seguro = tenantId.replaceAll(RegExp(r'[^\w\-.]'), '_');
		return 'posia_t_$seguro.db';
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
	}
}
