/* Redondeo y formato de MXN. Espejo de posia_core/lib/src/utils/moneda_util.dart
   para que el ticket web y el del POS den el mismo importe.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

/** Redondea a dos decimales half-up, igual que `redondearMonto` en Dart. */
export function redondearMonto(monto) {
	const escalado = monto * 100 + 1e-9;
	return Math.round(escalado) / 100;
}

/** Formatea como cadena de pesos con dos decimales. */
export function formatearMoneda(monto) {
	return `$${redondearMonto(monto).toFixed(2)}`;
}

/** Cantidad sin ceros de relleno: 2 en vez de 2.000, 1.5 en vez de 1.500. */
export function numeroCorto(valor) {
	if (Number.isInteger(valor)) {
		return String(valor);
	}
	return String(Math.round(valor * 1000) / 1000);
}
