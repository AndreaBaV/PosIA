/// Utilidades de formato y redondeo para MXN.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

import '../constants/posia_constants.dart';

/// Redondea un monto a dos decimales usando half-up.
///
/// [monto] Valor en pesos mexicanos sin redondear.
/// Retorna el monto redondeado a [DECIMALES_MONEDA] decimales.
double redondearMonto(double monto) {
	final factor = _calcularFactorRedondeo();
	final epsilon = 1e-9;
	final escalado = monto * factor + epsilon;
	final redondeado = escalado.roundToDouble();
	return redondeado / factor;
}

/// Formatea un monto como cadena de moneda MXN.
///
/// [monto] Valor numerico a formatear.
/// Retorna cadena con simbolo de pesos y dos decimales.
String formatearMoneda(double monto) {
	final valorRedondeado = redondearMonto(monto);
	return '\$${valorRedondeado.toStringAsFixed(DECIMALES_MONEDA)}';
}

/// Calcula el factor multiplicador para redondeo half-up.
///
/// Retorna 10 elevado a [DECIMALES_MONEDA].
double _calcularFactorRedondeo() {
	var factor = 1.0;
	var contador = 0;
	while (contador < DECIMALES_MONEDA) {
		factor = factor * 10.0;
		contador = contador + 1;
	}
	return factor;
}
