/* Consultas del catalogo publico.

   Regla de oro: la vitrina NUNCA expone existencias. Solo nombre, precio,
   unidad, categoria, imagen, presentaciones y escalas de precio por cantidad.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import { LIMITE_PAGINA_CATALOGO } from './constantes.js';
import { redondearMonto } from './dinero.js';

/**
 * Categorias activas con al menos un producto publicable.
 *
 * Catalogo UNIFICADO: cuenta productos de todas las sucursales activas. El
 * total se calcula sobre nombres distintos, igual que la vitrina, para que no
 * infle con el mismo producto repetido en varias sucursales.
 */
export async function consultarCategorias(sql) {
	const filas = await sql.query(
		`SELECT c.id, c.nombre, COUNT(DISTINCT lower(btrim(p.nombre))) AS total
		 FROM categories c
		 JOIN products p
			ON p.categoria_id = c.id
			AND p.activo = 1
			AND p.precio_base > 0
		 JOIN stores s ON s.id = p.tienda_id AND s.activa = 1
		 WHERE c.activa = 1
		 GROUP BY c.id, c.nombre, c.orden
		 HAVING COUNT(p.id) > 0
		 ORDER BY c.orden ASC, c.nombre ASC`,
	);
	return {
		categorias: filas.map((fila) => ({
			id: fila.id,
			nombre: fila.nombre,
			total: Number(fila.total ?? 0),
		})),
	};
}

/** Maximo de sugerencias devueltas junto a los resultados. */
const LIMITE_SUGERENCIAS = 8;

/** Ordenes soportados desde la URL. */
const ORDENES_VALIDOS = new Set(['nombre', 'precio_asc', 'precio_desc']);

/**
 * Acentos que la busqueda normaliza (á→a, ñ→n, ü→u, etc.).
 *
 * La misma tabla vive espejada en `packages/posia_core/lib/src/utils/
 * busqueda_producto_util.dart`: si se agregan letras aqui hay que agregarlas
 * alla tambien para que la caja y la tienda en linea usen el mismo alfabeto.
 */
const ACENTOS_ORIGEN = 'áàäâéèëêíìïîóòöôúùüûñ';
const ACENTOS_DESTINO = 'aaaaeeeeiiiioooouuuun';

/**
 * Expresion SQL que devuelve el nombre + notas + categoria en minusculas y
 * sin acentos. Es el "texto buscable" contra el que se aplican los tokens de
 * la consulta.
 */
const SQL_TEXTO_BUSCABLE = `translate(
	lower(
		coalesce(p.nombre, '') || ' ' ||
		coalesce(p.notas, '') || ' ' ||
		coalesce(c.nombre, '')
	),
	'${ACENTOS_ORIGEN}',
	'${ACENTOS_DESTINO}'
)`;

/**
 * Baja a minusculas y quita acentos. Espejo de `normalizarTextoBusqueda`
 * del POS: la vitrina resuelve "arándano" y "arandano" igual.
 */
export function normalizarBusqueda(texto) {
	if (!texto) {
		return '';
	}
	let s = String(texto).toLowerCase();
	for (let i = 0; i < ACENTOS_ORIGEN.length; i++) {
		const desde = ACENTOS_ORIGEN[i];
		if (s.indexOf(desde) === -1) {
			continue;
		}
		s = s.split(desde).join(ACENTOS_DESTINO[i]);
	}
	return s;
}

/**
 * Tokens de una consulta ya normalizada, unicos y sin vacios.
 *
 * "arroz  1kg " → ["arroz", "1kg"]
 */
function tokenizar(consulta) {
	const normalizado = normalizarBusqueda(consulta).trim();
	if (!normalizado) {
		return [];
	}
	return Array.from(new Set(normalizado.split(/\s+/).filter(Boolean)));
}

/**
 * Agrega al WHERE la condicion de busqueda. Cada token debe aparecer en el
 * nombre, las notas o la categoria (todos normalizados sin acentos), o bien
 * el codigo de barras completo coincide exacto. El acento en la consulta ya
 * no bloquea el match: "arandano", "arándano" y "Arándano" son la misma
 * busqueda.
 */
