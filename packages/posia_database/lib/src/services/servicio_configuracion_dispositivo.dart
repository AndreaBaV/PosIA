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

	/// Prueba URL + clave sin guardar. Timeout largo para despertar hub suspendido.
	Future<DiagnosticoConexionHub> probarConexionHub({
		required String hubUrl,
		String hubApiKey = '',
	}) async {
		final url = hubUrl.trim().replaceAll(RegExp(r'/+$'), '');
		if (url.isEmpty) {
			return const DiagnosticoConexionHub(
				url: '',
				exitoso: false,
				detalle: 'Ingresa la URL del hub.',
			);
		}
		final cliente = HubSyncClient(urlBase: url, claveApi: hubApiKey.trim());
		return cliente.diagnosticarConexion();
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
			final diagnostico = await cliente.diagnosticarConexion();
			if (!diagnostico.exitoso) {
				throw StateError(diagnostico.mensajeUsuario);
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
