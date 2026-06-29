/// Valida reglas de licencia perpetua en tiempo de ejecucion.
library;

import 'package:posia_core/posia_core.dart';

import 'licencia.dart';

enum ResultadoValidacionLicencia {
	valida,
	invalida,
	moduloNoAutorizado,
}

class ValidadorLicencia {
	ValidadorLicencia({required Licencia licencia}) : _licencia = licencia;

	final Licencia _licencia;

	Licencia obtenerLicencia() => _licencia;

	ResultadoValidacionLicencia validarOperacion() {
		return ResultadoValidacionLicencia.valida;
	}

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
}
