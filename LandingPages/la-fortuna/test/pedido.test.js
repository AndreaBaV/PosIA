/* Pruebas del alta de pedidos: validacion, re-precio y escritura en Neon.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { redondearMonto } from '../lib/dinero.js';
import {
	componerNotas,
	consultarPedido,
	crearPedido,
	enlaceWhatsapp,
	fechaLocal,
	leerLineasSolicitadas,
	textoTicket,
	validarEntrega,
} from '../lib/pedido.js';
import { consultasCon, sqlFalso } from './ayudas.js';

const TIENDA = 'tienda-1';
const OPCIONES = { nombreTienda: 'La Fortuna', whatsapp: '527226527751' };

const PRODUCTOS = [
	{ id: 'p1', nombre: 'Frijol negro', precio_base: 38.5 },
	{ id: 'p2', nombre: 'Aceite 1 L', precio_base: 42 },
];

const PRESENTACIONES = [
	{ id: 'pr1', producto_id: 'p1', nombre: 'Bulto 25 kg', precio: 890, factor_a_base: 25 },
];

function cuerpoBase(lineas) {
	return {
		nombre: 'María Solís',
		telefono: '722 111 2233',
		entregaADomicilio: true,
		direccion: 'Calle Morelos 45',
		metodoPago: 'efectivo',
		notas: 'Después de las 6',
		lineas,
	};
}

// --- Validacion --------------------------------------------------------------

test('exige nombre, teléfono y dirección cuando es a domicilio', () => {
	assert.throws(() => validarEntrega({ telefono: '7221112233', direccion: 'x' }),
		/Falta el campo nombre/);
	assert.throws(() => validarEntrega({ nombre: 'Ana', telefono: '722', direccion: 'x' }),
		/Telefono invalido/);
	assert.throws(() => validarEntrega({ nombre: 'Ana', telefono: '7221112233' }),
		/Falta el campo direccion/);
});

test('recoger en tienda no pide dirección', () => {
	const entrega = validarEntrega({
		nombre: 'Ana', telefono: '7221112233', entregaADomicilio: false,
	});
	assert.equal(entrega.direccion, 'Recoger en tienda');
	assert.equal(entrega.telefono, '7221112233');
});

test('rechaza formas de pago que no se ofrecen en línea', () => {
	assert.throws(
		() => validarEntrega({ nombre: 'Ana', telefono: '7221112233', direccion: 'x', metodoPago: 'credito' }),
		/Metodo de pago no disponible/,
	);
});

test('el teléfono se normaliza a solo dígitos', () => {
	const entrega = validarEntrega({
		nombre: 'Ana', telefono: '+52 (722) 111-2233', direccion: 'x',
	});
	assert.equal(entrega.telefono, '527221112233');
});

test('valida las partidas del carrito', () => {
	assert.throws(() => leerLineasSolicitadas(null), /sin productos/);
	assert.throws(() => leerLineasSolicitadas([]), /al menos un producto/);
	assert.throws(() => leerLineasSolicitadas([{ productoId: 'p1', cantidad: 0 }]), /Cantidad invalida/);
	assert.throws(() => leerLineasSolicitadas([{ productoId: 'p1', cantidad: 99999 }]), /Cantidad invalida/);
	assert.throws(() => leerLineasSolicitadas([{ cantidad: 1 }]), /Partida sin producto/);
	assert.throws(
		() => leerLineasSolicitadas(Array.from({ length: 101 }, () => ({ productoId: 'p1', cantidad: 1 }))),
		/Maximo 100 productos/,
	);
	const lineas = leerLineasSolicitadas([{ productoId: 'p1', presentacionId: '', cantidad: 2 }]);
	assert.deepEqual(lineas, [{ productoId: 'p1', presentacionId: null, cantidad: 2 }]);
});

test('las notas marcan el canal de origen', () => {
	assert.equal(componerNotas('', true), 'Pedido web (envio a domicilio)');
	assert.equal(componerNotas('Tocar timbre', false), 'Pedido web (recoge en tienda) · Tocar timbre');
});

// --- Alta ---------------------------------------------------------------------

test('el precio se relee de la base e ignora el que mande el navegador', async () => {
	const sql = sqlFalso({ productos: PRODUCTOS, presentaciones: PRESENTACIONES });
	const pedido = await crearPedido(sql, {
		tiendaId: TIENDA,
		...OPCIONES,
		cuerpo: cuerpoBase([
			{ productoId: 'p1', cantidad: 2, precioUnitario: 1, subtotal: 2 },
		]),
	});
	assert.equal(pedido.lineas[0].precioUnitario, 38.5);
	assert.equal(pedido.lineas[0].subtotal, 77);
	assert.equal(pedido.total, 77);
});

test('la presentación elegida fija precio y nombre de la partida', async () => {
	const sql = sqlFalso({ productos: PRODUCTOS, presentaciones: PRESENTACIONES });
	const pedido = await crearPedido(sql, {
		tiendaId: TIENDA,
		...OPCIONES,
		cuerpo: cuerpoBase([{ productoId: 'p1', presentacionId: 'pr1', cantidad: 2 }]),
	});
	assert.equal(pedido.lineas[0].nombreProducto, 'Frijol negro (Bulto 25 kg)');
	assert.equal(pedido.lineas[0].precioUnitario, 890);
	assert.equal(pedido.total, 1780);
});

test('rechaza productos y presentaciones que ya no existen', async () => {
	const sinProductos = sqlFalso({ productos: [], presentaciones: [] });
	await assert.rejects(
		crearPedido(sinProductos, { tiendaId: TIENDA, ...OPCIONES, cuerpo: cuerpoBase([{ productoId: 'zz', cantidad: 1 }]) }),
		/ya no esta disponible/,
	);
	const sinPresentacion = sqlFalso({ productos: PRODUCTOS, presentaciones: [] });
	await assert.rejects(
		crearPedido(sinPresentacion, { tiendaId: TIENDA, ...OPCIONES, cuerpo: cuerpoBase([{ productoId: 'p1', presentacionId: 'pr1', cantidad: 1 }]) }),
		/presentacion elegida ya no esta disponible/,
	);
});

test('escribe el evento de sync y su proyección en una sola transacción', async () => {
	const sql = sqlFalso({ productos: PRODUCTOS, presentaciones: PRESENTACIONES });
	const pedido = await crearPedido(sql, {
		tiendaId: TIENDA,
		...OPCIONES,
		cuerpo: cuerpoBase([
			{ productoId: 'p1', cantidad: 1 },
			{ productoId: 'p2', cantidad: 3 },
		]),
	});

	const transaccion = consultasCon(sql, 'TRANSACTION');
	assert.equal(transaccion.length, 1, 'todo debe ir en una transacción');
	assert.equal(transaccion[0].parametros[0], 4, 'evento + pedido + 2 partidas');

	const evento = consultasCon(sql, 'INSERT INTO sync_events')[0];
	assert.ok(evento, 'debe registrarse el evento que consumen las cajas');
	assert.ok(evento.texto.includes("'orderUpserted'"));
	const [idEvento, tiendaEvento, dispositivo, payloadCrudo] = evento.parametros;
	assert.equal(tiendaEvento, TIENDA);
	assert.equal(dispositivo, 'tienda-web', 'no debe firmarse como una caja');

	const payload = JSON.parse(payloadCrudo);
	assert.equal(idEvento, `orderUpserted:${payload.id}`, 'id determinístico e idempotente');
	assert.equal(payload.estado, 'recibido');
	assert.equal(payload.esCredito, false);
	assert.equal(payload.total, redondearMonto(38.5 + 42 * 3));
	assert.equal(payload.lineas.length, 2);
	assert.equal(pedido.folio, payload.id.slice(0, 8).toUpperCase());

	const orden = consultasCon(sql, 'INSERT INTO orders')[0];
	assert.ok(orden.texto.includes('ON CONFLICT (id) DO NOTHING'), 'reintento no duplica');
	assert.equal(consultasCon(sql, 'INSERT INTO order_lines').length, 2);
});

test('el folio y el enlace de WhatsApp viajan en la respuesta', async () => {
	const sql = sqlFalso({ productos: PRODUCTOS, presentaciones: PRESENTACIONES });
	const pedido = await crearPedido(sql, {
		tiendaId: TIENDA,
		...OPCIONES,
		cuerpo: cuerpoBase([{ productoId: 'p2', cantidad: 1 }]),
	});
	assert.match(pedido.folio, /^[0-9A-F]{8}$/);
	assert.ok(pedido.whatsapp.startsWith('https://wa.me/527226527751?text='));
	assert.ok(pedido.ticketTexto.includes(`Folio: ${pedido.folio}`));
	assert.ok(pedido.ticketTexto.includes('TOTAL: $42.00'));
	assert.ok(
		pedido.ticketTexto.includes('Pago: Efectivo contra entrega'),
		'el ticket dice cómo se paga',
	);
});

// --- Seguimiento ---------------------------------------------------------------

test('el folio se valida antes de tocar la base', async () => {
	const sql = sqlFalso();
	await assert.rejects(consultarPedido(sql, 'no-es-folio', OPCIONES), /Folio invalido/);
	await assert.rejects(consultarPedido(sql, '', OPCIONES), /Folio invalido/);
	assert.equal(sql.llamadas.length, 0, 'no debe consultarse la base con un folio inválido');
});

test('un folio inexistente responde 404 y no filtra información', async () => {
	const sql = sqlFalso({ pedidos: [] });
	await assert.rejects(
		consultarPedido(sql, '7f3a9c21', OPCIONES),
		(error) => error.codigo === 404 && /No encontramos ese folio/.test(error.message),
	);
});

test('el seguimiento devuelve el pedido con sus partidas', async () => {
	const sql = sqlFalso({
		pedidos: [{
			id: '7f3a9c21-1111-4222-8333-444455556666',
			nombre_entrega: 'María Solís',
			telefono_entrega: '7221112233',
			direccion_entrega: 'Calle Morelos 45',
			metodo_pago: 'transferencia',
			total: 1780,
			notas: 'Pedido web (envio a domicilio)',
			estado: 'asignado',
			creado_en: new Date('2026-07-29T18:30:00Z'),
		}],
		lineasPedido: [
			{ nombre_producto: 'Frijol negro (Bulto 25 kg)', cantidad: 2, precio_unitario: 890, subtotal: 1780 },
		],
	});
	const pedido = await consultarPedido(sql, '7f3a9c21', OPCIONES);
	assert.equal(pedido.folio, '7F3A9C21');
	assert.equal(pedido.estado, 'asignado');
	assert.equal(pedido.total, 1780);
	assert.equal(pedido.lineas.length, 1);

	const consulta = consultasCon(sql, 'FROM orders')[0];
	assert.ok(
		consulta.texto.includes("notas LIKE 'Pedido web%'"),
		'solo se exponen pedidos del canal web, no los levantados en mostrador',
	);
});

// --- Formato --------------------------------------------------------------------

test('la fecha del ticket se muestra en horario de la tienda (UTC-6)', () => {
	assert.equal(fechaLocal('2026-07-29T18:30:00.000Z'), '29/07/2026 12:30');
	assert.equal(fechaLocal('no-es-fecha'), '');
});

test('el texto del ticket lista cantidades e importes', () => {
	const texto = textoTicket({
		folio: 'ABCD1234',
		creadoEn: '2026-07-29T18:30:00.000Z',
		nombreTienda: 'La Fortuna',
		nombre: 'Ana',
		telefono: '7221112233',
		direccion: 'Recoger en tienda',
		metodoPago: 'transferencia',
		notas: '',
		total: 247.5,
		lineas: [{ nombreProducto: 'Bistec de res', cantidad: 1.5, precioUnitario: 165, subtotal: 247.5 }],
	});
	assert.ok(texto.includes('1.5 x Bistec de res - $247.50'));
	assert.ok(texto.includes('TOTAL: $247.50'));
	assert.ok(!texto.includes('undefined'));
});

test('el enlace de WhatsApp escapa el texto del pedido', () => {
	const enlace = enlaceWhatsapp('527226527751', 'Folio ABC\nTotal $10');
	assert.ok(enlace.includes('%0A'), 'los saltos de línea van codificados');
	assert.ok(!enlace.includes(' '), 'sin espacios sin escapar');
});
