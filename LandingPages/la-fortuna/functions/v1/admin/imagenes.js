/* POST /v1/admin/imagenes?productoId=... — sube la foto de un producto a R2.

   Protegido con x-api-key: reusa POSIA_HUB_API_KEY (el mismo secreto que ya
   trae la app POS para hablar con el hub) en vez de inventar una clave mas
   que la app tenga que cargar. El cuerpo es la imagen cruda (Content-Type
   image/jpeg|png|webp); no se usa multipart para no traer un parser aparte.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { ErrorPeticion, json } from '../../../lib/respuesta.js';

const EXTENSION_POR_TIPO = {
	'image/jpeg': 'jpg',
	'image/png': 'png',
	'image/webp': 'webp',
};

const TAMANO_MAXIMO_BYTES = 5 * 1024 * 1024;

export async function onRequestPost(context) {
	const claveEsperada = (context.env.POSIA_HUB_API_KEY || '').trim();
	if (!claveEsperada) {
		throw new ErrorPeticion('Subida de imagenes no configurada', 503);
	}
	const claveRecibida = context.request.headers.get('x-api-key') || '';
	if (claveRecibida !== claveEsperada) {
		throw new ErrorPeticion('Clave invalida', 401);
	}

	const bucket = context.env.IMAGENES_PRODUCTOS;
	if (!bucket) {
		throw new ErrorPeticion('Almacenamiento de imagenes no configurado', 503);
	}
	const urlBase = (context.env.IMAGENES_URL_BASE || '').trim().replace(/\/+$/, '');
	if (!urlBase) {
		throw new ErrorPeticion('URL publica de imagenes no configurada', 503);
	}

	const productoId = (new URL(context.request.url).searchParams.get('productoId') || '').trim();
	// Mismo formato que los ids que ya genera la app (UUID v4): bloquea
	// cualquier intento de escapar del prefijo productos/ con '/' o '..'.
	if (!/^[a-zA-Z0-9_-]+$/.test(productoId)) {
		throw new ErrorPeticion('productoId invalido', 400);
	}

	const tipo = (context.request.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
	const extension = EXTENSION_POR_TIPO[tipo];
	if (!extension) {
		throw new ErrorPeticion('Formato de imagen no soportado (usa JPG, PNG o WEBP)', 415);
	}

	const cuerpo = await context.request.arrayBuffer();
	if (!cuerpo.byteLength) {
		throw new ErrorPeticion('La imagen viene vacia', 400);
	}
	if (cuerpo.byteLength > TAMANO_MAXIMO_BYTES) {
		throw new ErrorPeticion('La imagen supera el tamano maximo (5 MB)', 413);
	}

	// Clave unica por subida (no solo por producto): asi la URL cambia cada
	// vez y nunca sirve una version cacheada vieja de la foto. La anterior
	// queda huerfana en el bucket -aceptable, R2 es barato- en vez de
	// arriesgar servir una imagen a medio sobreescribir.
	const clave = `productos/${productoId}-${Date.now()}.${extension}`;
	await bucket.put(clave, cuerpo, {
		httpMetadata: { contentType: tipo },
	});

	return json({ url: `${urlBase}/${clave}` });
}
