/* Errores de dominio, respuestas JSON y cache de borde.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

/** Error de validacion o de negocio que se traduce a un codigo HTTP. */
export class ErrorPeticion extends Error {
	constructor(mensaje, codigo = 400) {
		super(mensaje);
		this.name = 'ErrorPeticion';
		this.codigo = codigo;
	}
}

/** Construye una respuesta JSON con cabeceras de cache opcionales. */
export function json(cuerpo, { codigo = 200, cacheSegundos = 0 } = {}) {
	const cabeceras = {
		'Content-Type': 'application/json; charset=utf-8',
		'Cache-Control': cacheSegundos > 0
			? `public, max-age=${cacheSegundos}`
			: 'no-store',
	};
	return new Response(JSON.stringify(cuerpo), { status: codigo, headers: cabeceras });
}

/**
 * Sirve una lectura desde el cache del borde de Cloudflare.
 *
 * Es lo que evita que cada visita despierte el computo de Neon: cientos de
 * vistas del catalogo se resuelven con una sola consulta cada [segundos].
 */
export async function conCacheDeBorde(context, segundos, generar) {
	const cacheDisponible = typeof caches !== 'undefined' && caches.default;
	if (!cacheDisponible) {
		return generar();
	}
	const cache = caches.default;
	const clave = new Request(context.request.url, { method: 'GET' });
	const guardada = await cache.match(clave);
	if (guardada) {
		return guardada;
	}
	const respuesta = await generar();
	if (respuesta.ok) {
		context.waitUntil(cache.put(clave, respuesta.clone()));
	}
	return respuesta;
}
