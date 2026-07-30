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
 * Tienda cuyo catalogo se publica.
 *
 * Con `TIENDA_PUBLICA_ID` se usa esa; sin ella, la primera tienda activa.
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
				'SELECT id, direccion FROM stores WHERE activa = 1 ORDER BY nombre ASC LIMIT 1',
			);
	if (!filas.length) {
		throw new ErrorPeticion('La tienda en linea aun no esta configurada', 503);
	}
	const tienda = { id: filas[0].id, direccion: filas[0].direccion ?? '' };
	tiendasResueltas.set(configurada, tienda);
	return tienda;
}
