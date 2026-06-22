/// Repositorio SQLite de configuracion local del dispositivo.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:40:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';
import 'package:sqflite/sqflite.dart';

import '../models/config_dispositivo.dart';
import '../models/config_impresora.dart';

/// Clave de configuracion para URL del hub central.
const String CLAVE_CONFIG_HUB_URL = 'hub_url';

/// Clave de configuracion para clave API del hub.
const String CLAVE_CONFIG_HUB_API_KEY = 'hub_api_key';

/// Clave de configuracion para PIN administrativo.
const String CLAVE_CONFIG_PIN_ADMIN = 'pin_admin';

/// Clave de configuracion para tenant del dispositivo.
const String CLAVE_CONFIG_TENANT_ID = 'tenant_id';

/// Clave de configuracion para tienda activa del dispositivo.
const String CLAVE_CONFIG_TIENDA_ID = 'tienda_id';

/// Clave de configuracion para identificador de caja.
const String CLAVE_CONFIG_CAJA_ID = 'caja_id';

/// Clave de configuracion para nombre legible de caja.
const String CLAVE_CONFIG_CAJA_NOMBRE = 'caja_nombre';

/// Marca que el tecnico completo la instalacion inicial del dispositivo.
const String CLAVE_CONFIG_INSTALACION_COMPLETA = 'instalacion_completada';

/// Clave de modo de impresora (archivo, red, ambos).
const String CLAVE_CONFIG_IMPRESORA_MODO = 'printer_mode';

/// Clave de host de impresora termica.
const String CLAVE_CONFIG_IMPRESORA_HOST = 'printer_host';

/// Clave de puerto de impresora termica.
const String CLAVE_CONFIG_IMPRESORA_PUERTO = 'printer_port';

/// Lee y escribe pares clave-valor en tabla app_config.
class ConfigRepository {
	/// Crea repositorio con conexion SQLite activa.
	///
	/// [baseDatos] Conexion local abierta.
	ConfigRepository({required Database baseDatos}) : _baseDatos = baseDatos;

	final Database _baseDatos;

	/// Obtiene valor de configuracion por clave.
	///
	/// [clave] Clave a consultar.
	/// Retorna valor almacenado o null si no existe.
	Future<String?> obtenerValor(String clave) async {
		final filas = await _baseDatos.query(
			'app_config',
			where: 'clave = ?',
			whereArgs: [clave],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		return filas.first['valor'] as String?;
	}

	/// Guarda valor de configuracion por clave.
	///
	/// [clave] Clave a escribir.
	/// [valor] Valor a persistir.
	Future<void> guardarValor(String clave, String valor) async {
		await _baseDatos.insert(
			'app_config',
			{'clave': clave, 'valor': valor},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	/// Obtiene URL del hub configurada en el dispositivo.
	///
	/// Retorna URL sin barra final o null si no hay hub.
	Future<String?> obtenerHubUrl() async {
		final valor = await obtenerValor(CLAVE_CONFIG_HUB_URL);
		if (valor == null || valor.trim().isEmpty) {
			return null;
		}
		final limpio = valor.trim();
		return limpio.endsWith('/')
			? limpio.substring(0, limpio.length - 1)
			: limpio;
	}

	/// Guarda URL del hub central.
	///
	/// [url] URL base del hub; vacia desactiva sync remoto.
	Future<void> guardarHubUrl(String url) async {
		await guardarValor(CLAVE_CONFIG_HUB_URL, url.trim());
	}

	/// Guarda clave API del hub central.
	Future<void> guardarHubApiKey(String clave) async {
		await guardarValor(CLAVE_CONFIG_HUB_API_KEY, clave.trim());
	}

	/// Lee identidad operativa del dispositivo (vacios hasta aprovisionar o sincronizar).
	Future<ConfigDispositivo> obtenerConfigDispositivo() async {
		final tenantId = await obtenerValor(CLAVE_CONFIG_TENANT_ID);
		final tiendaId = await obtenerValor(CLAVE_CONFIG_TIENDA_ID);
		final cajaId = await obtenerValor(CLAVE_CONFIG_CAJA_ID);
		final nombreCaja = await obtenerValor(CLAVE_CONFIG_CAJA_NOMBRE);
		return ConfigDispositivo(
			tenantId: tenantId ?? '',
			tiendaId: tiendaId ?? '',
			cajaId: cajaId ?? '',
			nombreCaja: nombreCaja,
		);
	}

	/// Persiste tenant, tienda y caja del dispositivo.
	Future<void> guardarConfigDispositivo(ConfigDispositivo config) async {
		await guardarValor(CLAVE_CONFIG_TENANT_ID, config.tenantId);
		await guardarValor(CLAVE_CONFIG_TIENDA_ID, config.tiendaId);
		await guardarValor(CLAVE_CONFIG_CAJA_ID, config.cajaId);
		if (config.nombreCaja != null && config.nombreCaja!.isNotEmpty) {
			await guardarValor(CLAVE_CONFIG_CAJA_NOMBRE, config.nombreCaja!);
		}
	}

	Future<ConfigImpresora> obtenerConfigImpresora() async {
		final modo = await obtenerValor(CLAVE_CONFIG_IMPRESORA_MODO);
		final host = await obtenerValor(CLAVE_CONFIG_IMPRESORA_HOST);
		final puerto = await obtenerValor(CLAVE_CONFIG_IMPRESORA_PUERTO);
		return ConfigImpresora(
			modo: modo ?? 'ambos',
			hostRed: host ?? '',
			puertoRed: int.tryParse(puerto ?? '') ?? 9100,
		);
	}

	Future<void> guardarConfigImpresora(ConfigImpresora config) async {
		await guardarValor(CLAVE_CONFIG_IMPRESORA_MODO, config.modo);
		await guardarValor(CLAVE_CONFIG_IMPRESORA_HOST, config.hostRed);
		await guardarValor(CLAVE_CONFIG_IMPRESORA_PUERTO, config.puertoRed.toString());
	}

	/// Indica si el tecnico ya configuro tenant y conexion al hub.
	Future<bool> esInstalacionCompleta() async {
		final valor = await obtenerValor(CLAVE_CONFIG_INSTALACION_COMPLETA);
		return valor == '1';
	}

	/// Marca la instalacion tecnica como finalizada.
	Future<void> marcarInstalacionCompleta() async {
		await guardarValor(CLAVE_CONFIG_INSTALACION_COMPLETA, '1');
	}

	/// Permite repetir el asistente de instalacion (modo tecnico).
	Future<void> reiniciarInstalacion() async {
		await guardarValor(CLAVE_CONFIG_INSTALACION_COMPLETA, '0');
	}
}
