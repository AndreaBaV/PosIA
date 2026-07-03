/// Aprovisionamiento silencioso del dispositivo en el primer arranque.
library;

import 'package:posia_core/posia_core.dart';
import 'package:uuid/uuid.dart';

import '../models/config_dispositivo.dart';
import '../repositories/config_repository.dart';

/// Configura tenant, hub y caja unica sin intervencion del usuario.
class AprovisionadorDispositivo {
	const AprovisionadorDispositivo._();

	static const _generadorId = Uuid();

	/// Ejecuta una sola vez por instalacion antes de mostrar la UI.
	static Future<void> asegurar(ConfigRepository config) async {
		// Refresca el hub desde el build/env aunque ya este instalado, para que
		// cambiar de proveedor (por ejemplo migrar a un servidor 24/7) o rotar
		// la API key con un nuevo release surta efecto sin re-instalar.
		await _refrescarHubDesdeConfig(config);
		if (await config.esInstalacionCompleta()) {
			return;
		}
		final actual = await config.obtenerConfigDispositivo();
		final cajaId = _resolverCajaUnica(actual.cajaId);
		final nombreCaja = actual.nombreCaja?.trim().isNotEmpty == true
			? actual.nombreCaja
			: 'Caja ${cajaId.substring(0, 8)}';

		await config.guardarConfigDispositivo(
			ConfigDispositivo(
				tiendaId: actual.tiendaId,
				cajaId: cajaId,
				nombreCaja: nombreCaja,
			),
		);

		if (ConfiguracionDespliegue.usaHubEnNube) {
			await config.guardarHubUrl(ConfiguracionDespliegue.hubUrl);
			await config.guardarHubApiKey(ConfiguracionDespliegue.hubApiKey);
			await config.marcarInstalacionCompleta();
		}
	}

	static Future<void> _refrescarHubDesdeConfig(ConfigRepository config) async {
		await refrescarHubConValores(
			config: config,
			urlBuild: ConfiguracionDespliegue.hubUrl,
			claveBuild: ConfiguracionDespliegue.hubApiKey,
		);
	}

	/// Sincroniza URL/clave del hub guardadas con los valores del build.
	///
	/// Solo sobrescribe cuando el build trae valores no vacios: si el APK/IPA
	/// se compilo sin `POSIA_HUB_API_KEY` (o esta se rotó en el servidor y aún
	/// no se recompila), NO se toca la clave guardada. Así un técnico puede
	/// corregirla desde "Configuración técnica" sin que el siguiente arranque
	/// la borre y deje al usuario con "Clave API inválida" para siempre.
	///
	/// Expuesto para pruebas; en producción se invoca via [asegurar] con los
	/// valores de [ConfiguracionDespliegue].
	static Future<void> refrescarHubConValores({
		required ConfigRepository config,
		required String urlBuild,
		required String claveBuild,
	}) async {
		final url = urlBuild.trim().replaceAll(RegExp(r'/+$'), '');
		if (url.isEmpty) {
			return;
		}
		final urlActual = await config.obtenerHubUrl();
		if (urlActual != url) {
			await config.guardarHubUrl(url);
		}
		final clave = claveBuild.trim();
		if (clave.isEmpty) {
			return;
		}
		final claveActual =
			(await config.obtenerValor(claveConfigHubApiKey))?.trim() ?? '';
		if (claveActual != clave) {
			await config.guardarHubApiKey(clave);
		}
	}

	/// Genera UUID de caja si aun no hay identidad unica del dispositivo.
	static String _resolverCajaUnica(String cajaActual) {
		final limpia = cajaActual.trim();
		if (limpia.isNotEmpty) {
			return limpia;
		}
		return _generadorId.v4();
	}
}
