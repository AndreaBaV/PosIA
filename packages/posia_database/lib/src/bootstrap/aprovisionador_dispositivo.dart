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
				tenantId: actual.tenantId,
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

	/// Genera UUID de caja si aun no hay identidad unica del dispositivo.
	static String _resolverCajaUnica(String cajaActual) {
		final limpia = cajaActual.trim();
		if (limpia.isNotEmpty) {
			return limpia;
		}
		return _generadorId.v4();
	}
}
