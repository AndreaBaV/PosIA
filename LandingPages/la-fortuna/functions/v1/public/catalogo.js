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
		const idsCrudo = (parametros.get('ids') || '').trim();
		const datos = await consultarCatalogo(sql, tienda.id, {
			q: parametros.get('q'),
			categoria: parametros.get('categoria'),
			limite: parametros.get('limite'),
			desde: parametros.get('desde'),
			// Filtros nuevos de la vitrina: rango de precio y orden. Los
			// valores no numericos o fuera de la lista blanca los ignora
			// `consultarCatalogo`, no hace falta validar aqui.
			precioMin: parametros.get('precio_min'),
			precioMax: parametros.get('precio_max'),
			orden: parametros.get('orden'),
			// Refresca precio/escalas de un carrito ya guardado (ids
			// separados por coma), sin paginar ni filtrar por texto.
			ids: idsCrudo ? idsCrudo.split(',') : undefined,
		});
		return json(datos, { cacheSegundos: CACHE_CATALOGO_SEGUNDOS });
	});
}
