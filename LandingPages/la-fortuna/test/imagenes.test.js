/* Pruebas del endpoint de subida de imagen de producto (POST /v1/admin/imagenes).

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { onRequestPost } from '../functions/v1/admin/imagenes.js';
import { ErrorPeticion } from '../lib/respuesta.js';

const CLAVE = 'clave-secreta-de-prueba';

function bucketFalso() {
	const guardados = [];
	return {
		guardados,
		async put(clave, cuerpo, opciones) {
			guardados.push({ clave, byteLength: cuerpo.byteLength, opciones });
		},
	};
}

function contexto({
	env = {},
	headers = {},
	productoId = 'a1b2c3d4-1111-2222-3333-444455556666',
	cuerpo = new Uint8Array([1, 2, 3, 4]).buffer,
} = {}) {
	const url = `https://tienda.test/v1/admin/imagenes?productoId=${encodeURIComponent(productoId)}`;
	return {
		env: {
			POSIA_HUB_API_KEY: CLAVE,
			IMAGENES_PRODUCTOS: bucketFalso(),
			IMAGENES_URL_BASE: 'https://pub-test.r2.dev',
			...env,
		},
		request: {
			url,
			headers: {
				get: (nombre) => headers[nombre.toLowerCase()] ?? null,
			},
			arrayBuffer: async () => cuerpo,
		},
	};
}

test('sube la imagen y devuelve la URL publica con clave unica por producto', async () => {
	const ctx = contexto({ headers: { 'x-api-key': CLAVE, 'content-type': 'image/jpeg' } });
	const respuesta = await onRequestPost(ctx);
	const cuerpo = await respuesta.json();

	assert.ok(cuerpo.url.startsWith('https://pub-test.r2.dev/productos/a1b2c3d4-1111-2222-3333-444455556666-'));
	assert.ok(cuerpo.url.endsWith('.jpg'));
	assert.equal(ctx.env.IMAGENES_PRODUCTOS.guardados.length, 1);
	assert.equal(ctx.env.IMAGENES_PRODUCTOS.guardados[0].byteLength, 4);
	assert.equal(ctx.env.IMAGENES_PRODUCTOS.guardados[0].opciones.httpMetadata.contentType, 'image/jpeg');
});

test('rechaza sin clave o con clave incorrecta', async () => {
	await assert.rejects(
		() => onRequestPost(contexto({ headers: { 'content-type': 'image/jpeg' } })),
		(error) => error instanceof ErrorPeticion && error.codigo === 401,
	);
	await assert.rejects(
		() => onRequestPost(contexto({ headers: { 'x-api-key': 'otra', 'content-type': 'image/jpeg' } })),
		(error) => error instanceof ErrorPeticion && error.codigo === 401,
	);
});

test('rechaza productoId con caracteres fuera de lo esperado', async () => {
	await assert.rejects(
		() => onRequestPost(contexto({
			headers: { 'x-api-key': CLAVE, 'content-type': 'image/jpeg' },
			productoId: '../secretos',
		})),
		(error) => error instanceof ErrorPeticion && error.codigo === 400,
	);
});

test('rechaza tipos de contenido no soportados', async () => {
	await assert.rejects(
		() => onRequestPost(contexto({
			headers: { 'x-api-key': CLAVE, 'content-type': 'application/pdf' },
		})),
		(error) => error instanceof ErrorPeticion && error.codigo === 415,
	);
});

test('rechaza un cuerpo vacio', async () => {
	await assert.rejects(
		() => onRequestPost(contexto({
			headers: { 'x-api-key': CLAVE, 'content-type': 'image/png' },
			cuerpo: new Uint8Array([]).buffer,
		})),
		(error) => error instanceof ErrorPeticion && error.codigo === 400,
	);
});

test('rechaza una imagen que supera el tamaño maximo', async () => {
	await assert.rejects(
		() => onRequestPost(contexto({
			headers: { 'x-api-key': CLAVE, 'content-type': 'image/png' },
			cuerpo: new ArrayBuffer(5 * 1024 * 1024 + 1),
		})),
		(error) => error instanceof ErrorPeticion && error.codigo === 413,
	);
});

test('responde 503 si el bucket o la URL publica no estan configurados', async () => {
	await assert.rejects(
		() => onRequestPost(contexto({
			headers: { 'x-api-key': CLAVE, 'content-type': 'image/jpeg' },
			env: { IMAGENES_PRODUCTOS: undefined },
		})),
		(error) => error instanceof ErrorPeticion && error.codigo === 503,
	);
	await assert.rejects(
		() => onRequestPost(contexto({
			headers: { 'x-api-key': CLAVE, 'content-type': 'image/jpeg' },
			env: { IMAGENES_URL_BASE: '' },
		})),
		(error) => error instanceof ErrorPeticion && error.codigo === 503,
	);
});
