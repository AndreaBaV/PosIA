/// Inicializacion de servicios locales offline de POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

/// Prepara motor SQLite y datos iniciales antes de mostrar caja.
class InicializadorApp {
	InicializadorApp._();

	static bool _preparado = false;

	/// Ejecuta inicializacion idempotente de base de datos.
	static Future<void> preparar() async {
		if (_preparado) {
			return;
		}
		await ConfiguracionEntorno.cargar();
		await PosiaLocalDatabase.inicializarMotor();
		final gestor = PosiaLocalDatabase.obtenerInstancia();
		final base = await gestor.obtenerBaseDatosDispositivo();
		await AprovisionadorDispositivo.asegurar(ConfigRepository(baseDatos: base));
		_preparado = true;
	}
}
