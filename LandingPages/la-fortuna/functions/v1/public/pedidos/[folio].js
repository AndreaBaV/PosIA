/* GET /v1/public/pedidos/{folio} — seguimiento del pedido.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { conectar, nombreTienda, whatsappTienda } from '../../../../lib/neon.js';
import { consultarPedido } from '../../../../lib/pedido.js';
import { json } from '../../../../lib/respuesta.js';

export async function onRequestGet(context) {
	const sql = conectar(context.env);
	const pedido = await consultarPedido(sql, context.params.folio, {
		nombreTienda: nombreTienda(context.env),
		whatsapp: whatsappTienda(context.env),
	});
	// Sin cache: el cliente consulta justo para ver si ya cambio el estado.
	return json(pedido);
}
