/* POST /v1/public/pedidos — alta de pedido del cliente final.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { conectar, nombreTienda, resolverTienda, whatsappTienda } from '../../../../lib/neon.js';
import { crearPedido } from '../../../../lib/pedido.js';
import { ErrorPeticion, json } from '../../../../lib/respuesta.js';

export async function onRequestPost(context) {
	let cuerpo;
	try {
		cuerpo = await context.request.json();
	} catch {
		throw new ErrorPeticion('JSON invalido');
	}
	const sql = conectar(context.env);
	const tienda = await resolverTienda(sql, context.env);
	const pedido = await crearPedido(sql, {
		tiendaId: tienda.id,
		nombreTienda: nombreTienda(context.env),
		whatsapp: whatsappTienda(context.env),
		cuerpo,
	});
	return json(pedido);
}
