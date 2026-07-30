/* Alta y consulta de pedidos de la tienda en linea.

   El pedido se escribe en Neon como lo haria el hub: una fila en
   `sync_events` con el evento `orderUpserted` MAS su proyeccion en
   `orders` / `order_lines`, todo en una transaccion. Asi las cajas lo
   reciben en su pull normal y el modulo Pedidos del POS lo ve igual que
   uno levantado en mostrador, sin que la tienda dependa de que el hub
   este despierto.

   Espejo de `ProyectorEventosPostgres._pedido` en
   server/sync_api/lib/src/proyector_eventos_postgres.dart: si esa
   proyeccion cambia, actualizar aqui.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import {
	DISPOSITIVO_WEB,
	LIMITE_CANTIDAD_LINEA,
	LIMITE_LINEAS_PEDIDO,
	METODOS_PAGO,
} from './constantes.js';
import { cargarPresentaciones } from './catalogo.js';
import { formatearMoneda, numeroCorto, redondearMonto } from './dinero.js';
import { ErrorPeticion } from './respuesta.js';

const ESTADO_INICIAL = 'recibido';

// --- Validacion (pura, sin base de datos) -----------------------------------

/** Valida y normaliza los datos de entrega del formulario. */
export function validarEntrega(cuerpo) {
	const aDomicilio = cuerpo?.entregaADomicilio !== false;
	const metodoPago = (cuerpo?.metodoPago ?? 'efectivo').trim();
	if (!METODOS_PAGO.has(metodoPago)) {
		throw new ErrorPeticion('Metodo de pago no disponible en linea');
	}
	return {
		nombre: textoObligatorio(cuerpo?.nombre, 'nombre', 120),
		telefono: telefonoValido(cuerpo?.telefono),
		aDomicilio,
		direccion: aDomicilio
			? textoObligatorio(cuerpo?.direccion, 'direccion', 300)
			: 'Recoger en tienda',
		metodoPago,
		notas: recortar(cuerpo?.notas ?? '', 500),
	};
}

/** Valida las partidas del carrito; el precio NO viene del navegador. */
export function leerLineasSolicitadas(crudas) {
	if (!Array.isArray(crudas)) {
		throw new ErrorPeticion('El pedido viene sin productos');
	}
	if (!crudas.length) {
		throw new ErrorPeticion('Agregue al menos un producto');
	}
	if (crudas.length > LIMITE_LINEAS_PEDIDO) {
		throw new ErrorPeticion(`Maximo ${LIMITE_LINEAS_PEDIDO} productos por pedido`);
	}
	return crudas.map((cruda) => {
		const productoId = String(cruda?.productoId ?? '').trim();
		const presentacionId = String(cruda?.presentacionId ?? '').trim();
		const cantidad = Number(cruda?.cantidad);
		if (!productoId) {
			throw new ErrorPeticion('Partida sin producto');
		}
		if (!(cantidad > 0) || cantidad > LIMITE_CANTIDAD_LINEA) {
			throw new ErrorPeticion(`Cantidad invalida en "${productoId}"`);
		}
		return { productoId, presentacionId: presentacionId || null, cantidad };
	});
}

/** Notas que veran en caja, marcando el canal de origen. */
export function componerNotas(notas, aDomicilio) {
	const partes = [
		aDomicilio ? 'Pedido web (envio a domicilio)' : 'Pedido web (recoge en tienda)',
	];
	if (notas.trim()) {
		partes.push(notas.trim());
	}
	return partes.join(' · ');
}

// --- Alta --------------------------------------------------------------------