function agregarBusqueda(condiciones, parametros, consultaCruda) {
	const consulta = (consultaCruda ?? '').trim();
	if (!consulta) {
		return;
	}
	const tokens = tokenizar(consulta);
	if (!tokens.length) {
		return;
	}

	const partesTokens = [];
	for (const token of tokens) {
		parametros.push(`%${escaparLike(token)}%`);
		partesTokens.push(`${SQL_TEXTO_BUSCABLE} LIKE $${parametros.length}`);
	}
	// Un escaneo con el lector tira el codigo exacto: se deja como atajo
	// para que salga el producto sin pasar por el texto buscable.
	parametros.push(consulta);
	const partaCodigo = `p.codigo_barras = $${parametros.length}`;

	condiciones.push(`((${partesTokens.join(' AND ')}) OR ${partaCodigo})`);
}

/** Filtro de precio min/max. Ignora valores no numericos, negativos o vacios. */
function agregarFiltroPrecio(condiciones, parametros, precioMin, precioMax) {
	const min = Number(precioMin);
	if (Number.isFinite(min) && min > 0) {
		parametros.push(min);
		condiciones.push(`p.precio_base >= $${parametros.length}`);
	}
	const max = Number(precioMax);
	if (Number.isFinite(max) && max > 0) {
		parametros.push(max);
		condiciones.push(`p.precio_base <= $${parametros.length}`);
	}
}

/** Fragmento ORDER BY final segun el `orden` pedido. Falla a alfabetico. */
function ordenExterno(orden) {
	if (orden === 'precio_asc') {
		return 'unicos.precio_base ASC, unicos.nombre ASC';
	}
	if (orden === 'precio_desc') {
		return 'unicos.precio_base DESC, unicos.nombre ASC';
	}
	return 'unicos.nombre ASC';
}

/**
 * Pagina del catalogo.
 *
 * Se pide un producto de mas que el limite para saber si hay pagina
 * siguiente sin pagar un COUNT(*) sobre todo el catalogo.
 *
 * Cuando hay `busqueda` se devuelve tambien `sugerencias`: productos de las
 * mismas categorias que los resultados directos (o, si no hubo ninguno, de
 * las categorias cuyo nombre matchea con la consulta). Reproduce el patron
 * "buscar arandano y ver almendra fileteada abajo".
 */
export async function consultarCatalogo(sql, tiendaPrincipalId, opciones = {}) {
	const busqueda = (opciones.q ?? '').trim();
	const categoriaId = (opciones.categoria ?? '').trim();
	const orden = ORDENES_VALIDOS.has(opciones.orden) ? opciones.orden : 'nombre';
	// Lista acotada de ids (p. ej. para refrescar precio/escalas de un
	// carrito guardado): sin paginar, se traen todos los que pidan.
	const idsFiltro = Array.isArray(opciones.ids)
		? [...new Set(opciones.ids.map((id) => String(id).trim()).filter(Boolean))]
		: [];
	const limite = idsFiltro.length
		? idsFiltro.length
		: Math.min(
			Math.max(Number(opciones.limite) || LIMITE_PAGINA_CATALOGO, 1),
			LIMITE_PAGINA_CATALOGO,
		);
	const salto = idsFiltro.length ? 0 : Math.max(Number(opciones.desde) || 0, 0);

	const condiciones = ['p.activo = 1', 'p.precio_base > 0'];
	const parametros = [tiendaPrincipalId];

	if (idsFiltro.length) {
		parametros.push(idsFiltro);
		condiciones.push(`p.id = ANY($${parametros.length})`);
	}
	if (!idsFiltro.length) {
		agregarBusqueda(condiciones, parametros, busqueda);
		agregarFiltroPrecio(condiciones, parametros, opciones.precioMin, opciones.precioMax);
	}
	if (categoriaId === 'sin-categoria') {
		condiciones.push("(p.categoria_id IS NULL OR p.categoria_id = '')");
	} else if (categoriaId) {
		parametros.push(categoriaId);
		condiciones.push(`p.categoria_id = $${parametros.length}`);
	}

	parametros.push(limite + 1, salto);
	// DISTINCT ON deja una sola ficha por producto aunque exista en varias
	// sucursales: gana la de la tienda principal y, si no esta ahi, la mas
	// barata. Sin esto el mismo articulo saldria repetido en la vitrina.
	const filas = await sql.query(
		`SELECT * FROM (
			SELECT DISTINCT ON (lower(btrim(p.nombre)))
				p.id, p.nombre, p.precio_base, p.unidad_medida,
				p.categoria_id, p.notas, p.ruta_imagen, c.nombre AS categoria_nombre
			FROM products p
			JOIN stores s ON s.id = p.tienda_id AND s.activa = 1
			LEFT JOIN categories c ON c.id = p.categoria_id
			WHERE ${condiciones.join(' AND ')}
			ORDER BY lower(btrim(p.nombre)),
				(p.tienda_id = $1) DESC, p.precio_base ASC, p.id ASC
		) unicos
		ORDER BY ${ordenExterno(orden)}
		LIMIT $${parametros.length - 1} OFFSET $${parametros.length}`,
		parametros,
	);

	const productos = filas.slice(0, limite).map(aProductoPublico);

	const [porProducto, porEscalas] = await Promise.all([
		cargarPresentaciones(sql, productos.map((p) => p.id)),
		cargarEscalas(sql, productos.map((p) => p.id)),
	]);
	for (const producto of productos) {
		producto.presentaciones = porProducto.get(producto.id) ?? [];
		producto.escalas = porEscalas.get(producto.id) ?? [];
	}

	const sugerencias = busqueda && !idsFiltro.length && salto === 0
		? await consultarSugerencias(sql, tiendaPrincipalId, {
			busqueda,
			categoriaFiltro: categoriaId,
			precioMin: opciones.precioMin,
			precioMax: opciones.precioMax,
			productosDirectos: productos,
		})
		: [];

	return {
		productos,
		hayMas: filas.length > limite,
		siguiente: salto + productos.length,
		sugerencias,
	};
}

