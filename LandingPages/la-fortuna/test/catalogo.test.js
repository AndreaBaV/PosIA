/* Pruebas del catalogo publico: filtros, paginacion y lo que NO se publica.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { consultarCatalogo, consultarCategorias, escaparLike } from '../lib/catalogo.js';
import { redondearMonto } from '../lib/dinero.js';
import { consultasCon, sqlFalso } from '../test-apoyo/ayudas.js';

const TIENDA = 'tienda-1';

function producto(id, nombre, precio = 10) {
	return {
		id,
		nombre,
		precio_base: precio,
		unidad_medida: 'pieza',
		categoria_id: 'cat-1',
		notas: '',
		categoria_nombre: 'Abarrotes',
	};
}

test('el catálogo nunca consulta ni publica existencias', async () => {
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	const datos = await consultarCatalogo(sql, TIENDA);

	for (const llamada of sql.llamadas) {
		assert.ok(!/stock_levels|warehouse_stock/i.test(llamada.texto),
			'no debe tocarse ninguna tabla de inventario');
	}
	assert.deepEqual(Object.keys(datos.productos[0]).sort(), [
		'categoria', 'categoriaId', 'descripcion', 'escalas', 'id', 'imagenUrl',
		'nombre', 'precio', 'presentaciones', 'unidad',
	]);
});

test('el catálogo expone la imagen del producto cuando existe, o null si no', async () => {
	const conImagen = producto('p1', 'Frijol');
	conImagen.ruta_imagen = 'https://pub-test.r2.dev/productos/p1-123.jpg';
	const sinImagen = producto('p2', 'Arroz');
	sinImagen.ruta_imagen = '';

	const sql = sqlFalso({ productos: [conImagen, sinImagen] });
	const datos = await consultarCatalogo(sql, TIENDA);

	const [frijol, arroz] = datos.productos;
	assert.equal(frijol.imagenUrl, 'https://pub-test.r2.dev/productos/p1-123.jpg');
	assert.equal(arroz.imagenUrl, null);
});

test('el catálogo trae las escalas de precio por cantidad', async () => {
	const sql = sqlFalso({
		productos: [producto('carne', 'Bistec')],
		escalas: [
			{ producto_id: 'carne', cantidad_minima: 0.5, precio_unitario: 40 },
			{ producto_id: 'carne', cantidad_minima: 1, precio_unitario: 30 },
		],
	});
	const datos = await consultarCatalogo(sql, TIENDA);
	assert.equal(datos.productos[0].escalas.length, 2);
	assert.equal(datos.productos[0].escalas[0].cantidadMinima, 0.5);
	assert.equal(datos.productos[0].escalas[0].precioUnitario, 40);
	assert.ok(
		consultasCon(sql, 'FROM wholesale_tiers').length >= 1,
		'debe leer wholesale_tiers para respetar medio/cuarto kilo',
	);
});

test('opciones.ids filtra por producto sin paginar, para refrescar un carrito guardado', async () => {
	const sql = sqlFalso({
		productos: [producto('carne', 'Bistec'), producto('pollo', 'Pechuga')],
	});
	const datos = await consultarCatalogo(sql, TIENDA, { ids: ['carne', 'pollo'] });

	const consulta = sql.llamadas.find((l) => l.texto.includes('FROM products'));
	assert.ok(consulta.texto.includes('p.id = ANY('),
		'debe filtrar por id cuando se piden ids especificos');
	assert.deepEqual(consulta.parametros[1], ['carne', 'pollo']);
	// Sin paginar: no debe faltar ningun producto de la lista pedida por
	// culpa del LIMIT normal de la vitrina.
	assert.equal(datos.hayMas, false);
	assert.equal(datos.productos.length, 2);
});

test('opciones.ids ignorado si viene vacio: se comporta como el catalogo normal', async () => {
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	await consultarCatalogo(sql, TIENDA, { ids: [] });

	const consulta = sql.llamadas.find((l) => l.texto.includes('FROM products'));
	assert.ok(!consulta.texto.includes('p.id = ANY('),
		'una lista vacia no debe agregar el filtro por id');
});

test('solo salen productos activos y con precio, de cualquier sucursal', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA);
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('p.activo = 1'));
	assert.ok(consulta.texto.includes('p.precio_base > 0'));
	assert.ok(
		!/AND p\.tienda_id = \$\d+/.test(consulta.texto),
		'el catálogo es unificado: la sucursal no filtra (solo desempata)',
	);
	assert.ok(
		consulta.texto.includes('JOIN stores s ON s.id = p.tienda_id AND s.activa = 1'),
		'pero sí se excluyen las sucursales dadas de baja',
	);
});

test('un producto repetido en varias sucursales sale una sola vez', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA);
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('DISTINCT ON (lower(btrim(p.nombre)))'));
	assert.ok(
		consulta.texto.includes('(p.tienda_id = $1) DESC, p.precio_base ASC'),
		'gana la ficha de la tienda principal y, si no está, la más barata',
	);
	assert.equal(consulta.parametros[0], TIENDA);
});

test('la búsqueda numera sus parámetros junto al filtro de categoría', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { q: 'frijol', categoria: 'cat-9', limite: 20, desde: 40 });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('p.nombre ILIKE $2 OR p.codigo_barras = $3'));
	assert.ok(consulta.texto.includes('p.categoria_id = $4'));
	assert.ok(consulta.texto.includes('LIMIT $5 OFFSET $6'));
	assert.deepEqual(consulta.parametros, [TIENDA, '%frijol%', 'frijol', 'cat-9', 21, 40]);
});

test('la categoría "sin-categoria" agrupa los productos sueltos', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { categoria: 'sin-categoria' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes("p.categoria_id IS NULL OR p.categoria_id = ''"));
	assert.equal(consulta.parametros.length, 3, 'sin parámetro de categoría');
});

test('hayMas se decide con un producto extra, no con COUNT', async () => {
	const cinco = ['a', 'b', 'c', 'd', 'e'].map((id) => producto(id, id));
	const sql = sqlFalso({ productos: cinco });
	const datos = await consultarCatalogo(sql, TIENDA, { limite: 4 });
	assert.equal(datos.productos.length, 4);
	assert.equal(datos.hayMas, true);
	assert.equal(datos.siguiente, 4);

	const sinExtra = sqlFalso({ productos: cinco.slice(0, 3) });
	const ultima = await consultarCatalogo(sinExtra, TIENDA, { limite: 4, desde: 8 });
	assert.equal(ultima.hayMas, false);
	assert.equal(ultima.siguiente, 11);
});

test('el límite por página no se puede inflar desde la URL', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { limite: '5000', desde: '-3' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.equal(consulta.parametros.at(-2), 61, 'tope de 60 productos + 1 de sondeo');
	assert.equal(consulta.parametros.at(-1), 0, 'sin desplazamientos negativos');
});

test('cada producto trae sus presentaciones con precio propio', async () => {
	const sql = sqlFalso({
		productos: [producto('p1', 'Frijol', 38.5)],
		presentaciones: [
			{ id: 'pr1', producto_id: 'p1', nombre: 'Bulto 25 kg', precio: 890, factor_a_base: 25 },
		],
	});
	const datos = await consultarCatalogo(sql, TIENDA);
	assert.deepEqual(datos.productos[0].presentaciones, [
		{ id: 'pr1', nombre: 'Bulto 25 kg', precio: 890, factor: 25 },
	]);

	const consulta = consultasCon(sql, 'FROM product_presentations')[0];
	assert.ok(consulta.texto.includes('precio IS NOT NULL'));
	assert.ok(consulta.texto.includes('es_presentacion_base = 0'));
});

test('sin productos no se consultan presentaciones', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA);
	assert.equal(consultasCon(sql, 'FROM product_presentations').length, 0);
});

test('las categorías vacías no se listan', async () => {
	const sql = sqlFalso({ categorias: [{ id: 'cat-1', nombre: 'Abarrotes', total: 12 }] });
	const datos = await consultarCategorias(sql);
	assert.deepEqual(datos.categorias, [{ id: 'cat-1', nombre: 'Abarrotes', total: 12 }]);
	const consulta = consultasCon(sql, 'FROM categories')[0];
	assert.ok(consulta.texto.includes('HAVING COUNT(p.id) > 0'));
	assert.ok(consulta.texto.includes('c.activa = 1'));
	assert.ok(
		consulta.texto.includes('COUNT(DISTINCT lower(btrim(p.nombre)))'),
		'el total no debe inflarse con el mismo producto de varias sucursales',
	);
});

test('los comodines de LIKE se escapan', () => {
	assert.equal(escaparLike('100%_algo'), '100\\%\\_algo');
});

test('los precios se redondean como en el POS', () => {
	assert.equal(redondearMonto(38.505), 38.51);
	assert.equal(redondearMonto(0.1 + 0.2), 0.3);
	assert.equal(redondearMonto(165 * 1.5), 247.5);
});
