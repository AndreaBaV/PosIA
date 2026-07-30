/* Middleware comun de las rutas /v1/public: CORS y traduccion de errores.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { ErrorPeticion, json } from '../lib/respuesta.js';

const CORS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type',
	'Access-Control-Max-Age': '86400',
};

export async function onRequest(context) {
	if (context.request.method === 'OPTIONS') {
		return new Response(null, { status: 204, headers: CORS });
	}
	let respuesta;
	try {
		respuesta = await context.next();
	} catch (error) {
		if (error instanceof ErrorPeticion) {
			respuesta = json({ error: error.message }, { codigo: error.codigo });
		} else {
			console.error('Tienda publica: error inesperado', error);
			respuesta = json(
				{ error: 'No pudimos completar la operacion' },
				{ codigo: 500 },
			);
		}
	}
	// La respuesta puede venir del cache del borde (inmutable): se reconstruye.
	const conCors = new Response(respuesta.body, respuesta);
	for (const [clave, valor] of Object.entries(CORS)) {
		conCors.headers.set(clave, valor);
	}
	return conCors;
}