/** Registra el pedido y devuelve folio, ticket y enlace de WhatsApp. */
export async function crearPedido(sql, { tiendaId, nombreTienda, whatsapp, cuerpo }) {
	const entrega = validarEntrega(cuerpo);
	const solicitadas = leerLineasSolicitadas(cuerpo?.lineas);
	const lineas = await resolverLineas(sql, tiendaId, solicitadas);
	const total = redondearMonto(
		lineas.reduce((suma, linea) => suma + linea.subtotal, 0),
	);
	if (!(total > 0)) {
		throw new ErrorPeticion('El pedido no tiene importe');
	}

	const pedidoId = crypto.randomUUID();
	const folio = pedidoId.slice(0, 8).toUpperCase();
	const creadoEn = new Date().toISOString();
	const notas = componerNotas(entrega.notas, entrega.aDomicilio);

	const payload = {
		id: pedidoId,
		tiendaId,
		clienteId: null,
		nombreEntrega: entrega.nombre,
		telefonoEntrega: entrega.telefono,
		direccionEntrega: entrega.direccion,
		esCredito: false,
		creditoDias: null,
		creditoVenceEn: null,
		metodoPago: entrega.metodoPago,
		total,
		notas,
		estado: ESTADO_INICIAL,
		asignadoAUsuarioId: null,
		asignadoAUsuarioNombre: null,
		asignadoEn: null,
		creadoEn,
		creadoPorUsuarioId: null,
		ventaId: null,
		lineas,
	};

	await sql.transaction([
		// Log de sync: es lo que las cajas descargan en su pull.
		sql.query(
			`INSERT INTO sync_events (id, store_id, device_id, type, payload, created_at)
			 VALUES ($1, $2, $3, 'orderUpserted', $4::jsonb, $5)
			 ON CONFLICT (id) DO UPDATE SET
				payload = EXCLUDED.payload,
				created_at = EXCLUDED.created_at`,
			[`orderUpserted:${pedidoId}`, tiendaId, DISPOSITIVO_WEB, JSON.stringify(payload), creadoEn],
		),
		// Proyeccion espejo: es lo que ve el administrador y el seguimiento.
		sql.query(
			`INSERT INTO orders (
				id, tienda_id, cliente_id, nombre_entrega, telefono_entrega,
				direccion_entrega, es_credito, credito_dias, credito_vence_en,
				metodo_pago, total, notas, estado, asignado_a_usuario_id,
				asignado_a_usuario_nombre, asignado_en, creado_en,
				creado_por_usuario_id, venta_id
			) VALUES (
				$1, $2, NULL, $3, $4, $5, 0, NULL, NULL, $6, $7, $8, $9,
				NULL, NULL, NULL, $10, NULL, NULL
			)
			ON CONFLICT (id) DO NOTHING`,
			[
				pedidoId, tiendaId, entrega.nombre, entrega.telefono, entrega.direccion,
				entrega.metodoPago, total, notas, ESTADO_INICIAL, creadoEn,
			],
		),
		...lineas.map((linea) =>
			sql.query(
				`INSERT INTO order_lines (
					pedido_id, producto_id, nombre_producto, cantidad,
					precio_unitario, subtotal
				) VALUES ($1, $2, $3, $4, $5, $6)`,
				[
					pedidoId, linea.productoId, linea.nombreProducto,
					linea.cantidad, linea.precioUnitario, linea.subtotal,
				],
			),
		),
	]);

	return construirRespuesta({
		folio,
		creadoEn,
		estado: ESTADO_INICIAL,
		nombreTienda,
		whatsapp,
		nombre: entrega.nombre,
		telefono: entrega.telefono,
		direccion: entrega.direccion,
		metodoPago: entrega.metodoPago,
		notas: entrega.notas,
		total,
		lineas,
	});
}

/**
 * Relee nombre y precio de cada partida desde Neon.
 *
 * El navegador solo dice QUE y CUANTO; el importe se calcula aqui.
 */
async function resolverLineas(sql, tiendaId, solicitadas) {
	const ids = [...new Set(solicitadas.map((s) => s.productoId))];
	const filas = await sql.query(
		`SELECT id, nombre, precio_base
		 FROM products
		 WHERE activo = 1 AND tienda_id = $1 AND id = ANY($2)`,
		[tiendaId, ids],
	);
	const productos = new Map(filas.map((fila) => [fila.id, fila]));
	const presentaciones = await cargarPresentaciones(sql, ids);

	return solicitadas.map((solicitada) => {
		const producto = productos.get(solicitada.productoId);
		if (!producto) {
			throw new ErrorPeticion('Un producto del carrito ya no esta disponible');
		}
		let nombreProducto = producto.nombre;
		let precioUnitario = redondearMonto(Number(producto.precio_base ?? 0));

		if (solicitada.presentacionId) {
			const disponibles = presentaciones.get(solicitada.productoId) ?? [];
			const elegida = disponibles.find((p) => p.id === solicitada.presentacionId);
			if (!elegida) {
				throw new ErrorPeticion('La presentacion elegida ya no esta disponible');
			}
			precioUnitario = elegida.precio;
			nombreProducto = `${nombreProducto} (${elegida.nombre})`;
		}
		if (!(precioUnitario > 0)) {
			throw new ErrorPeticion(`"${nombreProducto}" no tiene precio publicado`);
		}
		return {
			productoId: solicitada.productoId,
			nombreProducto,
			cantidad: solicitada.cantidad,
			precioUnitario,
			subtotal: redondearMonto(precioUnitario * solicitada.cantidad),
		};
	});
}

// --- Seguimiento -------------------------------------------------------------

