/// Validador de licencia perpetua offline.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import 'package:posia_core/posia_core.dart';

import 'licencia.dart';

/// Resultado de validacion de licencia.
enum ResultadoValidacionLicencia {
	/// Licencia valida para operacion.
	valida,

	/// Licencia expirada o invalida.
	invalida,

	/// Modulo solicitado no incluido en licencia.
	moduloNoAutorizado,
}

/// Evalua reglas de licencia perpetua en tiempo de ejecucion.
class ValidadorLicencia {
	/// Crea validador con licencia activa cargada.
	///
	/// [licencia] Licencia instalada en dispositivo.
	ValidadorLicencia({required Licencia licencia}) : _licencia = licencia;

	final Licencia _licencia;

	/// Obtiene licencia activa en memoria.
	///
	/// Retorna instancia de [Licencia].
	Licencia obtenerLicencia() {
		return _licencia;
	}

	/// Valida que la licencia permita operacion general.
	///
	/// Retorna [ResultadoValidacionLicencia.valida] si tenantId no es vacio.
	ResultadoValidacionLicencia validarOperacion() {
		if (_licencia.tenantId.isEmpty) {
			return ResultadoValidacionLicencia.invalida;
		}
		return ResultadoValidacionLicencia.valida;
	}

	/// Valida acceso a modulo comercial especifico.
	///
	/// [modulo] Modulo solicitado por funcionalidad.
	/// Retorna resultado de autorizacion del modulo.
	ResultadoValidacionLicencia validarModulo(ModuloLicencia modulo) {
		final operacion = validarOperacion();
		if (operacion != ResultadoValidacionLicencia.valida) {
			return operacion;
		}
		if (!_licencia.tieneModulo(modulo)) {
			return ResultadoValidacionLicencia.moduloNoAutorizado;
		}
		return ResultadoValidacionLicencia.valida;
	}

	/// Valida limite de tiendas contra conteo actual.
	///
	/// [tiendasActivas] Numero de tiendas configuradas.
	/// Retorna verdadero si no excede limite licenciado.
	bool validarLimiteTiendas(int tiendasActivas) {
		return tiendasActivas <= _licencia.maxTiendas;
	}

	/// Valida limite de cajas contra conteo actual.
	///
	/// [cajasActivas] Numero de cajas configuradas.
	/// Retorna verdadero si no excede limite licenciado.
	bool validarLimiteCajas(int cajasActivas) {
		return cajasActivas <= _licencia.maxCajas;
	}
}
