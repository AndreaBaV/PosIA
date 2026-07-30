/* GET /v1/public/categorias — categorias con productos publicables.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { consultarCategorias } from '../../../lib/catalogo.js';
import { CACHE_CATALOGO_SEGUNDOS } from '../../../lib/constantes.js';
import { conectar } from '../../../lib/neon.js';
import { conCacheDeBorde, json } from '../../../lib/respuesta.js';

export async function onRequestGet(context) {
	return conCacheDeBorde(context, CACHE_CATALOGO_SEGUNDOS, async () => {
		const sql = conectar(context.env);
		const datos = await consultarCategorias(sql);
		return json(datos, { cacheSegundos: CACHE_CATALOGO_SEGUNDOS });
	});
}