/** Busca un pedido por folio (primeros 8 caracteres del id, en mayusculas). */
export async function consultarPedido(sql, tiendaId, folioCrudo, { nombreTienda, whatsapp }) {
	const folio = String(folioCrudo ?? '').trim().toUpperCase();
	if (!/^[0-9A-F]{8}$/.test(folio)) {
		throw new ErrorPeticion('Folio invalido', 404);
	}
	const filas = await sql.query(
		`SELECT id, nombre_entrega, telefono_entrega, direccion_entrega,
			metodo_pago, total, notas, estado, creado_en
		 FROM orders
		 WHERE upper(left(id, 8)) = $1 AND tienda_id = $2
		 ORDER BY creado_en DESC
		 LIMIT 1`,
		[folio, tiendaId],
	);
	if (!filas.length) {
		throw new ErrorPeticion('No encontramos ese folio', 404);
	}
	const pedido = filas[0];
	const lineasFilas = await sql.query(
		`SELECT nombre_producto, cantidad, precio_unitario, subtotal
		 FROM order_lines
		 WHERE pedido_id = $1
		 ORDER BY id ASC`,
		[pedido.id],
	);
	return construirRespuesta({
		folio,
		creadoEn: fechaIso(pedido.creado_en),
		estado: pedido.estado || ESTADO_INICIAL,
		nombreTienda,
		whatsapp,
		nombre: pedido.nombre_entrega ?? '',
		telefono: pedido.telefono_entrega ?? '',
		direccion: pedido.direccion_entrega ?? '',
		metodoPago: pedido.metodo_pago ?? 'efectivo',
		notas: pedido.notas ?? '',
		total: Number(pedido.total ?? 0),
		lineas: lineasFilas.map((linea) => ({
			nombreProducto: linea.nombre_producto ?? '',
			cantidad: Number(linea.cantidad ?? 0),
			precioUnitario: Number(linea.precio_unitario ?? 0),
			subtotal: Number(linea.subtotal ?? 0),
		})),
	});
}

// --- Presentacion ------------------------------------------------------------

/** Cuerpo JSON comun del alta y del seguimiento. */
export function construirRespuesta(datos) {
	const ticketTexto = textoTicket(datos);
	return {
		folio: datos.folio,
		estado: datos.estado,
		creadoEn: datos.creadoEn,
		tienda: datos.nombreTienda,
		nombre: datos.nombre,
		telefono: datos.telefono,
		direccion: datos.direccion,
		metodoPago: datos.metodoPago,
		notas: datos.notas,
		total: datos.total,
		lineas: datos.lineas,
		ticketTexto,
		whatsapp: enlaceWhatsapp(datos.whatsapp, ticketTexto),
	};
}

/** Texto plano del ticket, tambien usado como mensaje de WhatsApp. */
export function textoTicket(datos) {
	const lineas = [
		`PEDIDO ${datos.nombreTienda}`,
		`Folio: ${datos.folio}`,
		`Fecha: ${fechaLocal(datos.creadoEn)}`,
		`Cliente: ${datos.nombre}`,
		`Telefono: ${datos.telefono}`,
		`Entrega: ${datos.direccion}`,
		`Pago: ${etiquetaPago(datos.metodoPago)}`,
		'',
	];
	for (const linea of datos.lineas) {
		lineas.push(
			`${numeroCorto(linea.cantidad)} x ${linea.nombreProducto} - ` +
			`${formatearMoneda(linea.subtotal)}`,
		);
	}
	lineas.push('', `TOTAL: ${formatearMoneda(datos.total)}`);
	if (datos.notas?.trim()) {
		lineas.push(`Notas: ${datos.notas.trim()}`);
	}
	lineas.push('', 'Envio este pedido desde la tienda en linea.');
	return lineas.join('\n');
}

/** Enlace wa.me con el pedido ya redactado. */
export function enlaceWhatsapp(whatsapp, texto) {
	return `https://wa.me/${whatsapp}?text=${encodeURIComponent(texto)}`;
}

export function etiquetaPago(metodo) {
	return metodo === 'transferencia' ? 'Transferencia' : 'Efectivo contra entrega';
}

/** Fecha legible en horario de la tienda (UTC-6, sin dependencias de zona). */
export function fechaLocal(iso) {
	const fecha = new Date(iso);
	if (Number.isNaN(fecha.getTime())) {
		return '';
	}
	const local = new Date(fecha.getTime() - 6 * 60 * 60 * 1000);
	const dd = String(local.getUTCDate()).padStart(2, '0');
	const mm = String(local.getUTCMonth() + 1).padStart(2, '0');
	const hh = String(local.getUTCHours()).padStart(2, '0');
	const mi = String(local.getUTCMinutes()).padStart(2, '0');
	return `${dd}/${mm}/${local.getUTCFullYear()} ${hh}:${mi}`;
}

// --- Helpers -----------------------------------------------------------------

function fechaIso(valor) {
	if (valor instanceof Date) {
		return valor.toISOString();
	}
	const fecha = new Date(valor);
	return Number.isNaN(fecha.getTime()) ? new Date().toISOString() : fecha.toISOString();
}

function textoObligatorio(valor, campo, maximo) {
	const texto = String(valor ?? '').trim();
	if (!texto) {
		throw new ErrorPeticion(`Falta el campo ${campo}`);
	}
	return recortar(texto, maximo);
}

function telefonoValido(valor) {
	const digitos = String(valor ?? '').replace(/[^0-9]/g, '');
	if (digitos.length < 10 || digitos.length > 15) {
		throw new ErrorPeticion('Telefono invalido (10 digitos)');
	}
	return digitos;
}

function recortar(texto, maximo) {
	const limpio = String(texto ?? '').trim();
	return limpio.length <= maximo ? limpio : limpio.slice(0, maximo);
}
