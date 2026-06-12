/// Modelo de licencia perpetua POSIA.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

/// Representa derechos comerciales otorgados al cliente.
class Licencia {
	/// Crea licencia con limites y modulos activos.
	///
	/// [tenantId] Identificador del cliente.
	/// [modulos] Modulos habilitados.
	/// [maxTiendas] Numero maximo de sucursales.
	/// [maxCajas] Numero maximo de cajas registradoras.
	/// [soporteExpiraEn] Fecha limite de soporte y sync incluido.
	const Licencia({
		required this.tenantId,
		required this.modulos,
		required this.maxTiendas,
		required this.maxCajas,
		required this.soporteExpiraEn,
	});

	/// Identificador del tenant licenciado.
	final String tenantId;

	/// Modulos comerciales activos.
	final List<ModuloLicencia> modulos;

	/// Limite de tiendas permitidas.
	final int maxTiendas;

	/// Limite de cajas permitidas.
	final int maxCajas;

	/// Fecha de expiracion de soporte anual.
	final DateTime soporteExpiraEn;

	/// Indica si un modulo esta habilitado en licencia.
	///
	/// [modulo] Modulo consultado.
	/// Retorna verdadero si el modulo esta activo.
	bool tieneModulo(ModuloLicencia modulo) {
		return modulos.contains(modulo);
	}

	/// Indica si el periodo de soporte sigue vigente.
	///
	/// Retorna verdadero si la fecha actual es anterior a expiracion.
	bool soporteVigente() {
		final ahora = DateTime.now().toUtc();
		return ahora.isBefore(soporteExpiraEn);
	}
}
