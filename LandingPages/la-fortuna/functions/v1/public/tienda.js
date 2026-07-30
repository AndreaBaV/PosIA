/* GET /v1/public/tienda — datos de portada.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { CACHE_TIENDA_SEGUNDOS } from '../../../lib/constantes.js';
import { conectar, nombreTienda, resolverTienda, whatsappTienda } from '../../../lib/neon.js';
import { conCacheDeBorde, json } from '../../../lib/respuesta.js';

export async function onRequestGet(context) {
	return conCacheDeBorde(context, CACHE_TIENDA_SEGUNDOS, async () => {
		const sql = conectar(context.env);
		const tienda = await resolverTienda(sql, context.env);
		return json(
			{
				nombre: nombreTienda(context.env),
				whatsapp: whatsappTienda(context.env),
				tiendaId: tienda.id,
				direccion: tienda.direccion,
				moneda: 'MXN',
			},
			{ cacheSegundos: CACHE_TIENDA_SEGUNDOS },
		);
	});
}
