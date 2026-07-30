/* GET /v1/public/catalogo — pagina del catalogo, sin existencias.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { consultarCatalogo } from '../../../lib/catalogo.js';
import { CACHE_CATALOGO_SEGUNDOS } from '../../../lib/constantes.js';
import { conectar, resolverTienda } from '../../../lib/neon.js';
import { conCacheDeBorde, json } from '../../../lib/respuesta.js';

export async function onRequestGet(context) {
	return conCacheDeBorde(context, CACHE_CATALOGO_SEGUNDOS, async () => {
		const parametros = new URL(context.request.url).searchParams;
		const sql = conectar(context.env);
		const tienda = await resolverTienda(sql, context.env);
		const datos = await consultarCatalogo(sql, tienda.id, {
			q: parametros.get('q'),
			categoria: parametros.get('categoria'),
			limite: parametros.get('limite'),
			desde: parametros.get('desde'),
		});
		return json(datos, { cacheSegundos: CACHE_CATALOGO_SEGUNDOS });
	});
}