/**
 * Productos relacionados que se muestran debajo de los resultados directos.
 *
 * Cuando la busqueda si trajo resultados, la relacion es "misma categoria":
 * si buscaste "arandano" y salio en la categoria de frutos secos, tambien
 * te ofrecemos almendra, nuez, etc.
 *
 * Cuando la busqueda no trajo nada, buscamos categorias cuyo nombre
 * contenga alguno de los tokens: "ablandador de carne" (que no existe
 * como producto) devuelve productos de "Carnes" o "Condimentos".
 */
async function consultarSugerencias(sql, tiendaPrincipalId, {
	busqueda,
	categoriaFiltro,
	precioMin,
	precioMax,
	productosDirectos,
}) {
	const tokens = tokenizar(busqueda);
	if (!tokens.length) {
		return [];
	}

	const idsDirectos = productosDirectos.map((p) => p.id).filter(Boolean);
	// Mismo producto en dos sucursales: la vitrina muestra una fila por
	// DISTINCT ON(lower(btrim(nombre))), pero la OTRA fila (mismo nombre,
	// otro id) todavia puede colarse en sugerencias porque el filtro por
	// id no la excluye. Se excluye tambien por nombre normalizado para no
	// repetir "Arroz" en la vitrina y en "podria interesarte".
	const nombresDirectos = productosDirectos
		.map((p) => (p.nombre ?? '').trim().toLowerCase())
		.filter(Boolean);

	// La categoria "sin-categoria" no aporta un IN util (todas las nulls no
	// se relacionan entre si); tampoco sugerimos si el usuario ya filtro por
	// una sola categoria: dentro de esa vitrina "sugerir mas de la misma
	// categoria" seria redundante.
	if (categoriaFiltro && categoriaFiltro !== 'sin-categoria') {
		return [];
	}

	// Categorias base: donde cayeron los resultados directos, o (si no hubo)
	// las que matchean con los tokens de la busqueda.
	let categoriaIds = productosDirectos
		.map((p) => p.categoriaId)
		.filter((id) => id && id !== '');
	categoriaIds = [...new Set(categoriaIds)];

	if (!categoriaIds.length) {
		categoriaIds = await categoriasPorTokens(sql, tokens);
	}
	if (!categoriaIds.length) {
		return [];
	}

	const condiciones = [
		'p.activo = 1',
		'p.precio_base > 0',
		'p.categoria_id = ANY($2)',
	];
	const parametros = [tiendaPrincipalId, categoriaIds];

	if (idsDirectos.length) {
		parametros.push(idsDirectos);
		condiciones.push(`p.id <> ALL($${parametros.length})`);
	}
	if (nombresDirectos.length) {
		parametros.push(nombresDirectos);
		condiciones.push(`lower(btrim(p.nombre)) <> ALL($${parametros.length})`);
	}
	agregarFiltroPrecio(condiciones, parametros, precioMin, precioMax);

	parametros.push(LIMITE_SUGERENCIAS);
	// Sin busqueda de texto adicional: la sugerencia se ancla en la
	// categoria, no en el token. Se priorizan productos con foto y luego
	// el precio mas bajo para que la seccion "podria interesarte" no
	// arranque con articulos caros o sin imagen.
	const filas = await sql.query(
		`SELECT * FROM (
			SELECT DISTINCT ON (lower(btrim(p.nombre)))
				p.id, p.nombre, p.precio_base, p.unidad_medida,
				p.categoria_id, p.notas, p.ruta_imagen, c.nombre AS categoria_nombre
			FROM products p
			JOIN stores s ON s.id = p.tienda_id AND s.activa = 1
			LEFT JOIN categories c ON c.id = p.categoria_id
			WHERE ${condiciones.join(' AND ')}
			ORDER BY lower(btrim(p.nombre)),
				(p.tienda_id = $1) DESC, p.precio_base ASC, p.id ASC
		) unicos
		ORDER BY (unicos.ruta_imagen IS NOT NULL AND unicos.ruta_imagen <> '') DESC,
			unicos.precio_base ASC, unicos.nombre ASC
		LIMIT $${parametros.length}`,
		parametros,
	);

	const sugerencias = filas.map(aProductoPublico);
	const [porProducto, porEscalas] = await Promise.all([
		cargarPresentaciones(sql, sugerencias.map((p) => p.id)),
		cargarEscalas(sql, sugerencias.map((p) => p.id)),
	]);
	for (const producto of sugerencias) {
		producto.presentaciones = porProducto.get(producto.id) ?? [];
		producto.escalas = porEscalas.get(producto.id) ?? [];
	}
	return sugerencias;
}

