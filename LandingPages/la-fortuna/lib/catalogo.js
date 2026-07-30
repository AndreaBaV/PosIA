/* Consultas del catalogo publico.

   Regla de oro: la vitrina NUNCA expone existencias. Solo nombre, precio,
   unidad, categoria y presentaciones con precio propio.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { LIMITE_PAGINA_CATALOGO } from './constantes.js';
import { redondearMonto } from './dinero.js';

/** Categorias activas con al menos un producto publicable. */
export async function consultarCategorias(sql, tiendaId) {
	const filas = await sql.query(
		`SELECT c.id, c.nombre, COUNT(p.id) AS total
		 FROM categories c
		 JOIN products p
			ON p.categoria_id = c.id
			AND p.activo = 1
			AND p.tienda_id = $1
			AND p.precio_base > 0
		 WHERE c.activa = 1
		 GROUP BY c.id, c.nombre, c.orden
		 HAVING COUNT(p.id) > 0
		 ORDER BY c.orden ASC, c.nombre ASC`,
		[tiendaId],
	);
	return {
		categorias: filas.map((fila) => ({
			id: fila.id,
			nombre: fila.nombre,
			total: Number(fila.total ?? 0),
		})),
	};
}

/**
 * Pagina del catalogo.
 *
 * Se pide un producto de mas que el limite para saber si hay pagina
 * siguiente sin pagar un COUNT(*) sobre todo el catalogo.
 */
export async function consultarCatalogo(sql, tiendaId, opciones = {}) {
	const busqueda = (opciones.q ?? '').trim();
	const categoriaId = (opciones.categoria ?? '').trim();
	const limite = Math.min(
		Math.max(Number(opciones.limite) || LIMITE_PAGINA_CATALOGO, 1),
		LIMITE_PAGINA_CATALOGO,
	);
	const salto = Math.max(Number(opciones.desde) || 0, 0);

	const condiciones = ['p.activo = 1', 'p.tienda_id = $1', 'p.precio_base > 0'];
	const parametros = [tiendaId];

	if (busqueda) {
		parametros.push(`%${escaparLike(busqueda)}%`, busqueda);
		condiciones.push(
			`(p.nombre ILIKE $${parametros.length - 1} OR p.codigo_barras = $${parametros.length})`,
		);
	}
	if (categoriaId === 'sin-categoria') {
		condiciones.push("(p.categoria_id IS NULL OR p.categoria_id = '')");
	} else if (categoriaId) {
		parametros.push(categoriaId);
		condiciones.push(`p.categoria_id = $${parametros.length}`);
	}

	parametros.push(limite + 1, salto);
	const filas = await sql.query(
		`SELECT p.id, p.nombre, p.precio_base, p.unidad_medida,
			p.categoria_id, p.notas, c.nombre AS categoria_nombre
		 FROM products p
		 LEFT JOIN categories c ON c.id = p.categoria_id
		 WHERE ${condiciones.join(' AND ')}
		 ORDER BY p.nombre ASC
		 LIMIT $${parametros.length - 1} OFFSET $${parametros.length}`,
		parametros,
	);

	const productos = filas.slice(0, limite).map((fila) => ({
		id: fila.id,
		nombre: fila.nombre,
		precio: redondearMonto(Number(fila.precio_base ?? 0)),
		unidad: fila.unidad_medida || 'pieza',
		categoriaId: fila.categoria_id,
		categoria: fila.categoria_nombre || 'Otros',
		descripcion: (fila.notas ?? '').trim(),
		presentaciones: [],
	}));

	const porProducto = await cargarPresentaciones(sql, productos.map((p) => p.id));
	for (const producto of productos) {
		producto.presentaciones = porProducto.get(producto.id) ?? [];
	}

	return {
		productos,
		hayMas: filas.length > limite,
		siguiente: salto + productos.length,
	};
}

/**
 * Presentaciones activas CON precio propio (caja, bulto).
 *
 * Las que no tienen importe publicado no son vendibles en linea.
 */
export async function cargarPresentaciones(sql, productoIds) {
	if (!productoIds.length) {
		return new Map();
	}
	const filas = await sql.query(
		`SELECT id, producto_id, nombre, precio, factor_a_base
		 FROM product_presentations
		 WHERE activo = 1
			AND precio IS NOT NULL
			AND precio > 0
			AND es_presentacion_base = 0
			AND producto_id = ANY($1)
		 ORDER BY factor_a_base ASC`,
		[productoIds],
	);
	const porProducto = new Map();
	for (const fila of filas) {
		const lista = porProducto.get(fila.producto_id) ?? [];
		lista.push({
			id: fila.id,
			nombre: fila.nombre,
			precio: redondearMonto(Number(fila.precio ?? 0)),
			factor: Number(fila.factor_a_base ?? 1),
		});
		porProducto.set(fila.producto_id, lista);
	}
	return porProducto;
}

/** Escapa los comodines de LIKE para que el usuario no los inyecte. */
export function escaparLike(texto) {
	return texto.replace(/%/g, '\\%').replace(/_/g, '\\_');
}
