/// Configuracion del dispositivo (hub, caja) sin depender del tenant activo.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';

import '../bootstrap/aprovisionador_offline.dart';
import '../repositories/config_repository.dart';

/// Opera sobre la base SQLite del dispositivo antes o despues del login.
class ServicioConfiguracionDispositivo {
	ServicioConfiguracionDispositivo({required ConfigRepository config})
		: _config = config;

	final ConfigRepository _config;

	Future<String?> obtenerHubUrl() => _config.obtenerHubUrl();

	Future<String> obtenerHubApiKey() async {
		return (await _config.obtenerValor(claveConfigHubApiKey)) ?? '';
	}

	/// Guarda URL y clave del hub; no modifica el tenant (se resuelve al login).
	Future<bool> guardarConexionHub({
		String hubUrl = '',
		String hubApiKey = '',
		bool soloOffline = false,
		String pinTecnico = '',
		String nombreNegocio = '',
		String nombreTienda = '',
		String nombreAdmin = '',
		String codigoAdmin = '',
		String pinAdmin = '',
	}) async {
		final usarHub = !soloOffline && hubUrl.trim().isNotEmpty;
		if (!usarHub) {
			await _config.guardarHubUrl('');
			await _config.guardarHubApiKey('');
			final actual = await _config.obtenerConfigDispositivo();
			if (actual.tiendaId.isEmpty && pinAdmin.trim().length == LONGITUD_PIN_ADMIN) {
				await AprovisionadorOffline.aprovisionar(
					config: _config,
					nombreNegocio: nombreNegocio,
					nombreTienda: nombreTienda,
					nombreAdmin: nombreAdmin,
					codigoAdmin: codigoAdmin.isEmpty ? '1001' : codigoAdmin,
					pinAdmin: pinAdmin,
				);
			}
		} else {
			final url = hubUrl.trim().replaceAll(RegExp(r'/+$'), '');
			final clave = hubApiKey.trim();
			final cliente = HubSyncClient(urlBase: url, claveApi: clave);
			final responde = await cliente.mantenerHubVivo();
			if (!responde) {
				throw StateError(
					'No se pudo conectar a $url. Verifique la URL (sin barra final), '
					'que el servidor esté desplegado y espere ~1 min si usa Render gratuito.',
				);
			}
			await _config.guardarHubUrl(url);
			await _config.guardarHubApiKey(clave);
		}
		final pin = pinTecnico.trim();
		if (pin.isNotEmpty) {
			if (pin.length != LONGITUD_PIN_ADMIN) {
				throw StateError('El PIN técnico debe tener $LONGITUD_PIN_ADMIN dígitos');
			}
			await _config.guardarValor(claveConfigPinAdmin, pin);
		}
		await _config.marcarInstalacionCompleta();
		return usarHub;
	}
}