/**
 * Categorias cuyo nombre (normalizado sin acentos) contenga cualquiera de
 * los tokens. Se usa cuando la busqueda no trajo resultados directos: dar
 * pistas por familia en vez de un catalogo vacio.
 */
async function categoriasPorTokens(sql, tokens) {
	const partes = [];
	const parametros = [];
	for (const token of tokens) {
		parametros.push(`%${escaparLike(token)}%`);
		partes.push(
			`translate(lower(c.nombre), '${ACENTOS_ORIGEN}', '${ACENTOS_DESTINO}') LIKE $${parametros.length}`,
		);
	}
	if (!partes.length) {
		return [];
	}
	const filas = await sql.query(
		`SELECT DISTINCT c.id
		 FROM categories c
		 WHERE c.activa = 1 AND (${partes.join(' OR ')})`,
		parametros,
	);
	return filas.map((f) => f.id).filter(Boolean);
}

/** Mapea la fila de products al producto publico expuesto por el API. */
function aProductoPublico(fila) {
	return {
		id: fila.id,
		nombre: fila.nombre,
		precio: redondearMonto(Number(fila.precio_base ?? 0)),
		unidad: fila.unidad_medida || 'pieza',
		categoriaId: fila.categoria_id,
		categoria: fila.categoria_nombre || 'Otros',
		descripcion: (fila.notas ?? '').trim(),
		imagenUrl: (fila.ruta_imagen ?? '').trim() || null,
		presentaciones: [],
		escalas: [],
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

/**
 * Tramos de mayoreo / precio por peso desde Neon.
 *
 * Misma tabla que proyecta el hub (`wholesale_tiers`). Sin esto la vitrina
 * cobra el precio de kilo tambien en medio y cuarto.
 */
export async function cargarEscalas(sql, productoIds) {
	if (!productoIds.length) {
		return new Map();
	}
	const filas = await sql.query(
		`SELECT producto_id, cantidad_minima, precio_unitario
		 FROM wholesale_tiers
		 WHERE producto_id = ANY($1)
		 ORDER BY cantidad_minima ASC`,
		[productoIds],
	);
	const porProducto = new Map();
	for (const fila of filas) {
		const lista = porProducto.get(fila.producto_id) ?? [];
		const precio = Number(fila.precio_unitario ?? 0);
		if (!(precio > 0)) {
			continue;
		}
		lista.push({
			cantidadMinima: Number(fila.cantidad_minima ?? 0),
			precioUnitario: redondearMonto(precio),
		});
		porProducto.set(fila.producto_id, lista);
	}
	return porProducto;
}

/** Escapa los comodines de LIKE para que el usuario no los inyecte. */
export function escaparLike(texto) {
	return texto.replace(/%/g, '\\%').replace(/_/g, '\\_');
}
