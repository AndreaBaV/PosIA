/* Escalas de precio por cantidad (mayoreo y cortes por peso).

   Espejo de `seleccionarEscalaMayoreoPorCantidad` /
   `resolverPrecioConEscalas` en
   packages/posia_core/lib/src/utils/precio_util.dart.

   Los tramos viven en Neon (`wholesale_tiers`) como $/unidad base
   (para granel, $/kg). Ejemplo típico de carnicería:
     0 kg → $88/kg (cubre cuarto y fracciones menores)
     0.5 kg → $40/kg (medio kilo)
     1 kg → $30/kg (precio de kilo completo)

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { redondearMonto } from './dinero.js';

/**
 * Escala con mayor `cantidadMinima` que califica para [cantidad].
 *
 * Misma regla que el POS: umbral inclusivo (`cantidad >= cantidadMinima`).
 */
export function seleccionarEscalaPorCantidad(escalas, cantidad) {
	let mejor = null;
	for (const escala of escalas ?? []) {
		const umbral = Number(escala.cantidadMinima);
		const precio = Number(escala.precioUnitario);
		if (!(cantidad >= umbral) || !(precio > 0)) {
			continue;
		}
		if (!mejor || umbral > Number(mejor.cantidadMinima)) {
			mejor = escala;
		}
	}
	return mejor;
}

/** Precio unitario aplicando escalas, o [precioBase] si no hay tramo. */
export function resolverPrecioConEscalas(precioBase, cantidad, escalas = []) {
	const escala = seleccionarEscalaPorCantidad(escalas, cantidad);
	if (escala) {
		return redondearMonto(Number(escala.precioUnitario));
	}
	return redondearMonto(Number(precioBase) || 0);
}
