/* Pruebas de la seleccion de escala por cantidad (espejo del POS).

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
	resolverPrecioConEscalas,
	seleccionarEscalaPorCantidad,
} from '../lib/escalas.js';

// Tramos tipicos de carniceria: kilo $30, medio $20 (= $40/kg), cuarto $22 (= $88/kg).
const CORTES = [
	{ cantidadMinima: 0, precioUnitario: 88 },
	{ cantidadMinima: 0.25, precioUnitario: 88 },
	{ cantidadMinima: 0.5, precioUnitario: 40 },
	{ cantidadMinima: 1, precioUnitario: 30 },
];

test('medio kilo usa el tramo de fraccion, no el de kilo completo', () => {
	assert.equal(resolverPrecioConEscalas(30, 0.5, CORTES), 40);
	assert.equal(resolverPrecioConEscalas(30, 0.25, CORTES), 88);
	assert.equal(resolverPrecioConEscalas(30, 1, CORTES), 30);
	assert.equal(resolverPrecioConEscalas(30, 1.5, CORTES), 30);
});

test('sin escalas se conserva el precio base', () => {
	assert.equal(resolverPrecioConEscalas(70, 0.5, []), 70);
	assert.equal(resolverPrecioConEscalas(70, 0.5, null), 70);
});

test('selecciona el umbral mayor que califica', () => {
	const elegida = seleccionarEscalaPorCantidad(CORTES, 0.5);
	assert.equal(elegida.cantidadMinima, 0.5);
	assert.equal(elegida.precioUnitario, 40);
});
