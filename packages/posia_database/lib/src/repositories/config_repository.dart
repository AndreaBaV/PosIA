/// Repositorio SQLite de configuracion local del dispositivo.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-11 15:40:00 (UTC-6)
/// Ultima modificacion: 2026-06-11 15:40:00 (UTC-6)
library;

import 'package:sqflite/sqflite.dart';

import '../models/config_dispositivo.dart';
import '../models/config_impresora.dart';

/// Clave de configuracion para URL del hub central.
const String claveConfigHubUrl = 'hub_url';

/// Clave de configuracion para clave API del hub.
const String claveConfigHubApiKey = 'hub_api_key';

/// Clave de configuracion para PIN administrativo.
const String claveConfigPinAdmin = 'pin_admin';

/// Clave de configuracion para tenant del dispositivo.
const String claveConfigTenantId = 'tenant_id';

/// Clave de configuracion para tienda activa del dispositivo.
const String claveConfigTiendaId = 'tienda_id';

/// Clave de configuracion para identificador de caja.
const String claveConfigCajaId = 'caja_id';

/// Clave de configuracion para nombre legible de caja.
const String claveConfigCajaNombre = 'caja_nombre';

/// Marca que el tecnico completo la instalacion inicial del dispositivo.
const String claveConfigInstalacionCompleta = 'instalacion_completada';

/// Ultimo usuario que inicio sesion (para restaurar sin volver a autenticar).
const String claveConfigUltimoUsuarioId = 'ultimo_usuario_id';

/// Clave de modo de impresora (archivo, red, ambos).
const String claveConfigImpresoraModo = 'printer_mode';

/// Clave de host de impresora termica.
const String claveConfigImpresoraHost = 'printer_host';

/// Clave de puerto de impresora termica.
const String claveConfigImpresoraPuerto = 'printer_port';

/// Abrir cajon al cobrar en efectivo.
const String claveConfigCajonAbrir = 'cash_drawer_open';

/// Tecla de acceso rapido para cobrar (ej. F12, Enter con modificador).
const String claveConfigTeclaCobrar = 'tecla_cobrar';

/// Mapa JSON de atajos de caja (cobrar, creditos, admin, etc.).
const String claveConfigAtajosCaja = 'atajos_caja';

/// Ancho etiqueta producto en mm.
const String claveConfigEtiquetaAnchoMm = 'etiqueta_ancho_mm';

/// Alto etiqueta producto en mm.
const String claveConfigEtiquetaAltoMm = 'etiqueta_alto_mm';

/// Carpeta donde se guardan los PDF de etiquetas de producto.
const String claveConfigEtiquetasCarpeta = 'etiquetas_carpeta';

/// Tecla de cobro por defecto si no hay configuracion.
const String teclaCobrarConfigPredeterminada = 'F2';

/// Ancho de etiqueta por defecto (mm).
const double etiquetaAnchoMmPredeterminado = 50.0;

/// Alto de etiqueta por defecto (mm).
const double etiquetaAltoMmPredeterminado = 30.0;

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
		final valor = await obtenerValor(claveConfigHubUrl);
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
		await guardarValor(claveConfigHubUrl, url.trim());
	}

	/// Guarda clave API del hub central.
	Future<void> guardarHubApiKey(String clave) async {
		await guardarValor(claveConfigHubApiKey, clave.trim());
	}

	/// Lee identidad operativa del dispositivo (vacios hasta aprovisionar o sincronizar).
	Future<ConfigDispositivo> obtenerConfigDispositivo() async {
		final tenantId = await obtenerValor(claveConfigTenantId);
		final tiendaId = await obtenerValor(claveConfigTiendaId);
		final cajaId = await obtenerValor(claveConfigCajaId);
		final nombreCaja = await obtenerValor(claveConfigCajaNombre);
		return ConfigDispositivo(
			tenantId: tenantId ?? '',
			tiendaId: tiendaId ?? '',
			cajaId: cajaId ?? '',
			nombreCaja: nombreCaja,
		);
	}

	/// Persiste tenant, tienda y caja del dispositivo.
	Future<void> guardarConfigDispositivo(ConfigDispositivo config) async {
		await guardarValor(claveConfigTenantId, config.tenantId);
		await guardarValor(claveConfigTiendaId, config.tiendaId);
		await guardarValor(claveConfigCajaId, config.cajaId);
		if (config.nombreCaja != null && config.nombreCaja!.isNotEmpty) {
			await guardarValor(claveConfigCajaNombre, config.nombreCaja!);
		}
	}

	Future<ConfigImpresora> obtenerConfigImpresora() async {
		final modo = await obtenerValor(claveConfigImpresoraModo);
		final host = await obtenerValor(claveConfigImpresoraHost);
		final puerto = await obtenerValor(claveConfigImpresoraPuerto);
		final abrirCajon = await obtenerValor(claveConfigCajonAbrir);
		return ConfigImpresora(
			modo: modo ?? 'ambos',
			hostRed: host ?? '',
			puertoRed: int.tryParse(puerto ?? '') ?? 9100,
			abrirCajonAlCobrar: abrirCajon == '1',
		);
	}

	Future<void> guardarConfigImpresora(ConfigImpresora config) async {
		await guardarValor(claveConfigImpresoraModo, config.modo);
		await guardarValor(claveConfigImpresoraHost, config.hostRed);
		await guardarValor(claveConfigImpresoraPuerto, config.puertoRed.toString());
		await guardarValor(
			claveConfigCajonAbrir,
			config.abrirCajonAlCobrar ? '1' : '0',
		);
	}

	/// Indica si el tecnico ya configuro tenant y conexion al hub.
	Future<bool> esInstalacionCompleta() async {
		final valor = await obtenerValor(claveConfigInstalacionCompleta);
		return valor == '1';
	}

	/// Marca la instalacion tecnica como finalizada.
	Future<void> marcarInstalacionCompleta() async {
		await guardarValor(claveConfigInstalacionCompleta, '1');
	}

	/// Permite repetir el asistente de instalacion (modo tecnico).
	Future<void> reiniciarInstalacion() async {
		await guardarValor(claveConfigInstalacionCompleta, '0');
	}
}
