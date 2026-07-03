/// Limpieza de SQLite y credenciales locales cuando el build lo solicita.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import '../services/gestor_acceso_biometrico.dart';

/// Borra el almacen local una vez por [ConfiguracionDespliegue.buildId].
class LimpiadorCacheLocal {
	LimpiadorCacheLocal._();

	static const _archivoMarcador = '.posia_cache_wipe_marker';

	/// Devuelve true si se eliminaron datos locales en este arranque.
	static Future<bool> aplicarSiCorresponde() async {
		if (!ConfiguracionDespliegue.limpiarCacheLocal) {
			return false;
		}
		final buildId = ConfiguracionDespliegue.buildId.isEmpty
			? 'dev'
			: ConfiguracionDespliegue.buildId;
		final directorio = await getApplicationDocumentsDirectory();
		final marcador = File('${directorio.path}/$_archivoMarcador');
		if (await marcador.exists()) {
			final previo = (await marcador.readAsString()).trim();
			if (previo == buildId) {
				return false;
			}
		}
		await PosiaLocalDatabase.inicializarMotor();
		await PosiaLocalDatabase.obtenerInstancia().reiniciarAlmacenLocalCompleto();
		await GestorAccesoBiometrico().limpiarAlmacen();
		await marcador.writeAsString(buildId);
		return true;
	}
}
