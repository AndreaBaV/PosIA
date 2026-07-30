/* Conexion a Neon y resolucion de la tienda publicada.

   Se usa el driver HTTP de Neon (sin conexiones TCP persistentes): es el
   adecuado para un entorno sin estado como Cloudflare Workers.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { neon } from '@neondatabase/serverless';

import { NOMBRE_TIENDA, WHATSAPP_PREDETERMINADO } from './constantes.js';
import { ErrorPeticion } from './respuesta.js';

/** Cliente SQL sobre Neon. Barato de crear: no abre conexiones. */
export function conectar(env) {
	const url = env?.DATABASE_URL;
	if (!url) {
		throw new ErrorPeticion('La tienda en linea no esta configurada', 503);
	}
	return neon(url);
}

/** Nombre comercial visible en el sitio y en el ticket. */
export function nombreTienda(env) {
	return (env?.TIENDA_PUBLICA_NOMBRE || '').trim() || NOMBRE_TIENDA;
}

/** WhatsApp de seguimiento, solo digitos, para enlaces wa.me. */
export function whatsappTienda(env) {
	const crudo = (env?.TIENDA_PUBLICA_WHATSAPP || '').trim() || WHATSAPP_PREDETERMINADO;
	return crudo.replace(/[^0-9]/g, '');
}

const tiendasResueltas = new Map();

/**
 * Sucursal que queda asignada a los pedidos web.
 *
 * El catalogo es UNIFICADO: se publica el de todas las sucursales activas sin
 * importar de cual sea cada producto. Pero `orders.tienda_id` es obligatorio
 * (es lo que hace que el pedido aparezca en el modulo Pedidos), asi que hay
 * que elegir una: con `TIENDA_PUBLICA_ID` se respeta esa; sin ella, la que
 * tenga mas catalogo publicable, que es la que mas probablemente surta.
 *
 * Se memoiza por isolate porque no cambia entre despliegues.
 */
export async function resolverTienda(sql, env) {
	const configurada = (env?.TIENDA_PUBLICA_ID || '').trim();
	const memoizada = tiendasResueltas.get(configurada);
	if (memoizada) {
		return memoizada;
	}
	const filas = configurada
		? await sql.query(
				'SELECT id, direccion FROM stores WHERE id = $1 LIMIT 1',
				[configurada],
			)
		: await sql.query(
				`SELECT s.id, s.direccion
				 FROM stores s
				 JOIN products p
					ON p.tienda_id = s.id AND p.activo = 1 AND p.precio_base > 0
				 WHERE s.activa = 1
				 GROUP BY s.id, s.direccion, s.nombre
				 ORDER BY COUNT(p.id) DESC, s.nombre ASC
				 LIMIT 1`,
			);
	if (!filas.length) {
		throw new ErrorPeticion('La tienda en linea aun no esta configurada', 503);
	}
	const tienda = { id: filas[0].id, direccion: filas[0].direccion ?? '' };
	tiendasResueltas.set(configurada, tienda);
	return tienda;
}
